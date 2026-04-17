import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../core/map_interface.dart';
import '../models/subway_models.dart';

class NaverMapEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const NaverMapEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<NaverMapEngine> createState() => _NaverMapEngineState();
}

class _NaverMapEngineState extends State<NaverMapEngine> implements IMapController {
  NaverMapController? _controller;

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    final cameraUpdate = NCameraUpdate.withParams(
      target: NLatLng(lat, lng),
      zoom: zoom,
      tilt: pitch,
      bearing: bearing,
    );
    cameraUpdate.setAnimation(animation: NCameraAnimation.fly, duration: const Duration(seconds: 1));
    _controller?.updateCamera(cameraUpdate);
  }

  @override
  void setPitch(double pitch) {
    _controller?.updateCamera(NCameraUpdate.withParams(tilt: pitch));
  }

  @override
  void setBearing(double bearing) => _controller?.updateCamera(NCameraUpdate.withParams(bearing: bearing));

  @override
  void setZoom(double zoom) => _controller?.updateCamera(NCameraUpdate.withParams(zoom: zoom));

  @override
  void setStyle(String styleUri) {
    // Naver Map 스타일 변경 (Basic, Satellite 등)
  }

  @override
  void toggleLayer(String layerId, bool visible) {
    // Naver Map 전용 레이어 (Traffic, Transit 등) 제어 가능
  }

  @override
  void setFilter(String layerId, dynamic filter) {}

  @override
  void setLightPreset(String preset) {}

  @override
  void setTerrain(bool enabled) {}

  @override
  Future<void> addMarker(String id, double lat, double lng, {String? title, String? iconPath}) async {
    final marker = NMarker(id: id, position: NLatLng(lat, lng));

    // 1. 마커를 지도에 먼저 추가합니다. (필수)
    _controller?.addOverlay(marker);

    // 2. title이 전달되었다면 InfoWindow를 생성하고 마커에 엽니다.
    if (title != null) {
      // InfoWindow도 고유의 ID가 필요하므로 마커 ID에 접미사를 붙여 사용합니다.
      final infoWindow = NInfoWindow.onMarker(id: '${id}_info', text: title);
      marker.openInfoWindow(infoWindow);
    }
  }

  @override
  void removeMarker(String id) {
    // Naver Map은 오버레이 타입과 ID로 삭제
  }

  @override
  void clearMarkers() {
    _controller?.clearOverlays();
  }

  // ── 지하철 시각화 메서드 (Naver Map 기본 구현) ──

  @override
  Future<void> addPolyline(String id, List<List<double>> coordinates, {
    Color color = Colors.blue, double width = 3.0, double opacity = 1.0,
  }) async {
    if (_controller == null || coordinates.length < 2) return;
    final coords = coordinates.map((c) => NLatLng(c[0], c[1])).toList();
    final polyline = NPolylineOverlay(
      id: id,
      coords: coords,
      color: color,
      width: width,
    );
    _controller?.addOverlay(polyline);
  }

  @override
  void removePolyline(String id) {}

  @override
  void clearPolylines() {
    _controller?.clearOverlays();
  }

  @override
  Future<void> addCircleMarker(String id, double lat, double lng, {
    Color color = Colors.red, double radius = 6.0,
    Color strokeColor = Colors.white, double strokeWidth = 2.0,
  }) async {
    if (_controller == null) return;
    final marker = NMarker(id: id, position: NLatLng(lat, lng));
    _controller?.addOverlay(marker);
  }

  @override
  void removeCircleMarker(String id) {}

  @override
  void clearCircleMarkers() {
    _controller?.clearOverlays();
  }

  @override
  Future<void> addStationMarker(String id, double lat, double lng, {
    String? name, Color color = Colors.white, double radius = 3.0,
  }) async {
    if (_controller == null) return;
    final marker = NMarker(id: id, position: NLatLng(lat, lng));
    _controller?.addOverlay(marker);
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(widget.initialCamera.lat, widget.initialCamera.lng),
          zoom: widget.initialCamera.zoom,
          tilt: widget.initialCamera.pitch,
          bearing: widget.initialCamera.bearing,
        ),
      ),
      onMapReady: (controller) {
        _controller = controller;
        widget.onMapCreated(this);
      },
    );
  }

  // ── 3D (Naver Maps에서는 미지원 — no-op) ──
  @override
  Future<void> init3DLayers() async {}
  @override
  void cleanup3DLayers() {}
  @override
  Future<void> updateTrainPositions3D(List<InterpolatedTrainPosition> trains) async {}
  @override
  Future<void> initRoutes3D(Map<String, List<List<double>>> routeCoordinates,
      Map<String, Color> lineColors, Map<String, List<bool>> segmentUnderground) async {}
  @override
  Future<void> updateStations3D(List<Map<String, dynamic>> stations) async {}
  @override
  void setUndergroundVisible(bool visible) {}
}
