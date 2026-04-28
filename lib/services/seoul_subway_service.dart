import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_keys.dart';
import '../models/subway_models.dart';

/// 서울시 지하철 공공데이터 API 연동 서비스
/// 5개 데이터 소스:
/// 1. 실시간 열차 위치정보 (OA-12601)
/// 2. 실시간 도착정보 (OA-12764)
/// 3. 실시간 도착정보 일괄 (OA-15799)
/// 4. 지하철역 연계 지하도 공간정보 (OA-21213)
/// 5. 지하철 출입구 리프트 위치정보 (OA-21211)
class SeoulSubwayService {
  static const String _baseUrl = 'http://swopenAPI.seoul.go.kr/api/subway';

  /// 전체 노선 목록
  static const List<String> allLineNames = [
    '1호선', '2호선', '3호선', '4호선', '5호선',
    '6호선', '7호선', '8호선', '9호선',
    '경의중앙선', '공항철도', '경춘선', '수인분당선', '신분당선', '우이신설선', 'GTX-A',
    '서해선', '신림선', '경강선',
  ];

  String get _apiKey => ApiKeys.seoulApiKey;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // API 호출 예산 관리 (일일 1,000건 제한 대응)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const int dailyLimit = 1000;

  int _callCount = 0;
  DateTime _countResetDate = DateTime.now();

  /// 오늘 사용한 API 호출 수
  int get callCount {
    _resetIfNewDay();
    return _callCount;
  }

  /// 오늘 남은 API 호출 수
  int get remainingCalls => (dailyLimit - callCount).clamp(0, dailyLimit);

  /// 현재 호출 상황에 맞는 권장 갱신 주기(초)
  int get recommendedIntervalSec {
    final remaining = remainingCalls;
    if (remaining <= 50) return 0; // 중단 권고
    if (remaining <= 100) return 600; // 10분
    if (remaining <= 300) return 420; // 7분
    return 300; // 5분 (기본)
  }

  /// 심야 시간(01:00~05:00)이면 true — 열차 미운행
  bool get isNonOperatingHours {
    final hour = DateTime.now().hour;
    return hour >= 1 && hour < 5;
  }

  void _resetIfNewDay() {
    final now = DateTime.now();
    if (now.day != _countResetDate.day ||
        now.month != _countResetDate.month ||
        now.year != _countResetDate.year) {
      _callCount = 0;
      _countResetDate = now;
      debugPrint('[SeoulSubwayAPI] 🔄 일일 호출 카운터 리셋');
    }
  }

  void _incrementCallCount() {
    _resetIfNewDay();
    _callCount++;
  }

