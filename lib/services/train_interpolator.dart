import 'dart:math';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../data/route_geometry.dart';

/// MiniTokyo3D 스타일 열차 위치 보간 엔진
///
/// OSM 노선 경로(RouteGeometry)가 있으면 실제 선로를 따라 보간하고,
/// 없으면 역 좌표 직선 보간으로 폴백합니다.
class TrainInterpolator {
  RouteGeometry? _routeGeometry;

  /// 노선 ID → 역명 → 역 인덱스 캐시
  final Map<String, Map<String, int>> _stationIndexCache = {};
  /// 지선(branch) 키 → 역명 → 역 인덱스 캐시
  final Map<String, Map<String, int>> _branchIndexCache = {};

  TrainInterpolator() {
    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      final stations = SeoulSubwayData.getLineStations(lineId);
      final indexMap = <String, int>{};
      for (int i = 0; i < stations.length; i++) {
        indexMap[stations[i].name] = i;
      }
      _stationIndexCache[lineId] = indexMap;
    }
    // 지선 캐시 구축
    for (final branchKey in SeoulSubwayData.branchToLineId.keys) {
      final stations = SeoulSubwayData.getBranchStations(branchKey);
      final indexMap = <String, int>{};
      for (int i = 0; i < stations.length; i++) {
        indexMap[stations[i].name] = i;
      }
      _branchIndexCache[branchKey] = indexMap;
    }
  }

  /// RouteGeometry 설정 (초기화 후 호출)
  void setRouteGeometry(RouteGeometry rg) {
    _routeGeometry = rg;
  }

  /// 열차 위치 목록을 지도 좌표로 보간
  List<InterpolatedTrainPosition> interpolateAll(List<TrainPosition> trains) {
    final results = <InterpolatedTrainPosition>[];
    for (final train in trains) {
      final pos = interpolate(train);
      if (pos != null) results.add(pos);
    }
    return results;
  }

  /// 단일 열차의 보간된 지도 좌표 계산
  InterpolatedTrainPosition? interpolate(TrainPosition train) {
    final lineId = train.subwayId;

    // 지선 체크: 현재 역이 지선 소속인지 확인
    final branchKey = SeoulSubwayData.findBranchForStation(lineId, train.stationName);
    if (branchKey != null) {
      return _interpolateBranch(train, branchKey);
    }

    final stations = SeoulSubwayData.getLineStations(lineId);
    if (stations.isEmpty) return null;

    final stationIndex = _findStationIndex(lineId, train.stationName);
    if (stationIndex == null) return null;

    final isUpbound = train.direction == 0;

    // 역 기반 from/to/t 결정
    int fromIdx = stationIndex;
    int toIdx = stationIndex;
    double t = 0;

    switch (train.trainStatus) {
      case 1: // 도착: 현재 역 위치
        fromIdx = stationIndex;
        toIdx = stationIndex;
        t = 1.0;
        break;
      case 2: // 출발: 다음 역 방향으로 15%
        fromIdx = stationIndex;
        toIdx = isUpbound
            ? (stationIndex > 0 ? stationIndex - 1 : stationIndex)
            : (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex);
        t = 0.15;
        break;
      case 0: // 진입: 이전역에서 85% 진행
        toIdx = stationIndex;
        fromIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.85;
        break;
      case 3: // 전역출발: 이전역에서 30% 진행
        toIdx = stationIndex;
        fromIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.3;
        break;
      default:
        fromIdx = stationIndex;
        toIdx = stationIndex;
        t = 0.5;
    }

    double lat, lng, bearing;

    // OSM 경로가 있으면 경로를 따라 보간
    final rg = _routeGeometry;
    if (rg != null && rg.hasRoute(lineId) && fromIdx != toIdx) {
      final fromName = stations[fromIdx].name;
      final toName = stations[toIdx].name;
      final pos = rg.interpolate(lineId, fromName, toName, t);
      if (pos != null) {
        lat = pos[0];
        lng = pos[1];
        bearing = rg.bearingAt(lineId, fromName, toName, t);
      } else {
        // 폴백: 직선 보간
        lat = _lerp(stations[fromIdx].lat, stations[toIdx].lat, t);
        lng = _lerp(stations[fromIdx].lng, stations[toIdx].lng, t);
        bearing = _bearingBetween(
          stations[fromIdx].lat, stations[fromIdx].lng,
          stations[toIdx].lat, stations[toIdx].lng,
        );
      }
    } else if (fromIdx == toIdx) {
      // 역에 정차 중: 스냅된 역 좌표 사용
      final snapped = rg?.getStationPosition(lineId, stations[stationIndex].name);
      lat = snapped?[0] ?? stations[stationIndex].lat;
      lng = snapped?[1] ?? stations[stationIndex].lng;
      bearing = _calcBearing(stations, stationIndex, isUpbound);
    } else {
      // 폴백: 직선 보간
      lat = _lerp(stations[fromIdx].lat, stations[toIdx].lat, t);
      lng = _lerp(stations[fromIdx].lng, stations[toIdx].lng, t);
      bearing = _bearingBetween(
        stations[fromIdx].lat, stations[fromIdx].lng,
        stations[toIdx].lat, stations[toIdx].lng,
      );
    }

    final isUnderground = !SeoulSubwayData.isSurfaceStation(
      fromIdx == toIdx ? stations[fromIdx].id : stations[toIdx].id,
    );

    return InterpolatedTrainPosition(
      trainNo: train.trainNo,
      subwayId: train.subwayId,
      subwayName: train.subwayName,
      lat: lat,
      lng: lng,
      altitude: 0,
      isUnderground: isUnderground,
      direction: train.direction,
      terminalName: train.terminalName,
      stationName: train.stationName,
      trainStatus: train.trainStatus,
      expressType: train.expressType,
      isLastTrain: train.isLastTrain,
      bearing: bearing,
    );
  }

  /// 지선(branch) 열차 보간
  InterpolatedTrainPosition? _interpolateBranch(TrainPosition train, String branchKey) {
    final stations = SeoulSubwayData.getBranchStations(branchKey);
    if (stations.isEmpty) return null;

    final cache = _branchIndexCache[branchKey];
    int? stationIndex;
    if (cache != null) {
      stationIndex = cache[train.stationName];
    }
    if (stationIndex == null) return null;

    final isUpbound = train.direction == 0;
    int fromIdx = stationIndex;
    int toIdx = stationIndex;
    double t = 0;

    switch (train.trainStatus) {
      case 1:
        t = 1.0;
        break;
      case 2:
        fromIdx = stationIndex;
        toIdx = isUpbound
            ? (stationIndex > 0 ? stationIndex - 1 : stationIndex)
            : (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex);
        t = 0.15;
        break;
      case 0:
        toIdx = stationIndex;
        fromIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.85;
        break;
      case 3:
        toIdx = stationIndex;
        fromIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.3;
        break;
      default:
        t = 0.5;
    }

    double lat, lng, bearing;
    final rg = _routeGeometry;

    if (rg != null && rg.hasRoute(branchKey) && fromIdx != toIdx) {
      final fromName = stations[fromIdx].name;
      final toName = stations[toIdx].name;
      final pos = rg.interpolate(branchKey, fromName, toName, t);
      if (pos != null) {
        lat = pos[0];
        lng = pos[1];
        bearing = rg.bearingAt(branchKey, fromName, toName, t);
      } else {
        lat = _lerp(stations[fromIdx].lat, stations[toIdx].lat, t);
        lng = _lerp(stations[fromIdx].lng, stations[toIdx].lng, t);
        bearing = _bearingBetween(
          stations[fromIdx].lat, stations[fromIdx].lng,
          stations[toIdx].lat, stations[toIdx].lng,
        );
      }
    } else if (fromIdx == toIdx) {
      final snapped = rg?.getStationPosition(branchKey, stations[stationIndex].name);
      lat = snapped?[0] ?? stations[stationIndex].lat;
      lng = snapped?[1] ?? stations[stationIndex].lng;
      bearing = _calcBearing(stations, stationIndex, isUpbound);
    } else {
      lat = _lerp(stations[fromIdx].lat, stations[toIdx].lat, t);
      lng = _lerp(stations[fromIdx].lng, stations[toIdx].lng, t);
      bearing = _bearingBetween(
        stations[fromIdx].lat, stations[fromIdx].lng,
        stations[toIdx].lat, stations[toIdx].lng,
      );
    }

    final isUnderground = !SeoulSubwayData.isSurfaceStation(
      fromIdx == toIdx ? stations[fromIdx].id : stations[toIdx].id,
    );

    return InterpolatedTrainPosition(
      trainNo: train.trainNo,
      subwayId: train.subwayId,
      subwayName: train.subwayName,
      lat: lat,
      lng: lng,
      altitude: 0,
      isUnderground: isUnderground,
      direction: train.direction,
      terminalName: train.terminalName,
      stationName: train.stationName,
      trainStatus: train.trainStatus,
      expressType: train.expressType,
      isLastTrain: train.isLastTrain,
      bearing: bearing,
    );
  }

  int? _findStationIndex(String lineId, String stationName) {
    final cache = _stationIndexCache[lineId];
    if (cache != null && cache.containsKey(stationName)) {
      return cache[stationName];
    }
    final stations = SeoulSubwayData.getLineStations(lineId);
    for (int i = 0; i < stations.length; i++) {
      if (stations[i].name.contains(stationName) ||
          stationName.contains(stations[i].name)) {
        return i;
      }
    }
    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      if (entry.key == lineId) continue;
      final otherStations = SeoulSubwayData.getLineStations(entry.key);
      for (int i = 0; i < otherStations.length; i++) {
        if (otherStations[i].name == stationName) {
          final targetStation = otherStations[i];
          return _findNearestStationIndex(
              stations, targetStation.lat, targetStation.lng);
        }
      }
    }
    return null;
  }

  int? _findNearestStationIndex(
      List<StationInfo> stations, double lat, double lng) {
    if (stations.isEmpty) return null;
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < stations.length; i++) {
      final d = _distance(lat, lng, stations[i].lat, stations[i].lng);
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    return nearest;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return sqrt(dlat * dlat + dlng * dlng);
  }

  double _calcBearing(List<StationInfo> stations, int idx, bool isUpbound) {
    if (isUpbound && idx > 0) {
      return _bearingBetween(
        stations[idx].lat, stations[idx].lng,
        stations[idx - 1].lat, stations[idx - 1].lng,
      );
    } else if (!isUpbound && idx < stations.length - 1) {
      return _bearingBetween(
        stations[idx].lat, stations[idx].lng,
        stations[idx + 1].lat, stations[idx + 1].lng,
      );
    }
    return 0;
  }

  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLng);
    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  double _toRadians(double deg) => deg * pi / 180;
  double _toDegrees(double rad) => rad * 180 / pi;
}
