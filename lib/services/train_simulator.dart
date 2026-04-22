import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../data/route_geometry.dart';

/// 시간표 기반 열차 위치 시뮬레이터
///
/// 세 가지 용도:
/// 1. **데모 모드**: API 없이 가상 열차를 운행 (3D 테스트용)
/// 2. **보간 모드**: API 스냅샷 사이 구간을 시간표 속도로 자체 추정
/// 3. **연속 보간 모드**: 매 프레임(60fps) 시간표 기반 정밀 위치 계산
///
/// 서울 지하철 실제 운행 데이터 기반:
/// - 평균 운행 속도: 33 km/h (정차 포함)
/// - 평균 역간 거리: ~1.1 km
/// - 평균 역간 주행: ~100초, 정차: ~20초
class TrainSimulator {
  // 역간 평균 주행시간 (초) — 서울 지하철 평균
  static const double avgInterStationSec = 100.0; // 1분 40초
  // 역 정차 시간 (초)
  static const double dwellTimeSec = 20.0;
  // 역간 + 정차 = 1구간 소요시간 (~2분)
  static const double segmentDurationSec = avgInterStationSec + dwellTimeSec;

  // 급행/초급행 속도 계수 (일반 대비)
  // 급행: 30% 빠름, 초급행: 45% 빠름
  static const double expressSpeedFactor = 0.70;
  static const double superExpressSpeedFactor = 0.55;

  // 노선별 시뮬레이션된 열차 상태
  final Map<String, List<_SimTrain>> _simTrains = {};

  // 마지막 API 스냅샷 데이터
  List<TrainPosition> _lastApiSnapshot = [];
  List<TrainPosition> get lastApiSnapshot => _lastApiSnapshot;

  // ── 노선별 역간 시간표 스케줄 ──
  final Map<String, _LineSchedule> _scheduleCache = {};

  // OSM 노선 경로 기반 보간
  RouteGeometry? _routeGeometry;

  /// RouteGeometry 설정 (초기화 후 호출)
  void setRouteGeometry(RouteGeometry rg) {
    _routeGeometry = rg;
  }

  /// 데모 모드: 노선별 가상 열차 초기 배치
  /// 피크 시간(07-09, 17-19)은 배차간격 3분, 그 외 5분
  /// 1호선: 급행(expressType=1) + 초급행(expressType=7) 추가 배치
  void initDemoTrains() {
    _simTrains.clear();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      final stations = SeoulSubwayData.getLineStations(lineId);
      if (stations.length < 2) continue;

      final isPeak = _isPeakHour();
      final headwayMin = isPeak ? 3.0 : 6.0;
      final segments = stations.length - 1;
      final oneWayMin = segments * (segmentDurationSec / 60.0);
      final trainCount = max(2, (oneWayMin * 2 / headwayMin).round());

      final trains = <_SimTrain>[];
      for (int i = 0; i < trainCount; i++) {
        final offset = (i / trainCount) * oneWayMin * 2 * 60;
        final isUpbound = i % 2 == 0;
        trains.add(_SimTrain(
          trainNo: '${lineId}D${i.toString().padLeft(3, '0')}',
          lineId: lineId,
          stationCount: stations.length,
          offsetSec: offset,
          isUpbound: isUpbound,
          expressType: 0, // 일반
        ));
      }

      // 1호선: 급행/초급행 열차 추가
      if (lineId == '1001') {
        final expressStations = SeoulSubwayData.getExpressStations(lineId, 1);
        final superExpressStations = SeoulSubwayData.getExpressStations(lineId, 7);

        // 급행 3~4대
        final expressCount = isPeak ? 4 : 3;
        final expSegments = expressStations.length - 1;
        final expOneWayMin = expSegments * (_expressSegmentDurationSec(lineId, 1) / 60.0);
        for (int i = 0; i < expressCount; i++) {
          final offset = (i / expressCount) * expOneWayMin * 2 * 60;
          trains.add(_SimTrain(
            trainNo: '${lineId}E${i.toString().padLeft(3, '0')}',
            lineId: lineId,
            stationCount: expressStations.length,
            offsetSec: offset,
            isUpbound: i % 2 == 0,
            expressType: 1,
          ));
        }

        // 초급행(특급) 2대
        final superExpSegments = superExpressStations.length - 1;
        final superExpOneWayMin = superExpSegments * (_expressSegmentDurationSec(lineId, 7) / 60.0);
        for (int i = 0; i < 2; i++) {
          final offset = (i / 2) * superExpOneWayMin * 2 * 60;
          trains.add(_SimTrain(
            trainNo: '${lineId}S${i.toString().padLeft(3, '0')}',
            lineId: lineId,
            stationCount: superExpressStations.length,
            offsetSec: offset,
            isUpbound: i % 2 == 0,
            expressType: 7,
          ));
        }
      }

      _simTrains[lineId] = trains;
    }

