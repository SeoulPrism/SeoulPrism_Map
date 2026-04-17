import 'dart:math';
import 'package:flutter/foundation.dart';
import 'subway_geojson_loader.dart';
import 'seoul_subway_data.dart';

/// OSM 노선 경로 기반 위치 보간 엔진
///
/// 역 좌표 직선 보간 대신, 실제 선로 geometry 위를 따라 이동하도록
/// 각 역의 경로상 위치(누적 거리)를 프리컴퓨트하고,
/// 두 역 사이 보간 시 경로 polyline을 따라감
class RouteGeometry {
  // lineId → 경로 좌표 [[lat, lng], ...]
  final Map<String, List<List<double>>> _routes = {};
  // lineId → 각 좌표점의 누적 거리 (미터)
  final Map<String, List<double>> _cumDist = {};
  // lineId → stationName → 경로상 누적 거리
  final Map<String, Map<String, double>> _stationDist = {};
  // lineId → stationName → 경로에 스냅된 [lat, lng]
  final Map<String, Map<String, List<double>>> _stationSnapped = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// GeoJSON 로드 + 역 매핑 초기화
  Future<void> init() async {
    if (_initialized) return;

    final geojson = await SubwayGeoJsonLoader.load();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      final coords = geojson[lineId];
      if (coords == null || coords.length < 2) continue;

      _routes[lineId] = coords;

      // 누적 거리 계산
      final cumDist = <double>[0.0];
      for (int i = 1; i < coords.length; i++) {
        final d = _haversine(
          coords[i - 1][0], coords[i - 1][1],
          coords[i][0], coords[i][1],
        );
        cumDist.add(cumDist.last + d);
      }
      _cumDist[lineId] = cumDist;

      // 각 역을 경로에 스냅
      final stations = SeoulSubwayData.getLineStations(lineId);
      final stDist = <String, double>{};
      final stSnap = <String, List<double>>{};

      for (final station in stations) {
        final snap = _snapToRoute(coords, cumDist, station.lat, station.lng);
        // 스냅 거리가 500m 이상이면 경로 데이터 불일치 — 원래 좌표 유지
        final snapDistM = _haversine(station.lat, station.lng, snap.lat, snap.lng);
        if (snapDistM > 500) {
          debugPrint('[RouteGeometry] ⚠️ $lineId ${station.name}: 스냅 거리 ${snapDistM.round()}m → 원래 좌표 유지');
          stDist[station.name] = snap.dist;
          stSnap[station.name] = [station.lat, station.lng];
        } else {
          stDist[station.name] = snap.dist;
          stSnap[station.name] = [snap.lat, snap.lng];
        }
      }

      _stationDist[lineId] = stDist;
      _stationSnapped[lineId] = stSnap;
    }