  // 마지막 API 에러 메시지 (디버깅용)
  String? lastApiError;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 1. 실시간 열차 위치정보 (realtimePosition)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 특정 노선의 실시간 열차 위치 조회
  Future<List<TrainPosition>> fetchTrainPositions(String lineName) async {
    if (remainingCalls <= 0) {
      debugPrint('[SeoulSubwayAPI] 🚫 일일 호출 한도 소진 ($dailyLimit/$dailyLimit)');
      throw SeoulApiException('일일 API 호출 한도($dailyLimit건) 소진', code: 'LIMIT');
    }

    final url = '$_baseUrl/$_apiKey/json/realtimePosition/0/200/$lineName';
    try {
      _incrementCallCount();
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['realtimePositionList'] != null) {
          final list = data['realtimePositionList'] as List;
          debugPrint('[SeoulSubwayAPI] ✅ $lineName: ${list.length}개 열차 (남은 호출: $remainingCalls)');
          return list.map((e) => TrainPosition.fromJson(e)).toList();
        }
        // API 에러 응답 처리
        if (data['status'] != null && data['status'] != 200) {
          final msg = data['message'] ?? 'API error';
          final code = data['code'] ?? '';
          debugPrint('[SeoulSubwayAPI] ❌ $lineName 에러 응답: [$code] $msg');
          developer.log('API error: [$code] $msg', name: 'SeoulSubwayAPI');
          throw SeoulApiException(msg, code: code);
        }
        debugPrint('[SeoulSubwayAPI] ⚠️ $lineName: 데이터 없음 (status=${response.statusCode})');
      } else {
        debugPrint('[SeoulSubwayAPI] ❌ $lineName: HTTP ${response.statusCode}');
      }
      return [];
    } on TimeoutException {
      debugPrint('[SeoulSubwayAPI] ⏱️ $lineName: 요청 시간 초과');
      throw SeoulApiException('요청 시간 초과', code: 'TIMEOUT');
    } catch (e) {
      if (e is SeoulApiException) rethrow;
      debugPrint('[SeoulSubwayAPI] ❌ $lineName: 네트워크 오류 - $e');
      throw SeoulApiException('네트워크 오류: $e', code: 'NETWORK');
    }
  }

  /// 열차 위치 조회 — 지정된 노선만, 또는 전체
  /// [lineNames]를 지정하면 해당 노선만 호출 (호출 수 절약)
  Future<Map<String, List<TrainPosition>>> fetchAllTrainPositions({
    List<String>? lineNames,
  }) async {
    final targets = lineNames ?? allLineNames;

    // 심야 시간 체크
    if (isNonOperatingHours) {
      debugPrint('[SeoulSubwayAPI] 🌙 심야 시간(01~05시) — 열차 미운행, API 호출 건너뜀');
      lastApiError = '심야 시간(01~05시) 열차 미운행';
      return {};
    }

    // 남은 호출 수가 요청할 노선 수보다 적으면 중단
    if (remainingCalls < targets.length) {
      debugPrint('[SeoulSubwayAPI] 🚫 남은 호출($remainingCalls) < 요청 노선(${targets.length}), 중단');
      lastApiError = '일일 한도 부족 (남은: $remainingCalls건)';
      return {};
    }

    final results = <String, List<TrainPosition>>{};
    lastApiError = null;

    // 3개씩 배치로 나누어 호출
    const batchSize = 3;
    for (var i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      final futures = batch.map((name) async {
        try {
          final positions = await fetchTrainPositions(name);
          return MapEntry(name, positions);
        } catch (e) {
          debugPrint('[SeoulSubwayAPI] 🚨 $name 조회 실패: $e');
          lastApiError = '[$name] $e';
          return MapEntry(name, <TrainPosition>[]);
        }
      });

      final entries = await Future.wait(futures);
      for (final entry in entries) {
        if (entry.value.isNotEmpty) {
          results[entry.key] = entry.value;
        }
      }
    }
    final totalTrains = results.values.fold<int>(0, (sum, list) => sum + list.length);
    debugPrint('[SeoulSubwayAPI] 📊 결과: ${results.length}/${targets.length} 노선, '
        '$totalTrains개 열차 | 오늘 사용: $_callCount/$dailyLimit'
        '${lastApiError != null ? ' | 에러: $lastApiError' : ''}');
    return results;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 2. 실시간 도착정보 (realtimeStationArrival)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 특정 역의 실시간 도착 정보 조회
  Future<List<ArrivalInfo>> fetchStationArrivals(String stationName) async {
    // 1차: 원본 이름으로 시도
    var result = await _fetchArrivals(stationName);
    if (result.isNotEmpty) return result;

    // 2차: 괄호 제거 후 시도 (e.g. "총신대입구(이수)" → "총신대입구")
    final withoutParen = stationName.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    if (withoutParen != stationName) {
      result = await _fetchArrivals(withoutParen);
      if (result.isNotEmpty) return result;
    }

    return [];
  }

  Future<List<ArrivalInfo>> _fetchArrivals(String name) async {
    final url = '$_baseUrl/$_apiKey/json/realtimeStationArrival/0/20/$name';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['realtimeArrivalList'] != null) {
          final list = data['realtimeArrivalList'] as List;
          return list.map((e) => ArrivalInfo.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      if (e is SeoulApiException) rethrow;
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 3. 실시간 도착정보 일괄 (realtimeStationArrival/ALL)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 전체 역의 실시간 도착정보를 일괄 조회 (페이지네이션)
  Future<List<ArrivalInfo>> fetchAllStationArrivals({
    int startIndex = 0,
    int endIndex = 1000,
  }) async {
    final url = '$_baseUrl/$_apiKey/json/realtimeStationArrival/ALL/$startIndex/$endIndex';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['realtimeArrivalList'] != null) {
          final list = data['realtimeArrivalList'] as List;
          return list.map((e) => ArrivalInfo.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      if (e is SeoulApiException) rethrow;
      throw SeoulApiException('일괄 도착정보 조회 실패: $e', code: 'ALL_ARRIVAL');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 4. 지하철역 연계 지하도 공간정보 (OA-21213)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 지하도 공간 데이터 조회 (노드 + 링크)
  Future<Map<String, dynamic>> fetchUndergroundSpatialData({
    int startIndex = 1,
    int endIndex = 1000,
  }) async {
    final url = 'http://openapi.seoul.go.kr:8088/$_apiKey/json/tbLnOpendataSubwayUnderpassWgs/$startIndex/$endIndex';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rows = data['tbLnOpendataSubwayUnderpassWgs']?['row'] as List?;
        if (rows == null) return {'nodes': <UndergroundNode>[], 'links': <UndergroundLink>[]};

        final nodes = <UndergroundNode>[];
        final links = <UndergroundLink>[];

        for (final row in rows) {
          // 노드 파싱
          if (row['NODE_WKT'] != null && row['NODE_WKT'].toString().isNotEmpty) {
            final coords = _parseWktPoint(row['NODE_WKT'].toString());
            if (coords != null) {
              nodes.add(UndergroundNode(
                nodeId: row['NODE_ID']?.toString() ?? '',
                nodeType: row['NODE_TYPE_CD']?.toString() ?? '',
                lat: coords[1],
                lng: coords[0],
                stationCode: row['SBWY_STN_CD']?.toString() ?? '',
                stationName: row['SBWY_STN_NM']?.toString() ?? '',
                hasLift: row['LIFT']?.toString() == 'Y',
                hasElevator: row['ELVT']?.toString() == 'Y',
              ));
            }
          }

          // 링크 파싱
          if (row['LNKG_WKT'] != null && row['LNKG_WKT'].toString().isNotEmpty) {
            final lineCoords = _parseWktLineString(row['LNKG_WKT'].toString());
            links.add(UndergroundLink(
              linkId: row['LNKG_ID']?.toString() ?? '',
              linkType: row['LNKG_TYPE_CD']?.toString() ?? '',
              startNodeId: row['BGNG_LNKG_ID']?.toString() ?? '',
              endNodeId: row['END_LNKG_ID']?.toString() ?? '',
              length: double.tryParse(row['LNKG_LEN']?.toString() ?? '0') ?? 0,
              coordinates: lineCoords,
            ));
          }
        }
        return {'nodes': nodes, 'links': links};
      }
      return {'nodes': <UndergroundNode>[], 'links': <UndergroundLink>[]};
    } catch (e) {
      if (e is SeoulApiException) rethrow;
      throw SeoulApiException('지하도 공간정보 조회 실패: $e', code: 'SPATIAL');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 5. 지하철 출입구 리프트 위치정보 (OA-21211)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 지하철 출입구 리프트 위치 조회
  Future<List<SubwayLift>> fetchSubwayLifts({
    int startIndex = 1,
    int endIndex = 1000,
  }) async {
    final url = 'http://openapi.seoul.go.kr:8088/$_apiKey/json/tbLnOpendataSubwayLiftWgs/$startIndex/$endIndex';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rows = data['tbLnOpendataSubwayLiftWgs']?['row'] as List?;
        if (rows == null) return [];

        return rows.map((row) {
          final coords = _parseWktPoint(row['NODE_WKT']?.toString() ?? '');
          return SubwayLift(
            nodeId: row['NODE_ID']?.toString() ?? '',
            lat: coords?[1] ?? 0,
            lng: coords?[0] ?? 0,
            stationCode: row['SBWY_STN_CD']?.toString() ?? '',
            stationName: row['SBWY_STN_NM']?.toString() ?? '',
            districtName: row['SGG_NM']?.toString() ?? '',
          );
        }).where((lift) => lift.lat != 0 && lift.lng != 0).toList();
      }
      return [];
    } catch (e) {
      if (e is SeoulApiException) rethrow;
      throw SeoulApiException('리프트 위치정보 조회 실패: $e', code: 'LIFT');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 6. 열차별 지연 감지 (배차간격 비교)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// 개별 열차의 지연 시간(분)을 산출하여 반환
  ///
  /// 방법:
  /// 1) realtimeStationArrival/ALL 일괄 조회
  /// 2) (노선, 방향, 역) 그룹별로 열차를 barvlDt 순 정렬
  /// 3) 연속 열차 간 간격을 시간표 배차간격과 비교
  /// 4) 초과분이 있는 뒤쪽 열차에 지연 시간 부여
  /// 5) 같은 열차가 여러 역에서 감지되면 최대값 채택
  ///
  /// 반환: { trainNo: delayMinutes } — 2분 이상 지연 열차만 포함
  Future<Map<String, int>> fetchTrainDelays() async {
    if (isNonOperatingHours) return {};

    try {
      _incrementCallCount();
      final url = '$_baseUrl/$_apiKey/json/realtimeStationArrival/ALL/0/500';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return {};

      final data = jsonDecode(response.body);
      final list = data['realtimeArrivalList'] as List?;
      if (list == null) return {};

      final hour = DateTime.now().hour;
      final trainDelays = <String, int>{}; // trainNo → delayMinutes

      // ── Step 1: 키워드 감지 (즉각 지연 표시) ──
      const delayKeywords = ['지연', '서행', '운행중지', '운행 중지', '장애', '사고', '고장'];
      for (final item in list) {
        final msg2 = item['arvlMsg2']?.toString() ?? '';
        final msg3 = item['arvlMsg3']?.toString() ?? '';
        if (delayKeywords.any((kw) => '$msg2 $msg3'.contains(kw))) {
          final trainNo = item['btrainNo']?.toString() ?? '';
          if (trainNo.isNotEmpty) {
            trainDelays[trainNo] = trainDelays[trainNo] ?? 1; // 최소 1분
          }
        }
      }

      // ── Step 2: 배차간격 분석 — 개별 열차 지연 시간 산출 ──
      // (노선+방향+역) 그룹별로 { barvlDt, trainNo } 수집
      final grouped = <String, List<_ArrivalEntry>>{};
      for (final item in list) {
        final subwayId = item['subwayId']?.toString() ?? '';
        final direction = item['updnLine']?.toString() ?? '';
        final station = item['statnNm']?.toString() ?? '';
        final seconds = int.tryParse(item['barvlDt']?.toString() ?? '') ?? -1;
        final trainNo = item['btrainNo']?.toString() ?? '';
        if (seconds < 0 || subwayId.isEmpty || trainNo.isEmpty) continue;

        final key = '${subwayId}_${direction}_$station';
        grouped.putIfAbsent(key, () => []).add(
          _ArrivalEntry(trainNo: trainNo, seconds: seconds, subwayId: subwayId),
        );
      }

      for (final entry in grouped.entries) {
        final arrivals = entry.value..sort((a, b) => a.seconds.compareTo(b.seconds));
        if (arrivals.length < 2) continue;

        final subwayId = arrivals.first.subwayId;
        final expectedSec = _getExpectedHeadwaySec(subwayId, hour);

        for (int i = 1; i < arrivals.length; i++) {
          final gap = arrivals[i].seconds - arrivals[i - 1].seconds;
          if (gap < 30 || gap > 3600) continue;

          final delaySec = gap - expectedSec;
          if (delaySec < expectedSec * 0.5) continue;
          final delayMin = (delaySec / 60).round();
          if (delayMin < 2) continue;

          // 뒤쪽 열차(더 늦게 오는)에 지연 부여, 최대값 채택
          final trainNo = arrivals[i].trainNo;
          final prev = trainDelays[trainNo] ?? 0;
          if (delayMin > prev) {
            trainDelays[trainNo] = delayMin;
          }
        }
      }

      if (trainDelays.isNotEmpty) {
        debugPrint('[SeoulSubwayAPI] ⚠️ 열차 지연: ${trainDelays.length}대 — '
            '${trainDelays.entries.take(5).map((e) => '${e.key}(${e.value}분)').join(', ')}'
            '${trainDelays.length > 5 ? ' ...' : ''}');
      }
      return trainDelays;
    } catch (e) {
      debugPrint('[SeoulSubwayAPI] ❌ 지연 감지 실패: $e');
      return {};
    }
  }

  /// 노선 ID → 노선명 역매핑
  static const _subwayIdToName = {
    '1001': '1호선', '1002': '2호선', '1003': '3호선', '1004': '4호선',
    '1005': '5호선', '1006': '6호선', '1007': '7호선', '1008': '8호선',
    '1009': '9호선', '1063': '경의중앙선', '1065': '공항철도',
    '1067': '경춘선', '1075': '수인분당선', '1077': '신분당선',
    '1092': '우이신설선',
    '1032': 'GTX-A',
    '1093': '서해선',
    '1094': '신림선',
    '1081': '경강선',
  };

  /// 시간표 기준 배차간격 (초) 반환
  /// 시간대별: 러시아워(7~9,17~19), 평시(9~17,19~22), 심야(22~24,5~7)
  static int _getExpectedHeadwaySec(String subwayId, int hour) {
    final isRush = (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19);
    final isLate = hour >= 22 || (hour >= 5 && hour < 7);

    // 노선별 [러시아워, 평시, 심야/조조] 배차간격(초)
    const headways = {
      '1001': [180, 360, 540],   // 1호선: 3/6/9분
      '1002': [150, 270, 420],   // 2호선: 2.5/4.5/7분
      '1003': [180, 360, 480],   // 3호선: 3/6/8분
      '1004': [180, 330, 480],   // 4호선: 3/5.5/8분
      '1005': [180, 360, 540],   // 5호선: 3/6/9분
      '1006': [240, 420, 540],   // 6호선: 4/7/9분
      '1007': [180, 360, 540],   // 7호선: 3/6/9분
      '1008': [240, 420, 600],   // 8호선: 4/7/10분
      '1009': [180, 360, 480],   // 9호선: 3/6/8분
      '1063': [360, 600, 900],   // 경의중앙선: 6/10/15분
      '1065': [360, 540, 720],   // 공항철도: 6/9/12분
      '1067': [420, 720, 900],   // 경춘선: 7/12/15분
      '1075': [300, 480, 600],   // 수인분당선: 5/8/10분
      '1077': [300, 420, 540],   // 신분당선: 5/7/9분
      '1092': [360, 480, 600],   // 우이신설선: 6/8/10분
      '1032': [300, 480, 600],   // GTX-A: 5/8/10분
      '1093': [360, 600, 900],   // 서해선: 6/10/15분
      '1094': [240, 360, 480],   // 신림선: 4/6/8분
      '1081': [420, 720, 900],   // 경강선: 7/12/15분
    };

    final h = headways[subwayId] ?? [300, 480, 600]; // 기본 5/8/10분
    if (isRush) return h[0];
    if (isLate) return h[2];
    return h[1]; // 평시
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WKT (Well-Known Text) 파싱 유틸리티
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// WKT POINT 문자열에서 [lng, lat] 파싱
  /// 예: "POINT(126.9780 37.5665)" → [126.9780, 37.5665]
  List<double>? _parseWktPoint(String wkt) {
    final match = RegExp(r'POINT\s*\(\s*([\d.]+)\s+([\d.]+)\s*\)').firstMatch(wkt);
    if (match != null) {
      return [
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
      ];
    }
    return null;
  }

  /// WKT LINESTRING 문자열에서 좌표 목록 파싱
  /// 예: "LINESTRING(126.97 37.56, 126.98 37.57)" → [[126.97, 37.56], [126.98, 37.57]]
  List<List<double>> _parseWktLineString(String wkt) {
    final match = RegExp(r'LINESTRING\s*\((.+)\)').firstMatch(wkt);
    if (match == null) return [];

    return match.group(1)!.split(',').map((pair) {
      final coords = pair.trim().split(RegExp(r'\s+'));
      if (coords.length >= 2) {
        return [double.parse(coords[0]), double.parse(coords[1])];
      }
      return <double>[];
    }).where((c) => c.length == 2).toList();
  }
}

/// 배차간격 분석용 도착 항목
class _ArrivalEntry {
  final String trainNo;
  final int seconds;
  final String subwayId;
  const _ArrivalEntry({required this.trainNo, required this.seconds, required this.subwayId});
}

/// Seoul API 오류 클래스
class SeoulApiException implements Exception {
  final String message;
  final String code;

  SeoulApiException(this.message, {this.code = ''});

  @override
  String toString() => 'SeoulApiException[$code]: $message';
}