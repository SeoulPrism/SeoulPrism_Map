import 'package:flutter/material.dart';
import '../models/subway_models.dart';

enum MapType { mapbox, google, naver }

abstract class IMapController {
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing});
  void toggleLayer(String layerId, bool visible);
  void setPitch(double pitch);
  void setBearing(double bearing);
  void setZoom(double zoom);

  // 가시성 및 스타일 제어
  void setStyle(String styleUri);
  void setFilter(String layerId, dynamic filter);

  // 마커 및 어노테이션
  Future<void> addMarker(String id, double lat, double lng, {String? title, String? iconPath});
  void removeMarker(String id);
  void clearMarkers();

  // 3D 및 라이트 설정 (Mapbox 특화)
  void setLightPreset(String preset); // day, night, dusk, dawn
  void setTerrain(bool enabled);

  // ── 지하철 시각화용 확장 메서드 ──

  /// 폴리라인 추가 (노선 경로 표시)
  Future<void> addPolyline(String id, List<List<double>> coordinates, {
    Color color = Colors.blue,
    double width = 3.0,
    double opacity = 1.0,
  }) async {}

  /// 폴리라인 제거
  void removePolyline(String id) {}

  /// 모든 폴리라인 제거
  void clearPolylines() {}

  /// 원형 마커 추가 (열차 위치 표시)
  Future<void> addCircleMarker(String id, double lat, double lng, {
    Color color = Colors.red,
    double radius = 6.0,
    Color strokeColor = Colors.white,
    double strokeWidth = 2.0,
  }) async {}

  /// 원형 마커 제거
  void removeCircleMarker(String id) {}

  /// 모든 원형 마커 제거
  void clearCircleMarkers() {}

  /// 역 마커 추가 (작은 점 + 이름)
  Future<void> addStationMarker(String id, double lat, double lng, {
    String? name,
    Color color = Colors.white,
    double radius = 3.0,
  }) async {}

  // ── 3D 지하철 시각화 (Style Layer 기반) ──

  /// 3D 열차 위치 일괄 업데이트 (GeoJSON Source)
  Future<void> updateTrainPositions3D(List<InterpolatedTrainPosition> trains) async {}

  /// 3D 노선 경로 초기화 (지상/지하 구분)
  Future<void> initRoutes3D(Map<String, List<List<double>>> routeCoordinates,
      Map<String, Color> lineColors, Map<String, List<bool>> segmentUnderground) async {}

  /// 3D 역 마커 업데이트 (줌 반응형 MiniTokyo3D 스타일)
  Future<void> updateStations3D(List<Map<String, dynamic>> stations) async {}

  /// 지하 구간 표시 토글
  void setUndergroundVisible(bool visible) {}

  /// 3D Style Layer 초기화 (맵 엔진 준비 완료 후 호출)
  Future<void> init3DLayers() async {}

  /// 3D Style Layer 정리
  void cleanup3DLayers() {}
}

class CameraInfo {
  final double lat;
  final double lng;
  final double zoom;
  final double pitch;
  final double bearing;

  CameraInfo({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.pitch,
    required this.bearing,
  });
}
