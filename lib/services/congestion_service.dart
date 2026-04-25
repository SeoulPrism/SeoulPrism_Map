import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_keys.dart';

/// 역별 승하차 혼잡도 데이터
class StationCongestion {
  final String lineName;
  final String stationName;
  final int boarding;   // 승차 인원
  final int alighting;  // 하차 인원

  const StationCongestion({
    required this.lineName,
    required this.stationName,
    required this.boarding,
    required this.alighting,
  });

  int get total => boarding + alighting;
}

/// 서울 열린데이터 역별 승하차 인원 서비스
class CongestionService {
  static final CongestionService instance = CongestionService._();
  CongestionService._();

  // 역명 → 혼잡도 데이터 (동일 역명 여러 노선이면 합산)
  final Map<String, StationCongestion> _data = {};
  Map<String, StationCongestion> get data => _data;

  int _maxTotal = 1; // 정규화용 최대값
  bool _loaded = false;
  bool get isLoaded => _loaded;
  String _dateStr = '';
  String get dateStr => _dateStr;

  /// 혼잡도 0.0~1.0 (log scale로 시각적 분포 개선)
  double getCrowding(String stationName) {
    final c = _data[stationName];
    if (c == null || _maxTotal <= 0) return 0.0;
    // log scale: 작은 역도 보이도록
    final ratio = c.total / _maxTotal;
    return (ratio * 2.0).clamp(0.0, 1.0); // 상위 50%부터 최대
  }

  /// API 호출 — 최근 데이터 자동 탐색 (3일 전부터)
  Future<bool> fetch() async {
    if (_loaded) return true;

    final now = DateTime.now();
    // 최근 데이터 탐색 (보통 3~5일 지연)
    for (int daysBack = 2; daysBack <= 10; daysBack++) {
      final date = now.subtract(Duration(days: daysBack));
      final dateStr = '${date.year}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';

      final success = await _fetchDate(dateStr);
      if (success) {
        _dateStr = dateStr;
        _loaded = true;
        debugPrint('[Congestion] ✅ $dateStr 데이터 로드: ${_data.length}개 역, 최대 $_maxTotal명');
        return true;
      }
    }

    debugPrint('[Congestion] ❌ 최근 7일 데이터 없음');
    return false;
  }

  Future<bool> _fetchDate(String dateStr) async {
    try {
      final key = ApiKeys.seoulApiKey;
      final url = 'http://openapi.seoul.go.kr:8088/$key/json/CardSubwayStatsNew/1/700/$dateStr';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body);
      final root = json['CardSubwayStatsNew'];
      if (root == null) return false;

      final result = root['RESULT'];
      if (result != null && result['CODE'] != 'INFO-000') return false;

      final rows = root['row'] as List?;
      if (rows == null || rows.isEmpty) return false;

      _data.clear();
      _maxTotal = 1;

      for (final row in rows) {
        final lineName = row['SBWY_ROUT_LN_NM']?.toString() ?? '';
        final stationName = _cleanName(row['SBWY_STNS_NM']?.toString() ?? '');
        final boarding = int.tryParse(row['GTON_TNOPE']?.toString() ?? '0') ?? 0;
        final alighting = int.tryParse(row['GTOFF_TNOPE']?.toString() ?? '0') ?? 0;

        if (stationName.isEmpty) continue;

        // 동일 역명 합산 (환승역)
        final existing = _data[stationName];
        if (existing != null) {
          _data[stationName] = StationCongestion(
            lineName: existing.lineName,
            stationName: stationName,
            boarding: existing.boarding + boarding,
            alighting: existing.alighting + alighting,
          );
        } else {
          _data[stationName] = StationCongestion(
            lineName: lineName,
            stationName: stationName,
            boarding: boarding,
            alighting: alighting,
          );
        }
      }

      // 최대값 계산
      for (final c in _data.values) {
        if (c.total > _maxTotal) _maxTotal = c.total;
      }

      return _data.isNotEmpty;
    } catch (e) {
      debugPrint('[Congestion] 에러($dateStr): $e');
      return false;
    }
  }

  /// 역명 정리 (괄호 내용 유지, 앞뒤 공백 제거)
  String _cleanName(String name) {
    return name.trim();
  }
}
