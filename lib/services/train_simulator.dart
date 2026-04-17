import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';

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

  // 노선별 시뮬레이션된 열차 상태
  final Map<String, List<_SimTrain>> _simTrains = {};

  // 마지막 API 스냅샷 시간 (보간 모드용)
  DateTime? _lastApiTime;
  // 마지막 API 스냅샷 데이터
  List<TrainPosition> _lastApiSnapshot = [];

  // 연속 보간용 프리컴퓨트 상태
  final Map<String, _LiveTrainState> _liveStates = {};

  /// 데모 모드: 노선별 가상 열차 초기 배치
  /// 피크 시간(07-09, 17-19)은 배차간격 3분, 그 외 5분
  void initDemoTrains() {
    _simTrains.clear();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      final stations = SeoulSubwayData.getLineStations(lineId);
      if (stations.length < 2) continue;

      final isPeak = _isPeakHour();
      final headwayMin = isPeak ? 3.0 : 6.0;
      // 편도 소요시간(분) = (역수-1) × 역간소요(분)
      final segments = stations.length - 1;
      final oneWayMin = segments * (segmentDurationSec / 60.0);
      // 노선 위 총 열차 수 = 왕복 소요시간 / 배차간격 (상행+하행)
      final trainCount = max(2, (oneWayMin * 2 / headwayMin).round());

      final trains = <_SimTrain>[];
      for (int i = 0; i < trainCount; i++) {
        // 균등 분포: 각 열차의 시작 오프셋
        final offset = (i / trainCount) * oneWayMin * 2 * 60; // 초
        final isUpbound = i % 2 == 0;
        trains.add(_SimTrain(
          trainNo: '${lineId}D${i.toString().padLeft(3, '0')}',
          lineId: lineId,
          stationCount: stations.length,
          offsetSec: offset,
          isUpbound: isUpbound,
          isExpress: i % 7 == 0, // 약 14% 급행
        ));
      }
      _simTrains[lineId] = trains;
    }

    debugPrint('[TrainSimulator] 데모 열차 초기화: '
        '${_simTrains.values.fold<int>(0, (s, l) => s + l.length)}개');
  }

  /// 현재 시각 기준 시뮬레이션된 열차 위치 목록 생성
  List<TrainPosition> generateDemoPositions() {
    final now = DateTime.now();
    // 자정 기준 경과 초
    final todaySec = now.hour * 3600.0 + now.minute * 60.0 + now.second + now.millisecond / 1000.0;
    final results = <TrainPosition>[];

    for (final entry in _simTrains.entries) {
      final lineId = entry.key;
      final lineName = SeoulSubwayData.lineIdToApiName[lineId] ?? lineId;
      final stations = SeoulSubwayData.getLineStations(lineId);
      if (stations.length < 2) continue;

      for (final sim in entry.value) {
        final pos = _calcSimPosition(sim, stations, todaySec);
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
          trainStatus: pos.status, // 0:진입, 1:도착, 2:출발, 3:전역출발
          expressType: sim.isExpress ? 1 : 0,
          isLastTrain: false,
        ));
      }
    }
    return results;
  }

  /// API 스냅샷을 기록하고 보간 모드용으로 저장
  void updateApiSnapshot(List<TrainPosition> positions) {
    _lastApiTime = DateTime.now();
    _lastApiSnapshot = List.from(positions);
  }

  /// 보간 모드: API 스냅샷 + 경과 시간을 기반으로 열차 위치 추정
  /// API에서 받은 마지막 위치로부터 시간표 속도만큼 전진시킴
  List<TrainPosition> extrapolateFromSnapshot() {
    if (_lastApiSnapshot.isEmpty || _lastApiTime == null) {
      return [];
    }

    final elapsedSec = DateTime.now().difference(_lastApiTime!).inMilliseconds / 1000.0;
    if (elapsedSec < 1) return _lastApiSnapshot;

    // 경과 시간에 비례하여 열차 상태 전진
    final advanced = <TrainPosition>[];
    for (final train in _lastApiSnapshot) {
      final stations = SeoulSubwayData.getLineStations(train.subwayId);
      if (stations.isEmpty) {
        advanced.add(train);
        continue;
      }

      // 현재 역 인덱스 찾기
      int stIdx = -1;
      for (int i = 0; i < stations.length; i++) {
        if (stations[i].name == train.stationName ||
            stations[i].name.contains(train.stationName) ||
            train.stationName.contains(stations[i].name)) {
          stIdx = i;
          break;
        }
      }
      if (stIdx < 0) {
        advanced.add(train);
        continue;
      }

      // 경과 시간 → 몇 구간 전진?
      final segmentsAdvanced = elapsedSec / segmentDurationSec;
      final fullSegments = segmentsAdvanced.floor();
      final frac = segmentsAdvanced - fullSegments;

      final isUpbound = train.direction == 0;
      int newIdx = stIdx;

      if (isUpbound) {
        newIdx = (stIdx - fullSegments).clamp(0, stations.length - 1);
      } else {
        newIdx = (stIdx + fullSegments).clamp(0, stations.length - 1);
      }

      // 구간 내 진행률 → trainStatus 변환
      int newStatus;
      if (frac < 0.15) {
        newStatus = 2; // 출발
      } else if (frac < 0.5) {
        newStatus = 3; // 전역출발 (중간)
      } else if (frac < 0.85) {
        newStatus = 0; // 진입
      } else {
        newStatus = 1; // 도착
      }

      advanced.add(TrainPosition(
        subwayId: train.subwayId,
        subwayName: train.subwayName,
        stationId: stations[newIdx].id,
        stationName: stations[newIdx].name,
        trainNo: train.trainNo,
        lastRecvDate: train.lastRecvDate,
        recvTime: train.recvTime,
        direction: train.direction,
        terminalId: train.terminalId,
        terminalName: train.terminalName,
        trainStatus: newStatus,
        expressType: train.expressType,
        isLastTrain: train.isLastTrain,
      ));
    }
    return advanced;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 연속 보간 (60fps Live 모드)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// API 스냅샷을 기반으로 연속 보간용 상태를 프리컴퓨트
  /// updateApiSnapshot() 호출 후 반드시 호출해야 함
  void prepareContinuousExtrapolation() {
    _liveStates.clear();
    for (final train in _lastApiSnapshot) {
      final stations = SeoulSubwayData.getLineStations(train.subwayId);
      if (stations.length < 2) continue;

      final stIdx = _findStationIdx(stations, train.stationName);
      if (stIdx < 0) continue;

      final isUpbound = train.direction == 0;
      int fromIdx, toIdx;
      double timeSec;

      switch (train.trainStatus) {
        case 2: // 출발: stationName을 막 떠남 → 다음역 방향
          fromIdx = stIdx;
          toIdx = isUpbound
              ? (stIdx > 0 ? stIdx - 1 : stIdx)
              : (stIdx < stations.length - 1 ? stIdx + 1 : stIdx);
          timeSec = avgInterStationSec * 0.05;
          break;
        case 3: // 전역출발: 이전역 떠남 → stationName으로 향하는 중 (30%)
          toIdx = stIdx;
          fromIdx = isUpbound
              ? (stIdx < stations.length - 1 ? stIdx + 1 : stIdx)
              : (stIdx > 0 ? stIdx - 1 : stIdx);
          timeSec = avgInterStationSec * 0.30;
          break;
        case 0: // 진입: stationName에 거의 도착 (85%)
          toIdx = stIdx;
          fromIdx = isUpbound
              ? (stIdx < stations.length - 1 ? stIdx + 1 : stIdx)
              : (stIdx > 0 ? stIdx - 1 : stIdx);
          timeSec = avgInterStationSec * 0.85;
          break;
        case 1: // 도착: stationName에 정차 중 (dwell phase)
          toIdx = stIdx;
          fromIdx = isUpbound
              ? (stIdx < stations.length - 1 ? stIdx + 1 : stIdx)
              : (stIdx > 0 ? stIdx - 1 : stIdx);
          timeSec = avgInterStationSec + dwellTimeSec * 0.5; // dwell 중간
          break;
        default:
          fromIdx = stIdx;
          toIdx = stIdx;
          timeSec = 0;
      }

      _liveStates[train.trainNo] = _LiveTrainState(
        snapshot: train,
        stations: stations,
        segmentFromIdx: fromIdx,
        segmentToIdx: toIdx,
        segmentTimeSec: timeSec,
        isUpbound: isUpbound,
      );
    }
    debugPrint('[TrainSimulator] 연속 보간 준비 완료: ${_liveStates.length}개 열차');
  }

  /// 연속 보간 준비가 되었는지 확인
  bool get hasContinuousData => _liveStates.isNotEmpty && _lastApiTime != null;

  /// 매 프레임 호출: API 스냅샷 시점부터 경과 시간 기반으로 정밀 위치 계산
  /// 60fps에서도 가볍게 동작하도록 프리컴퓨트된 상태만 사용
  List<InterpolatedTrainPosition> getFramePositions() {
    if (_liveStates.isEmpty || _lastApiTime == null) return [];

    final elapsedSec =
        DateTime.now().difference(_lastApiTime!).inMilliseconds / 1000.0;
    final results = <InterpolatedTrainPosition>[];

    for (final state in _liveStates.values) {
      final stations = state.stations;
      final totalTime = state.segmentTimeSec + elapsedSec;

      // 전체 경과 시간에서 구간 수 + 남은 시간 분리
      final fullSegments = (totalTime / segmentDurationSec).floor();
      final remainingTime = totalTime % segmentDurationSec;

      // 스냅샷 시점의 구간에서 fullSegments만큼 전진
      int fromIdx = state.segmentFromIdx;
      int toIdx = state.segmentToIdx;

      for (int i = 0; i < fullSegments; i++) {
        // 다음 구간으로 이동: 현재 toIdx가 새 fromIdx
        fromIdx = toIdx;
        if (state.isUpbound) {
          toIdx = fromIdx > 0 ? fromIdx - 1 : fromIdx;
        } else {
          toIdx = fromIdx < stations.length - 1 ? fromIdx + 1 : fromIdx;
        }
        // 종점 도달 시 정지
        if (fromIdx == toIdx) break;
      }

      // 현재 구간 내 위치 계산
      double t;
      int displayStatus;
      if (fromIdx == toIdx) {
        // 종점에 정차
        t = 0.0;
        displayStatus = 1;
      } else if (remainingTime < avgInterStationSec) {
        // 주행 중: 역간 이동
        final rawT = remainingTime / avgInterStationSec;
        // ease-in-out으로 가감속 시뮬레이션 (출발 시 가속, 도착 전 감속)
        t = rawT * rawT * (3.0 - 2.0 * rawT);
        if (rawT < 0.15) {
          displayStatus = 2; // 출발
        } else if (rawT < 0.50) {
          displayStatus = 3; // 전역출발 (중간)
        } else if (rawT < 0.85) {
          displayStatus = 0; // 진입
        } else {
          displayStatus = 0; // 진입 (거의 도착)
        }
      } else {
        // 정차 중 (dwell phase)
        t = 1.0;
        displayStatus = 1;
      }

      final lat = _lerp(stations[fromIdx].lat, stations[toIdx].lat, t);
      final lng = _lerp(stations[fromIdx].lng, stations[toIdx].lng, t);

      // 베어링 계산
      double bearing;
      if (fromIdx == toIdx) {
        bearing = state.isUpbound
            ? _calcDirectionBearing(stations, toIdx, true)
            : _calcDirectionBearing(stations, toIdx, false);
      } else {
        bearing = _bearingBetween(
          stations[fromIdx].lat, stations[fromIdx].lng,
          stations[toIdx].lat, stations[toIdx].lng,
        );
      }

      // 지하/지상 구분
      final isUnderground = fromIdx == toIdx
          ? !SeoulSubwayData.isSurfaceStation(stations[fromIdx].id)
          : !SeoulSubwayData.isSurfaceStation(stations[toIdx].id);

      results.add(InterpolatedTrainPosition(
        trainNo: state.snapshot.trainNo,
        subwayId: state.snapshot.subwayId,
        subwayName: state.snapshot.subwayName,
        lat: lat,
        lng: lng,
        altitude: 0,
        isUnderground: isUnderground,
        direction: state.snapshot.direction,
        terminalName: state.snapshot.terminalName,
        stationName: stations[toIdx].name,
        trainStatus: displayStatus,
        expressType: state.snapshot.expressType,
        isLastTrain: state.snapshot.isLastTrain,
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

  /// 피크 시간 판별
  bool _isPeakHour() {
    final hour = DateTime.now().hour;
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  /// 시뮬레이션 열차의 현재 위치 계산
  _SimPosition? _calcSimPosition(
    _SimTrain sim,
    List<StationInfo> stations,
    double todaySec,
  ) {
    // 운행 시간: 05:30 ~ 24:00 (다음날 00:00)
    const startSec = 5 * 3600 + 30 * 60; // 05:30
    const endSec = 24 * 3600; // 24:00
    if (todaySec < startSec || todaySec > endSec) return null;

    final elapsed = todaySec - startSec + sim.offsetSec;
    final totalStations = stations.length;
    // 왕복 구간 수 = (역수-1) * 2
    final roundTripSegments = (totalStations - 1) * 2;
    final cycleDuration = roundTripSegments * segmentDurationSec;

    // 현재 사이클 내 위치
    final cyclePos = elapsed % cycleDuration;
    final segmentIndex = (cyclePos / segmentDurationSec).floor();
    final segmentFrac = (cyclePos % segmentDurationSec) / segmentDurationSec;

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
  final bool isExpress;

  const _SimTrain({
    required this.trainNo,
    required this.lineId,
    required this.stationCount,
    required this.offsetSec,
    required this.isUpbound,
    required this.isExpress,
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

/// 연속 보간용 프리컴퓨트 열차 상태
class _LiveTrainState {
  final TrainPosition snapshot;
  final List<StationInfo> stations;
  final int segmentFromIdx;
  final int segmentToIdx;
  final double segmentTimeSec; // 스냅샷 시점에서 현재 구간 내 경과 시간
  final bool isUpbound;

  const _LiveTrainState({
    required this.snapshot,
    required this.stations,
    required this.segmentFromIdx,
    required this.segmentToIdx,
    required this.segmentTimeSec,
    required this.isUpbound,
  });
}
