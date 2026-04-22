import 'package:flutter/material.dart';
import '../models/subway_models.dart';

enum MapType { mapbox }

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
  /// [trainDelays] 열차별 지연 시간 (trainNo → 분), 없으면 빈 맵
  Future<void> updateTrainPositions3D(List<InterpolatedTrainPosition> trains, {Map<String, int> trainDelays = const {}}) async {}

  /// 3D 노선 경로 초기화 (지상/지하 구분)
  Future<void> initRoutes3D(Map<String, List<List<double>>> routeCoordinates,
      Map<String, Color> lineColors, Map<String, List<bool>> segmentUnderground) async {}

  /// 3D 역 마커 업데이트 (MiniTokyo3D 스타일 필/캡슐 마커)
  /// [pills] 역별 캡슐 배경 (LineString), [dots] 노선별 컬러 도트 (Point)
  Future<void> updateStations3D(List<Map<String, dynamic>> pills, List<Map<String, dynamic>> dots) async {}

  /// 지하 구간 표시 토글
  void setUndergroundVisible(bool visible) {}

  /// 3D Style Layer 초기화 (맵 엔진 준비 완료 후 호출)
  Future<void> init3DLayers() async {}

  /// 3D Style Layer 정리
  void cleanup3DLayers() {}

  /// 열차 탭 콜백 설정 (Mapbox only)
  void setOnTrainTapped(void Function(String trainNo)? callback) {}

  /// 역 탭 콜백 설정 (Mapbox only)
  void setOnStationTapped(void Function(String stationName)? callback) {}

  /// 선택된 열차 따라가기 — 카메라 이동 (Mapbox only)
  void followTrain(double lat, double lng, double bearing) {}

  /// 열차 선택 해제 시 호출 — 맵 빈 곳 탭 (Mapbox only)
  void setOnMapTappedEmpty(VoidCallback? callback) {}

  /// 선택된 열차 번호 설정 (하이라이트 표시용)
  void setSelectedTrain(String? trainNo) {}

  /// 선택된 역 이름 설정 (하이라이트 표시용)
  void setSelectedStation(String? stationName) {}

  /// 날씨 시각 효과 적용 (안개, 비, 눈 등)
  void applyWeatherEffect({
    required String lightPreset,
    double fogOpacity = 0.0,
    double atmosphereRange = 1.0,
    double rainIntensity = 0.0,
    double snowIntensity = 0.0,
  }) {}

  /// 지연/장애 노선에 방어막(쉴드) 효과 표시 (MiniTokyo3D 스타일)
  /// [delayInfo] 지연 노선 ID → 지연 분 수 (e.g., {'1002': 5, '1004': 12})
  Future<void> updateDelayShield3D(Map<String, int> delayInfo) async {}
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