    _initialized = true;
    debugPrint('[RouteGeometry] 초기화 완료: ${_routes.length}개 노선');
  }

  /// 두 역 사이 경로를 따라 보간된 위치 반환
  /// [t]: 0.0 = fromStation, 1.0 = toStation
  /// 반환: [lat, lng] 또는 null
  List<double>? interpolate(
    String lineId, String fromStation, String toStation, double t,
  ) {
    final cumDist = _cumDist[lineId];
    final stDist = _stationDist[lineId];
    if (cumDist == null || stDist == null) return null;

    final fromD = stDist[fromStation];
    final toD = stDist[toStation];
    if (fromD == null || toD == null) return null;

    final targetD = fromD + (toD - fromD) * t;
    return _positionAtDist(lineId, targetD);
  }

  /// 경로상 누적 거리로 좌표 반환
  List<double>? _positionAtDist(String lineId, double dist) {
    final coords = _routes[lineId];
    final cumDist = _cumDist[lineId];
    if (coords == null || cumDist == null) return null;

    // 범위 클램프
    if (dist <= 0) return [coords.first[0], coords.first[1]];
    if (dist >= cumDist.last) return [coords.last[0], coords.last[1]];

    // 이진 탐색으로 세그먼트 찾기
    int lo = 0, hi = cumDist.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (cumDist[mid] <= dist) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segLen = cumDist[hi] - cumDist[lo];
    if (segLen < 1e-10) return [coords[lo][0], coords[lo][1]];

    final frac = (dist - cumDist[lo]) / segLen;
    return [
      coords[lo][0] + (coords[hi][0] - coords[lo][0]) * frac,
      coords[lo][1] + (coords[hi][1] - coords[lo][1]) * frac,
    ];
  }

  /// 역의 스냅된 좌표 반환
  List<double>? getStationPosition(String lineId, String stationName) {
    return _stationSnapped[lineId]?[stationName];
  }

  /// 역의 경로상 누적 거리 반환
  double? getStationDistance(String lineId, String stationName) {
    return _stationDist[lineId]?[stationName];
  }

  /// 두 역 사이 베어링 (경로 접선 방향)
  double bearingAt(String lineId, String fromStation, String toStation, double t) {
    final cumDist = _cumDist[lineId];
    final stDist = _stationDist[lineId];
    final coords = _routes[lineId];
    if (cumDist == null || stDist == null || coords == null) return 0;

    final fromD = stDist[fromStation];
    final toD = stDist[toStation];
    if (fromD == null || toD == null) return 0;

    final targetD = fromD + (toD - fromD) * t;

    // 전후 좌표로 접선 방향 계산
    const delta = 10.0; // 미터
    final p1 = _positionAtDist(lineId, targetD - delta);
    final p2 = _positionAtDist(lineId, targetD + delta);
    if (p1 == null || p2 == null) return 0;

    return _bearing(p1[0], p1[1], p2[0], p2[1]);
  }

  /// 노선 경로가 있는지 확인
  bool hasRoute(String lineId) => _routes.containsKey(lineId);

  // ━━━━━━ 내부 유틸리티 ━━━━━━

  /// 좌표를 경로 polyline에 스냅 (최근접점 + 누적 거리)
  /// cos(lat) 보정을 적용하여 대각선 구간에서도 정확한 투영 수행
  _SnapResult _snapToRoute(
    List<List<double>> coords, List<double> cumDist, double lat, double lng,
  ) {
    double bestDist = double.infinity;
    double bestCumDist = 0;
    double bestLat = lat, bestLng = lng;

    // 경도 스케일 보정: 서울 위도(~37.5°)에서 경도 1°는 위도 1°의 ~79%
    final cosLat = cos(lat * pi / 180);
    final cosLat2 = cosLat * cosLat;

    for (int i = 0; i < coords.length - 1; i++) {
      final ax = coords[i][0], ay = coords[i][1];
      final bx = coords[i + 1][0], by = coords[i + 1][1];

      // 점 (lat, lng)에서 선분 (a, b)까지의 최근접점
      // 경도 차이에 cos(lat) 보정을 적용한 근사 직교 투영
      final dLat = bx - ax;
      final dLng = by - ay;
      final lenSq = dLat * dLat + dLng * dLng * cosLat2;
      double t = 0;
      if (lenSq > 1e-12) {
        t = ((lat - ax) * dLat + (lng - ay) * dLng * cosLat2) / lenSq;
        t = t.clamp(0.0, 1.0);
      }

      final projLat = ax + t * dLat;
      final projLng = ay + t * dLng;
      // 보정된 거리 계산
      final eLat = projLat - lat;
      final eLng = (projLng - lng) * cosLat;
      final d = eLat * eLat + eLng * eLng;

      if (d < bestDist) {
        bestDist = d;
        bestLat = projLat;
        bestLng = projLng;
        final segLen = cumDist[i + 1] - cumDist[i];
        bestCumDist = cumDist[i] + segLen * t;
      }
    }

    return _SnapResult(bestLat, bestLng, bestCumDist);
  }

  /// Haversine 거리 (미터)
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// 두 점 사이 베어링 (도)
  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * pi / 180;
    final y = sin(dLng) * cos(lat2 * pi / 180);
    final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}

class _SnapResult {
  final double lat, lng, dist;
  const _SnapResult(this.lat, this.lng, this.dist);
}
