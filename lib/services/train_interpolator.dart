import 'dart:math';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';

/// MiniTokyo3D 스타일 열차 위치 보간 엔진
///
/// API에서 받은 열차의 현재 역 + 상태(진입/도착/출발/전역출발) 정보를 기반으로
/// 노선의 역 좌표 경로 위에서 실제 지도 좌표를 보간합니다.
class TrainInterpolator {
  // 3D 고도 설정 (미터)
  static const double surfaceAltitude = 30.0; // 지상 열차 고도
  static const double undergroundAltitude = 0.0; // 지하 열차 고도
  /// 노선 ID → 역명 → 역 인덱스 캐시
  final Map<String, Map<String, int>> _stationIndexCache = {};

  /// 초기화: 역 인덱스 캐시 구축
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
    final stations = SeoulSubwayData.getLineStations(lineId);
    if (stations.isEmpty) return null;

    final stationIndex = _findStationIndex(lineId, train.stationName);
    if (stationIndex == null) return null;

    // 열차 진행 방향에 따라 이전역/현재역 결정
    // direction: 0=상행(인덱스 감소 방향), 1=하행(인덱스 증가 방향)
    final isUpbound = train.direction == 0;

    double lat, lng, bearing;
    int fromIdx = stationIndex;
    int toIdx = stationIndex;
    double t = 0;

    switch (train.trainStatus) {
      case 1: // 도착: 현재 역 위치
        lat = stations[stationIndex].lat;
        lng = stations[stationIndex].lng;
        bearing = _calcBearing(stations, stationIndex, isUpbound);
        fromIdx = stationIndex;
        toIdx = stationIndex;
        t = 1.0;
        break;

      case 2: // 출발: 현재역을 막 떠남 → 다음 역 방향으로 약간 이동
        final nextIdx = isUpbound
            ? (stationIndex > 0 ? stationIndex - 1 : stationIndex)
            : (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex);
        t = 0.15;
        fromIdx = stationIndex;
        toIdx = nextIdx;
        lat = _lerp(stations[stationIndex].lat, stations[nextIdx].lat, t);
        lng = _lerp(stations[stationIndex].lng, stations[nextIdx].lng, t);
        bearing = _bearingBetween(
          stations[stationIndex].lat, stations[stationIndex].lng,
          stations[nextIdx].lat, stations[nextIdx].lng,
        );
        break;

      case 0: // 진입: 현재역에 거의 도착 → 이전역에서 85% 진행
        final prevIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.85;
        fromIdx = prevIdx;
        toIdx = stationIndex;
        lat = _lerp(stations[prevIdx].lat, stations[stationIndex].lat, t);
        lng = _lerp(stations[prevIdx].lng, stations[stationIndex].lng, t);
        bearing = _bearingBetween(
          stations[prevIdx].lat, stations[prevIdx].lng,
          stations[stationIndex].lat, stations[stationIndex].lng,
        );
        break;

      case 3: // 전역출발: 이전역을 떠남 → 현재역까지 30% 진행
        final prevIdx = isUpbound
            ? (stationIndex < stations.length - 1 ? stationIndex + 1 : stationIndex)
            : (stationIndex > 0 ? stationIndex - 1 : stationIndex);
        t = 0.3;
        fromIdx = prevIdx;
        toIdx = stationIndex;
        lat = _lerp(stations[prevIdx].lat, stations[stationIndex].lat, t);
        lng = _lerp(stations[prevIdx].lng, stations[stationIndex].lng, t);
        bearing = _bearingBetween(
          stations[prevIdx].lat, stations[prevIdx].lng,
          stations[stationIndex].lat, stations[stationIndex].lng,
        );
        break;

      default:
        lat = stations[stationIndex].lat;
        lng = stations[stationIndex].lng;
        bearing = 0;
    }

    // 3D 고도 계산: 지상/지하 구간 보간
    final fromSurface = SeoulSubwayData.isSurfaceStation(stations[fromIdx].id);
    final toSurface = SeoulSubwayData.isSurfaceStation(stations[toIdx].id);
    final fromAlt = fromSurface ? surfaceAltitude : undergroundAltitude;
    final toAlt = toSurface ? surfaceAltitude : undergroundAltitude;
    final altitude = _lerp(fromAlt, toAlt, t);
    final isUnderground = altitude < surfaceAltitude * 0.5;

    return InterpolatedTrainPosition(
      trainNo: train.trainNo,
      subwayId: train.subwayId,
      subwayName: train.subwayName,
      lat: lat,
      lng: lng,
      altitude: altitude,
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

  /// 역명으로 역 인덱스 검색
  int? _findStationIndex(String lineId, String stationName) {
    // 직접 매칭
    final cache = _stationIndexCache[lineId];
    if (cache != null && cache.containsKey(stationName)) {
      return cache[stationName];
    }

    // 부분 매칭 (API 역명과 데이터 역명이 다를 수 있음)
    final stations = SeoulSubwayData.getLineStations(lineId);
    for (int i = 0; i < stations.length; i++) {
      if (stations[i].name.contains(stationName) ||
          stationName.contains(stations[i].name)) {
        return i;
      }
    }

    // 전체 노선에서 검색 (환승역 등)
    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      if (entry.key == lineId) continue;
      final otherStations = SeoulSubwayData.getLineStations(entry.key);
      for (int i = 0; i < otherStations.length; i++) {
        if (otherStations[i].name == stationName) {
          // 해당 역의 좌표를 현재 노선에서 가장 가까운 역으로 매핑
          final targetStation = otherStations[i];
          return _findNearestStationIndex(stations, targetStation.lat, targetStation.lng);
        }
      }
    }

    return null;
  }

  /// 가장 가까운 역의 인덱스 검색
  int? _findNearestStationIndex(List<StationInfo> stations, double lat, double lng) {
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

  /// 선형 보간
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// 두 지점 사이의 거리 (간단한 유클리드)
  double _distance(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return sqrt(dlat * dlat + dlng * dlng);
  }

  /// 역 리스트에서 현재 인덱스 기준 진행 방향 베어링 계산
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

  /// 두 좌표 간 베어링(방위각) 계산 (도 단위)
  double _bearingBetween(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  double _toRadians(double deg) => deg * pi / 180;
  double _toDegrees(double rad) => rad * 180 / pi;
}
