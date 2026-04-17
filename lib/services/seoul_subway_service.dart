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
    '경의중앙선', '공항철도', '경춘선', '수인분당선', '신분당선', '우이신설선',
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

    final url = '$_baseUrl/$_apiKey/json/realtimePosition/0/100/$lineName';
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
    final url = '$_baseUrl/$_apiKey/json/realtimeStationArrival/0/20/$stationName';
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
      throw SeoulApiException('도착정보 조회 실패: $e', code: 'ARRIVAL');
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

/// Seoul API 오류 클래스
class SeoulApiException implements Exception {
  final String message;
  final String code;

  SeoulApiException(this.message, {this.code = ''});

  @override
  String toString() => 'SeoulApiException[$code]: $message';
}