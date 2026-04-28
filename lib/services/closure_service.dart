import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_keys.dart';
import '../data/seoul_subway_data.dart';

/// 지하철 시설 임시폐쇄 정보
class StationClosure {
  final String line;          // 호선 (e.g. "7호선")
  final String stationName;   // 역명 (괄호 제거, e.g. "이수")
  final String rawStationName; // 원본 역명 (e.g. "이수(7)")
  final String closurePlace;  // 폐쇄장소 (e.g. "2번 출입구")
  final String startDate;     // 시작일 (YYYY-MM-DD)
  final String endDate;       // 종료일 (YYYY-MM-DD)
  final String reason;        // 폐쇄사유
  final String altRoute;      // 대체경로

  const StationClosure({
    required this.line,
    required this.stationName,
    required this.rawStationName,
    required this.closurePlace,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.altRoute,
  });

  /// 출입구 폐쇄인지 (화장실/에스컬레이터 등과 구분)
  bool get isEntranceClosure => closurePlace.contains('출입구');
}

/// 서울 열린데이터 지하철 출입구 임시폐쇄 공사현황 서비스
/// API: TbSubwayLineDetail (OA-22122)
class ClosureService {
  static final ClosureService instance = ClosureService._();
  ClosureService._();

  final List<StationClosure> _closures = [];
  final Map<String, List<StationClosure>> _byStation = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;
  List<StationClosure> get all => _closures;

  /// 역명으로 해당 역의 폐쇄 정보 조회
  List<StationClosure> getClosures(String stationName) {
    return _byStation[stationName] ?? [];
  }

  /// 폐쇄 정보가 있는 역 목록
  Set<String> get affectedStations => _byStation.keys.toSet();

  /// API 호출 (앱 시작 시 1회)
  Future<bool> fetch() async {
    if (_loaded) return true;

    try {
      final key = ApiKeys.seoulApiKey;
      final url = 'http://openapi.seoul.go.kr:8088/$key/json/TbSubwayLineDetail/1/200/';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body);
      final root = json['TbSubwayLineDetail'];
      if (root == null) return false;

      final result = root['RESULT'];
      if (result != null && result['CODE'] != 'INFO-000') return false;

      final rows = root['row'] as List?;
      if (rows == null || rows.isEmpty) return false;

      final now = DateTime.now();
      _closures.clear();
      _byStation.clear();

      for (final row in rows) {
        final rawName = row['SBWY_STNS_NM']?.toString() ?? '';
        final cleanName = _cleanStationName(rawName);
        if (cleanName.isEmpty) continue;

        final startStr = (row['BGNG_YMD']?.toString() ?? '').substring(0, 10);
        final endStr = (row['END_YMD']?.toString() ?? '').substring(0, 10);

        // 종료일이 오늘 이전이면 스킵 (만료된 폐쇄)
        try {
          final endDate = DateTime.parse(endStr);
          if (endDate.isBefore(now)) continue;
        } catch (_) {}

        final closure = StationClosure(
          line: row['LINE']?.toString() ?? '',
          stationName: cleanName,
          rawStationName: rawName,
          closurePlace: row['CLSG_PLC']?.toString() ?? '',
          startDate: startStr,
          endDate: endStr,
          reason: row['CLSG_RSN']?.toString() ?? '',
          altRoute: row['RPLC_PATH']?.toString() ?? '',
        );

        _closures.add(closure);
        // 앱 역명으로 매핑 (API "이수" → 앱 "총신대입구" 등)
        final resolvedName = _resolveStationName(cleanName);
        _byStation.putIfAbsent(resolvedName, () => []).add(closure);
      }

      _loaded = true;
      debugPrint('[Closure] ${_closures.length}건 로드 (${_byStation.length}개 역)');
      return true;
    } catch (e) {
      debugPrint('[Closure] fetch 실패: $e');
      return false;
    }
  }

  /// 역명 정리: "이수(7)" → "이수", "사당(2)" → "사당"
  String _cleanStationName(String name) {
    return name.replaceAll(RegExp(r'\([^)]*\)$'), '').trim();
  }

  /// API 역명 → 앱 역명 매핑
  /// "이수" → "총신대입구(이수)" 등 자동 해소
  String _resolveStationName(String apiName) {
    // findStation이 정확/괄호제거/별칭/부분 매칭 전부 처리
    final found = SeoulSubwayData.findStation(apiName);
    if (found != null) return found.name;

    // 특수문자 차이 보정 (4·19민주묘지 ↔ 4.19민주묘지)
    final normalized = apiName.replaceAll('·', '.').replaceAll('ㆍ', '.');
    if (normalized != apiName) {
      final normMatch = SeoulSubwayData.findStation(normalized);
      if (normMatch != null) return normMatch.name;
    }

    return apiName;
  }
}