    debugPrint('[TrainSimulator] 데모 열차 초기화: '
        '${_simTrains.values.fold<int>(0, (s, l) => s + l.length)}개');
  }

  /// 급행 열차의 평균 역간 소요시간 (초)
  /// 급행 정차역 간 일반 역 구간 수 × 일반 역간시간 × 속도계수 + 정차시간
  double _expressSegmentDurationSec(String lineId, int expressType) {
    final allStations = SeoulSubwayData.getLineStations(lineId);
    final expressStations = SeoulSubwayData.getExpressStations(lineId, expressType);
    if (expressStations.length < 2) return segmentDurationSec;

    final normalSegments = allStations.length - 1;
    final expressSegments = expressStations.length - 1;
    final avgNormalPerExpress = normalSegments / expressSegments;
    final speedFactor = expressType == 7 ? superExpressSpeedFactor : expressSpeedFactor;
    return avgNormalPerExpress * avgInterStationSec * speedFactor + dwellTimeSec;
  }

  /// 현재 시각 기준 시뮬레이션된 열차 위치 목록 생성
  List<TrainPosition> generateDemoPositions() {
    final now = DateTime.now();
    final todaySec = now.hour * 3600.0 + now.minute * 60.0 + now.second + now.millisecond / 1000.0;
    final results = <TrainPosition>[];

    for (final entry in _simTrains.entries) {
      final lineId = entry.key;
      final lineName = SeoulSubwayData.lineIdToApiName[lineId] ?? lineId;

      for (final sim in entry.value) {
        // 급행/초급행은 정차역 리스트 사용
        final stations = SeoulSubwayData.getExpressStations(lineId, sim.expressType);
        if (stations.length < 2) continue;

        final segDuration = sim.expressType == 0
            ? segmentDurationSec
            : _expressSegmentDurationSec(lineId, sim.expressType);

        final pos = _calcSimPosition(sim, stations, todaySec, segDuration);
        if (pos == null) continue;

        results.add(TrainPosition(
          subwayId: lineId,
          subwayName: lineName,
          stationId: stations[pos.stationIndex].id,
          stationName: stations[pos.stationIndex].name,
          trainNo: sim.trainNo,
          lastRecvDate: '',
          recvTime: '',
          direction: pos.isUpbound ? 0 : 1,
          terminalId: '',
          terminalName: pos.isUpbound ? stations.first.name : stations.last.name,
          trainStatus: pos.status,
          expressType: sim.expressType,
          isLastTrain: false,
        ));
      }
    }
    return results;
  }


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // MiniTokyo3D 방식: 순수 함수 기반 위치 계산
  // 위치 = f(현재시각) — 상태 누적 없음, 텔레포트 없음
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // 활성 열차 세그먼트 (trainNo → TrainSegment)
  final Map<String, TrainSegment> _segments = {};
  int? _lastLogTime; // 로그 throttle용

  // ── 실시간 속도 학습: API 관측에서 실제 역간 소요시간 측정 ──
  // key: "lineId_fromIdx_toIdx" → 실측 소요시간(ms)
  final Map<String, int> _observedTravelMs = {};
  // 열차별 마지막 관측 정보: trainNo → (stationName, timeMs)
  final Map<String, _TrainObservation> _lastObservation = {};

  /// API 스냅샷 저장
  void updateApiSnapshot(List<TrainPosition> positions) {
    _lastApiSnapshot = List.from(positions);
  }

  /// API 데이터 → 세그먼트 생성/갱신 (prepareContinuousExtrapolation 대체)
  void prepareContinuousExtrapolation() {
    final rg = _routeGeometry;
    if (rg == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final observed = <String>{};

    for (final train in _lastApiSnapshot) {
      observed.add(train.trainNo);

      final isExpress = train.expressType != 0;
      final stations = isExpress
          ? SeoulSubwayData.getExpressStations(train.subwayId, train.expressType)
          : SeoulSubwayData.getLineStations(train.subwayId);
      if (stations.length < 2) continue;
      if (!rg.hasRoute(train.subwayId)) continue;

      final schedule = _getSchedule(train.subwayId, train.expressType);

      int stIdx = _findStationIdx(stations, train.stationName);
      if (stIdx < 0 && isExpress) {
        final allStations = SeoulSubwayData.getLineStations(train.subwayId);
        final allIdx = _findStationIdx(allStations, train.stationName);
        if (allIdx >= 0) {
          stIdx = _findNearestExpressStopIdx(stations, allStations, allIdx, train.direction == 0);
        }
      }
      if (stIdx < 0) continue;

      // ── 실시간 속도 학습: 열차가 새 역에 도착했으면 이동 시간 기록 ──
      final prevObs = _lastObservation[train.trainNo];
      if (prevObs != null && prevObs.stationName != train.stationName && prevObs.stationIdx != stIdx) {
        final elapsedMs = nowMs - prevObs.timeMs;
        if (elapsedMs > 5000 && elapsedMs < 600000) {
          final fromI = min(prevObs.stationIdx, stIdx);
          final toI = max(prevObs.stationIdx, stIdx);
          final key = '${train.subwayId}_${fromI}_$toI';
          final prev = _observedTravelMs[key];
          _observedTravelMs[key] = prev != null
              ? (prev * 0.7 + elapsedMs * 0.3).round()
              : elapsedMs;
        }
      }
      _lastObservation[train.trainNo] = _TrainObservation(train.stationName, stIdx, nowMs);

      final isUp = train.direction == 0;

      // 출발역/도착역 인덱스 결정
      int fromIdx, toIdx;
      switch (train.trainStatus) {
        case 2: // 출발 — 현재역에서 다음역으로
          fromIdx = stIdx;
          toIdx = isUp
              ? (stIdx > 0 ? stIdx - 1 : stIdx)
              : (stIdx < stations.length - 1 ? stIdx + 1 : stIdx);
          break;
        case 3: // 이동중 — 이전역→현재역 30% 지점
        case 0: // 곧 도착 — 이전역→현재역 85% 지점
          toIdx = stIdx;
          fromIdx = isUp
              ? (stIdx < stations.length - 1 ? stIdx + 1 : stIdx)
              : (stIdx > 0 ? stIdx - 1 : stIdx);
          break;
        case 1: // 정차중 — 현재역에서 다음역으로 (출발 대기)
        default:
          fromIdx = stIdx;
          toIdx = isUp
              ? (stIdx > 0 ? stIdx - 1 : stIdx)
              : (stIdx < stations.length - 1 ? stIdx + 1 : stIdx);
      }

      if (fromIdx == toIdx) continue; // 종점

      final fromDist = rg.getStationDistance(train.subwayId, stations[fromIdx].name);
      final toDist = rg.getStationDistance(train.subwayId, stations[toIdx].name);
      if (fromDist == null || toDist == null) continue;

      // 실측 소요시간 우선, 없으면 스케줄 기반
      final segKey = '\${train.subwayId}_\${min(fromIdx, toIdx)}_\${max(fromIdx, toIdx)}';
      final observedMs = _observedTravelMs[segKey];
      final travelMs = observedMs ?? (schedule.getTravelSec(min(fromIdx, toIdx), max(fromIdx, toIdx)) * 1000).round();

      // 출발 시각 역산: API 상태에서 "지금 구간의 몇 %인지"로 출발 시각 추정
      int departureMs;
      switch (train.trainStatus) {
        case 2: // 방금 출발
          departureMs = nowMs;
          break;
        case 3: // 30% 지점
          departureMs = nowMs - (travelMs * 0.30).round();
          break;
        case 0: // 85% 지점
          departureMs = nowMs - (travelMs * 0.85).round();
          break;
        case 1: // 정차중 — 정차시간 후 출발 예정
          final dwellMs = (schedule.getStationDwell(stIdx) * 500).round(); // 정차 중간
          departureMs = nowMs + dwellMs;
          break;
        default:
          departureMs = nowMs - (travelMs * 0.50).round();
      }
      final arrivalMs = departureMs + (travelMs < 10000 ? 30000 : travelMs);

      // ── 기존 열차: 절대 세그먼트 교체 안 함. 속도만 조정. ──
      final existing = _segments[train.trainNo];
      if (existing != null) {
        // API 위치 계산
        final apiDist = fromDist + (toDist - fromDist) * _statusToProgress(train.trainStatus);
        final animDist = existing.trackDistance(nowMs);
        final segDist = (existing.endDistM - existing.startDistM).abs();

        if (segDist > 10) {
          final distError = apiDist - animDist; // 양수=뒤처짐, 음수=앞서감
          final timeErrorMs = (distError / segDist * existing.durationMs).round();
          // 앞서가면(error<0) delay 증가 → 느려짐
          // 뒤처지면(error>0) delay 감소 → 빨라짐
          // 달리는 중 변경 없음 → 다음 역 정차에서 적용
          existing.pendingCorrectionMs -= (timeErrorMs * 0.3).round();
        }
        existing.confidence = 1.0;
        continue; // ← 핵심: 기존 열차는 무조건 여기서 끝. 세그먼트 교체 없음.
      }

      // 비정상 속도 체크: travelMs가 너무 짧으면 (제트기 방지) 최소 30초
      final safeTravelMs = travelMs < 10000 ? 30000 : travelMs;
      // 거리가 비정상적이면 스킵 (0m 이동 또는 50km 이상)
      final segDistM = (toDist - fromDist).abs();
      if (segDistM < 10 || segDistM > 50000) continue;

      // 새 세그���트 생성
      _segments[train.trainNo] = TrainSegment.create(
        trainNo: train.trainNo,
        subwayId: train.subwayId,
        subwayName: train.subwayName,
        direction: train.direction,
        expressType: train.expressType,
        terminalName: train.terminalName,
        isLastTrain: train.isLastTrain,
        startDistM: fromDist,
        endDistM: toDist,
        startStationName: stations[fromIdx].name,
        endStationName: stations[toIdx].name,
        departureMs: departureMs,
        arrivalMs: arrivalMs,
        fromStationIdx: fromIdx,
        toStationIdx: toIdx,
      );
    }

    // 미관측 열차: confidence 감쇠 (2분 후 제거)
    final toRemove = <String>[];
    for (final entry in _segments.entries) {
      if (!observed.contains(entry.key)) {
        entry.value.confidence -= 1.0 / 120.0; // ~2분
        if (entry.value.confidence <= 0) toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) _segments.remove(key);

    // ── 검증 로그: 5초마다만 출력 ──
    final shouldLog = _lastLogTime == null ||
        nowMs - _lastLogTime! > 5000;
    if (!shouldLog) return;
    _lastLogTime = nowMs;
    int matched = 0, totalError = 0, maxError = 0;
    final lineStats = <String, List<int>>{}; // lineId → [count, totalError]
    final samplePerLine = <String, String>{}; // lineId → 샘플 1개

    for (final train in _lastApiSnapshot) {
      final seg = _segments[train.trainNo];
      if (seg == null || rg == null) continue;

      final stations = SeoulSubwayData.getLineStations(train.subwayId);
      final stIdx = _findStationIdx(stations, train.stationName);
      if (stIdx < 0) continue;
      final stDist = rg.getStationDistance(train.subwayId, stations[stIdx].name);
      if (stDist == null) continue;

      final animDist = seg.trackDistance(nowMs);
      final errorM = (stDist - animDist).abs().round();

      matched++;
      totalError += errorM;
      if (errorM > maxError) maxError = errorM;

      lineStats.putIfAbsent(train.subwayId, () => [0, 0]);
      lineStats[train.subwayId]![0]++;
      lineStats[train.subwayId]![1] += errorM;

      // 노선별 샘플 1개 (실제 API 열차 우선, 오차 큰 것)
      if (!samplePerLine.containsKey(train.subwayId) || errorM > 300) {
        samplePerLine[train.subwayId] =
            '  ${train.trainNo} ${train.stationName}[${train.statusText}] '
            'API:${stDist.round()}m 애니:${animDist.round()}m '
            '오차:${errorM}m delay:${seg.delayMs}ms';
      }
    }

    final avgError = matched > 0 ? totalError ~/ matched : 0;
    debugPrint('[TrainSim] === 정확도 (학습 ${_observedTravelMs.length}구간) ===');
    debugPrint('[TrainSim] 전체: ${_segments.length}세그먼트, API ${observed.length}대, 비교 $matched대');
    debugPrint('[TrainSim] 평균오차: ${avgError}m / 최대: ${maxError}m');

    // 노선별 요약
    final lineNames = SubwayColors.lineNames;
    for (final entry in lineStats.entries) {
      final id = entry.key;
      final count = entry.value[0];
      final avgErr = count > 0 ? entry.value[1] ~/ count : 0;
      final name = lineNames[id] ?? id;
      final sample = samplePerLine[id] ?? '';
      debugPrint('[TrainSim] $name: ${count}대 평균${avgErr}m');
      if (sample.isNotEmpty) debugPrint(sample);
    }
  }

  /// trainStatus → 구간 내 진행률 (0~1)
  double _statusToProgress(int status) {
    switch (status) {
      case 2: return 0.05;  // 출발
      case 3: return 0.30;  // 이동중
      case 0: return 0.85;  // 곧 도착
      case 1: return 1.00;  // 정차
      default: return 0.50;
    }
  }

  /// 역 도착 콜백 (overlay에서 추가 API 호출 트리거)
  VoidCallback? onTrainArrivedAtStation;
  bool _arrivalTriggered = false;

  /// 구간 완료된 열차 → 다음 역으로 자동 전진
  void _advanceCompletedSegments(int nowMs) {
    final rg = _routeGeometry;
    if (rg == null) return;

    for (final entry in _segments.entries.toList()) {
      final seg = entry.value;
      if (!seg.isComplete(nowMs)) continue;

      // 정차 시간 확인
      final stations = SeoulSubwayData.getExpressStations(seg.subwayId, seg.expressType);
      final schedule = _getSchedule(seg.subwayId, seg.expressType);
      final dwellMs = (schedule.getStationDwell(seg.toStationIdx) * 1000).round();

      if (nowMs < seg.arrivalMs + seg.delayMs + dwellMs) continue; // 아직 정차중

      // 역 도착 → 추가 API 호출 트리거 (30초 쿨다운)
      if (!_arrivalTriggered) {
        _arrivalTriggered = true;
        onTrainArrivedAtStation?.call();
        Future.delayed(const Duration(seconds: 15), () => _arrivalTriggered = false);
      }

      // 다음 구간 생성
      final isUp = seg.direction == 0;
      final nextFromIdx = seg.toStationIdx;
      int nextToIdx;
      if (isUp) {
        nextToIdx = nextFromIdx > 0 ? nextFromIdx - 1 : -1;
      } else {
        nextToIdx = nextFromIdx < stations.length - 1 ? nextFromIdx + 1 : -1;
      }

      if (nextToIdx < 0 || nextToIdx >= stations.length) {
        // 종점 도달 — 세그먼트 유지 (API가 다음 방향 알려줄 때까지)
        continue;
      }

      // 핵심: 이전 세그먼트의 endDistM을 그대로 사용 (rg 재조회 X → 점프 방지)
      final fromDist = seg.endDistM;
      final toDist = rg.getStationDistance(seg.subwayId, stations[nextToIdx].name);
      if (toDist == null) continue;

      // 실측 소요시간 우선
      final advSegKey = '${seg.subwayId}_${min(nextFromIdx, nextToIdx)}_${max(nextFromIdx, nextToIdx)}';
      var travelMs = _observedTravelMs[advSegKey] ??
          (schedule.getTravelSec(min(nextFromIdx, nextToIdx), max(nextFromIdx, nextToIdx)) * 1000).round();

      // 속도 자동 보정: pendingCorrection이 양수(앞서감)면 다음 구간 더 느리게
      // pendingCorrection이 음수(뒤처짐)면 다음 구간 더 빠르게
      final correction = seg.pendingCorrectionMs.clamp(-30000, 30000);
      if (correction > 0) {
        // 앞서감 → 다음 구간 소요시간 늘리기 (최대 50% 증가)
        travelMs = (travelMs * (1.0 + (correction / 30000.0) * 0.5)).round();
      } else if (correction < 0) {
        // 뒤처짐 → 다음 구간 소요시간 줄이기 (최대 30% 감소)
        travelMs = (travelMs * (1.0 + (correction / 30000.0) * 0.3)).round();
      }
      travelMs = travelMs.clamp(10000, 600000); // 최소 10초, 최대 10분

      final newDepartureMs = nowMs;

      _segments[entry.key] = TrainSegment.create(
        trainNo: seg.trainNo,
        subwayId: seg.subwayId,
        subwayName: seg.subwayName,
        direction: seg.direction,
        expressType: seg.expressType,
        terminalName: seg.terminalName,
        isLastTrain: seg.isLastTrain,
        startDistM: fromDist,
        endDistM: toDist,
        startStationName: stations[nextFromIdx].name,
        endStationName: stations[nextToIdx].name,
        departureMs: newDepartureMs,
        arrivalMs: newDepartureMs + travelMs,
        fromStationIdx: nextFromIdx,
        toStationIdx: nextToIdx,
        delayMs: 0, // delay 리셋 — 새 구간은 깨끗하게 시작
        confidence: seg.confidence,
      );
    }
  }

  /// 보간 데이터 존재 여부
  bool get hasContinuousData => _segments.isNotEmpty;

  /// 매 프레임: 순수 함수로 전 열차 위치 계산 (상태 변이 없음)
  List<InterpolatedTrainPosition> getFramePositions() {
    if (_segments.isEmpty) return [];

    final rg = _routeGeometry;
    if (rg == null) return [];

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 완료된 세그먼트 자동 전진
    _advanceCompletedSegments(nowMs);

    final results = <InterpolatedTrainPosition>[];

    for (final seg in _segments.values) {
      // 순수 함수: 현재시각 → 경로 거리 (달리는 중 변경 없음)
      final dist = seg.trackDistance(nowMs);

      // 경로 거리 → 좌표
      final pos = rg.positionAtDistance(seg.subwayId, dist);
      if (pos == null) continue;

      final bearing = rg.bearingAtDistance(seg.subwayId, dist);
      final status = seg.displayStatus(nowMs);
      final stationName = seg.displayStation(nowMs);

      // 지하/지상 판별 (가장 가까운 역 기준)
      bool isUnderground = true;
      final stations = SeoulSubwayData.getLineStations(seg.subwayId);
      for (final s in stations) {
        final sDist = rg.getStationDistance(seg.subwayId, s.name);
        if (sDist != null && (sDist - dist).abs() < 500) {
          isUnderground = !SeoulSubwayData.isSurfaceStation(s.id);
          break;
        }
      }

      results.add(InterpolatedTrainPosition(
        trainNo: seg.trainNo,
        subwayId: seg.subwayId,
        subwayName: seg.subwayName,
        lat: pos[0],
        lng: pos[1],
        altitude: 0,
        isUnderground: isUnderground,
        direction: seg.direction,
        terminalName: seg.terminalName,
        stationName: stationName,
        trainStatus: status,
        expressType: seg.expressType,
        isLastTrain: seg.isLastTrain,
        bearing: bearing,
      ));
    }

    return results;
  }

  /// 역명으로 역 인덱스 검색 (부분 매칭 지원)
  int _findStationIdx(List<StationInfo> stations, String name) {
    for (int i = 0; i < stations.length; i++) {
      if (stations[i].name == name) return i;
    }
    for (int i = 0; i < stations.length; i++) {
      if (stations[i].name.contains(name) || name.contains(stations[i].name)) {
        return i;
      }
    }
    return -1;
  }

  /// 급행 통과 중인 열차의 가장 가까운 정차역 인덱스 찾기
  int _findNearestExpressStopIdx(
    List<StationInfo> expressStations,
    List<StationInfo> allStations,
    int allIdx,
    bool isUpbound,
  ) {
    for (int i = 0; i < expressStations.length - 1; i++) {
      final fromAllIdx = _findStationIdx(allStations, expressStations[i].name);
      final toAllIdx = _findStationIdx(allStations, expressStations[i + 1].name);
      if (fromAllIdx < 0 || toAllIdx < 0) continue;
      final lo = min(fromAllIdx, toAllIdx);
      final hi = max(fromAllIdx, toAllIdx);
      if (allIdx >= lo && allIdx <= hi) {
        return isUpbound ? i : i + 1;
      }
    }
    double minDist = double.infinity;
    int nearest = 0;
    for (int i = 0; i < expressStations.length; i++) {
      final d = (expressStations[i].lat - allStations[allIdx].lat).abs() +
                (expressStations[i].lng - allStations[allIdx].lng).abs();
      if (d < minDist) { minDist = d; nearest = i; }
    }
    return nearest;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * pi / 180;
    final lat1R = lat1 * pi / 180;
    final lat2R = lat2 * pi / 180;
    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// 종점에서 진행 방향 베어링 추정
  double _calcDirectionBearing(List<StationInfo> stations, int idx, bool isUp) {
    if (isUp && idx > 0) {
      return _bearingBetween(
        stations[idx].lat, stations[idx].lng,
        stations[idx - 1].lat, stations[idx - 1].lng,
      );
    } else if (!isUp && idx < stations.length - 1) {
      return _bearingBetween(
        stations[idx].lat, stations[idx].lng,
        stations[idx + 1].lat, stations[idx + 1].lng,
      );
    }
    return 0;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 노선별 역간 시간표 스케줄 빌드
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 노선+급행유형별 스케줄 캐시 조회 (없으면 생성)
  _LineSchedule _getSchedule(String lineId, int expressType) {
    final key = '${lineId}_$expressType';
    return _scheduleCache.putIfAbsent(key, () {
      final stations = SeoulSubwayData.getExpressStations(lineId, expressType);
      if (expressType != 0) {
        // 급행: 일반 스케줄의 구간 시간을 합산하여 생성
        final normalSchedule = _getSchedule(lineId, 0);
        final allStations = SeoulSubwayData.getLineStations(lineId);
        return _buildExpressSchedule(stations, allStations, normalSchedule, expressType);
      }
      return _buildScheduleFromStations(stations, 1.0);
    });
  }

  /// 역 데이터에서 스케줄 구축
  /// StationInfo.travelNextSec/dwellSec가 있으면 실제 시간표 사용,
  /// 없으면(0) 좌표 기반 거리 계산으로 폴백
  _LineSchedule _buildScheduleFromStations(List<StationInfo> stations, double speedFactor) {
    // 30km/h로 보수적 추정 (거리 기반은 항상 짧게 나오므로)
    const avgSpeedKmh = 30.0;
    const accelOverheadSec = 20.0;

    final travel = <double>[];
    final dwell = <double>[];

    for (int i = 0; i < stations.length; i++) {
      final s = stations[i];

      // 정차시간: 실제 데이터 우선, 없으면 역 유형별 기본값
      if (s.dwellSec > 0) {
        dwell.add(s.dwellSec.toDouble());
      } else if (i == 0 || i == stations.length - 1) {
        dwell.add(45.0);
      } else if (s.transferLines.length >= 2) {
        dwell.add(35.0);
      } else if (s.transferLines.isNotEmpty) {
        dwell.add(25.0);
      } else {
        dwell.add(20.0);
      }

      // 주행시간: 실제 데이터 우선, 없으면 거리 기반 계산
      if (i < stations.length - 1) {
        if (s.travelNextSec > 0) {
          travel.add(s.travelNextSec.toDouble() * speedFactor);
        } else {
          final dist = _distanceKm(
            stations[i].lat, stations[i].lng,
            stations[i + 1].lat, stations[i + 1].lng,
          );
          final baseSec = dist / avgSpeedKmh * 3600.0 + accelOverheadSec;
          travel.add((baseSec * speedFactor).clamp(40.0, 400.0));
        }
      }
    }

    return _LineSchedule(travelSec: travel, dwellSec: dwell);
  }

  /// 급행 스케줄: 일반 구간 시간을 합산 + 속도 계수 적용
  _LineSchedule _buildExpressSchedule(
    List<StationInfo> expressStations,
    List<StationInfo> allStations,
    _LineSchedule normalSchedule,
    int expressType,
  ) {
    final speedFactor = expressType == 7 ? superExpressSpeedFactor : expressSpeedFactor;
    final travel = <double>[];
    final dwell = <double>[];

    for (int i = 0; i < expressStations.length; i++) {
      // 정차시간
      final s = expressStations[i];
      if (i == 0 || i == expressStations.length - 1) {
        dwell.add(45.0);
      } else if (s.transferLines.length >= 2) {
        dwell.add(35.0);
      } else if (s.transferLines.isNotEmpty) {
        dwell.add(25.0);
      } else {
        dwell.add(20.0);
      }

      // 급행 구간 주행시간 = 일반 구간 주행시간 합산 × 속도계수
      if (i < expressStations.length - 1) {
        final fromAll = _findStationIdx(allStations, expressStations[i].name);
        final toAll = _findStationIdx(allStations, expressStations[i + 1].name);
        if (fromAll >= 0 && toAll >= 0) {
          double sumTravel = 0;
          final lo = min(fromAll, toAll);
          final hi = max(fromAll, toAll);
          for (int j = lo; j < hi && j < normalSchedule.travelSec.length; j++) {
            sumTravel += normalSchedule.travelSec[j];
          }
          // 급행은 중간역 정차 안 함 → 정차시간 빼고, 속도 계수 적용
          travel.add((sumTravel * speedFactor).clamp(40.0, 600.0));
        } else {
          // 폴백: 거리 기반
          final dist = _distanceKm(
            expressStations[i].lat, expressStations[i].lng,
            expressStations[i + 1].lat, expressStations[i + 1].lng,
          );
          travel.add((dist / 35.0 * 3600.0 * speedFactor + 15.0).clamp(40.0, 600.0));
        }
      }
    }

    return _LineSchedule(travelSec: travel, dwellSec: dwell);
  }

  /// 두 지점 사이 거리 (km) — 서울 위도 근사
  static double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const kmPerDegLat = 111.32;
    final kmPerDegLng = 111.32 * cos(lat1 * pi / 180);
    final dLat = (lat2 - lat1) * kmPerDegLat;
    final dLng = (lng2 - lng1) * kmPerDegLng;
    return sqrt(dLat * dLat + dLng * dLng);
  }

  /// 피크 시간 판별
  bool _isPeakHour() {
    final hour = DateTime.now().hour;
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  /// 시뮬레이션 열차의 현재 위치 계산
  _SimPosition? _calcSimPosition(
    _SimTrain sim,
    List<StationInfo> stations,
    double todaySec, [
    double? overrideSegmentDuration,
  ]) {
    final segDuration = overrideSegmentDuration ?? segmentDurationSec;
    final elapsed = todaySec + sim.offsetSec;
    final totalStations = stations.length;
    final roundTripSegments = (totalStations - 1) * 2;
    final cycleDuration = roundTripSegments * segDuration;

    // ���재 사���클 내 위치
    final cyclePos = elapsed % cycleDuration;
    final segmentIndex = (cyclePos / segDuration).floor();
    final segmentFrac = (cyclePos % segDuration) / segDuration;

    // 왕복 경로에서 실제 역 인덱스 계산
    bool isUpbound;
    int stationIdx;
    if (segmentIndex < totalStations - 1) {
      // 하행
      isUpbound = false;
      stationIdx = segmentIndex;
    } else {
      // 상행 (되돌아오는 중)
      isUpbound = true;
      stationIdx = roundTripSegments - segmentIndex;
    }
    stationIdx = stationIdx.clamp(0, totalStations - 1);

    // 구간 내 진행률 → trainStatus
    // 주행(0~83%) + 정차(83~100%) 비율 반영
    int status;
    if (segmentFrac < 0.05) {
      status = 2; // 출발 (이전역 떠남)
    } else if (segmentFrac < 0.40) {
      status = 3; // 전역출발 (역간 전반부)
    } else if (segmentFrac < 0.75) {
      status = 0; // 진입 (다음역 접근)
    } else {
      status = 1; // 도착 (역 정차 중)
    }

    return _SimPosition(
      stationIndex: stationIdx,
      isUpbound: isUpbound,
      status: status,
    );
  }
}

/// 시뮬레이션 열차 내부 상태
class _SimTrain {
  final String trainNo;
  final String lineId;
  final int stationCount;
  final double offsetSec;
  final bool isUpbound;
  final int expressType; // 0:일반, 1:급행, 7:특급(초���행)

  const _SimTrain({
    required this.trainNo,
    required this.lineId,
    required this.stationCount,
    required this.offsetSec,
    required this.isUpbound,
    required this.expressType,
  });
}

/// 계산된 시뮬레이션 위치
class _SimPosition {
  final int stationIndex;
  final bool isUpbound;
  final int status;

  const _SimPosition({
    required this.stationIndex,
    required this.isUpbound,
    required this.status,
  });
}

/// 노선별 역간 시간표 스케줄
/// 역 좌표 기반 거리 계산으로 구간별 소요시간을 산출
class _LineSchedule {
  /// ��간별 주행시간 (초): travelSec[i] = station[i] → station[i+1]
  final List<double> travelSec;
  /// 역별 정차시간 (초): dwellSec[i] = station[i]에���의 정차
  final List<double> dwellSec;

  const _LineSchedule({required this.travelSec, required this.dwellSec});

  /// 특정 구���의 주행시간 (인덱스 방향 무관)
  double getTravelSec(int fromIdx, int toIdx) {
    final segIdx = fromIdx < toIdx ? fromIdx : toIdx;
    if (segIdx < 0 || segIdx >= travelSec.length) return 100.0;
    return travelSec[segIdx];
  }

  /// 특정 구간의 총 소요시간 (주행 + 도착역 정차)
  double getFullSec(int fromIdx, int toIdx) {
    final travel = getTravelSec(fromIdx, toIdx);
    final arrivalIdx = fromIdx < toIdx ? toIdx : fromIdx;
    final dwell = arrivalIdx < dwellSec.length ? dwellSec[arrivalIdx] : 20.0;
    return travel + dwell;
  }

  /// 특정 역의 정차시간
  double getStationDwell(int stationIdx) {
    if (stationIdx < 0 || stationIdx >= dwellSec.length) return 20.0;
    return dwellSec[stationIdx];
  }

  /// 전체 편도 소요시간 (디버그용)
  double get totalOneWaySec {
    double sum = 0;
    for (int i = 0; i < travelSec.length; i++) {
      sum += travelSec[i] + (i + 1 < dwellSec.length ? dwellSec[i + 1] : 20.0);
    }
    return sum;
  }
}


/// 열차 관측 기록 (실시간 속도 학습용)
class _TrainObservation {
  final String stationName;
  final int stationIdx;
  final int timeMs;
  const _TrainObservation(this.stationName, this.stationIdx, this.timeMs);
}
