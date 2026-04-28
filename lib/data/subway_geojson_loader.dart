import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// OSM 기반 지하철 노선 GeoJSON 로더
/// 직선 보간 대신 실제 선로 곡선 geometry 사용
class SubwayGeoJsonLoader {
  static Map<String, List<List<double>>>? _cache;

  /// 노선별 좌표 로드 (lineId → [[lat, lng], ...])
  /// initRoutes3D에 바로 전달 가능한 형식
  static Future<Map<String, List<List<double>>>> load() async {
    if (_cache != null) return _cache!;

    final jsonStr =
        await rootBundle.loadString('assets/geojson/seoul_subway.geojson');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final features = data['features'] as List;

    final result = <String, List<List<double>>>{};

    for (final feat in features) {
      final props = feat['properties'] as Map<String, dynamic>;
      final lineId = props['lineId'] as String;
      final branch = props['branch'] as String? ?? 'main';
      final coords = (feat['geometry']['coordinates'] as List)
          .map<List<double>>((c) => [(c as List)[1] as double, c[0] as double]) // [lng,lat] → [lat,lng]
          .toList();

      if (branch == 'main') {
        // 메인 경로: 기존 데이터 교체
        result[lineId] = coords;
      } else {
        // 지선: 메인에 이어붙이기 (별도 키로 저장)
        final branchKey = '${lineId}_$branch';
        result[branchKey] = coords;
      }
    }

    _cache = result;
    return result;
  }
}
