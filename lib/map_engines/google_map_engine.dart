import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/map_interface.dart';
import '../models/subway_models.dart';

class GoogleMapEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const GoogleMapEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<GoogleMapEngine> createState() => _GoogleMapEngineState();
}

class _GoogleMapEngineState extends State<GoogleMapEngine> implements IMapController {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  
  // 현재 카메라 상태를 추적 (Google Maps는 개별 속성 변경이 까다롭기 때문)
  double _currentZoom = 12.0;
  double _currentTilt = 0.0;
  double _currentBearing = 0.0;
  LatLng _currentCenter = const LatLng(37.5665, 126.9780);

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialCamera.zoom;
    _currentTilt = widget.initialCamera.pitch;
    _currentBearing = widget.initialCamera.bearing;
    _currentCenter = LatLng(widget.initialCamera.lat, widget.initialCamera.lng);
  }

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    _currentCenter = LatLng(lat, lng);
    if (zoom != null) _currentZoom = zoom;
    if (pitch != null) _currentTilt = pitch;
    if (bearing != null) _currentBearing = bearing;

    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentCenter,
          zoom: _currentZoom,
          tilt: _currentTilt,
          bearing: _currentBearing,
        ),
      ),
    );
  }

  @override
  void setPitch(double pitch) {
    _currentTilt = pitch;
    _updateCamera();
  }

  @override
  void setBearing(double bearing) {
    _currentBearing = bearing;
    _updateCamera();
  }

  @override
  void setZoom(double zoom) {
    _currentZoom = zoom;
    _updateCamera();
  }

  void _updateCamera() {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentCenter,
          zoom: _currentZoom,
          tilt: _currentTilt,
          bearing: _currentBearing,
        ),
      ),
    );
  }

  @override
  void setStyle(String styleUri) {}

  @override
  void toggleLayer(String layerId, bool visible) {}

  @override
  void setFilter(String layerId, dynamic filter) {}

  @override
  void setLightPreset(String preset) {}

  @override
  void setTerrain(bool enabled) {}

  @override
  Future<void> addMarker(String id, double lat, double lng, {String? title, String? iconPath}) async {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: title),
      ));
    });
  }

  @override
  void removeMarker(String id) {
    setState(() => _markers.removeWhere((m) => m.markerId.value == id));
  }

  @override
  void clearMarkers() => setState(() => _markers.clear());

  // ── 지하철 시각화 메서드 (Google Maps 기본 구현) ──

  @override
  Future<void> addPolyline(String id, List<List<double>> coordinates, {
    Color color = Colors.blue, double width = 3.0, double opacity = 1.0,
  }) async {
    // Google Maps Polyline은 별도 Set<Polyline>로 관리 가능
    // 현재는 stub 구현
  }

  @override
  void removePolyline(String id) {}

  @override
  void clearPolylines() {}

  @override
  Future<void> addCircleMarker(String id, double lat, double lng, {
    Color color = Colors.red, double radius = 6.0,
    Color strokeColor = Colors.white, double strokeWidth = 2.0,
  }) async {}

  @override
  void removeCircleMarker(String id) {}

  @override
  void clearCircleMarkers() {}

  @override
  Future<void> addStationMarker(String id, double lat, double lng, {
    String? name, Color color = Colors.white, double radius = 3.0,
  }) async {}

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentCenter,
        zoom: _currentZoom,
        tilt: _currentTilt,
        bearing: _currentBearing,
      ),
      markers: _markers,
      onMapCreated: (controller) {
        _controller = controller;
        widget.onMapCreated(this);
      },
      onCameraMove: (position) {
        _currentCenter = position.target;
        _currentZoom = position.zoom;
        _currentTilt = position.tilt;
        _currentBearing = position.bearing;
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
    );
  }

  // ── 3D (Google Maps에서는 미지원 — no-op) ──
  @override
  Future<void> init3DLayers() async {}
  @override
  void cleanup3DLayers() {}

  @override
  void setOnTrainTapped(void Function(String trainNo)? callback) {}
  @override
  void setOnStationTapped(void Function(String stationName)? callback) {}
  @override
  void followTrain(double lat, double lng, double bearing) {}
  @override
  void setOnMapTappedEmpty(VoidCallback? callback) {}
  @override
  void setSelectedTrain(String? trainNo) {}
  @override
  void setSelectedStation(String? stationName) {}
  @override
  void applyWeatherEffect({required String lightPreset, double fogOpacity = 0.0, double atmosphereRange = 1.0, double rainIntensity = 0.0, double snowIntensity = 0.0}) {}
  @override
  Future<void> updateTrainPositions3D(List<InterpolatedTrainPosition> trains, {Map<String, int> trainDelays = const {}}) async {}
  @override
  Future<void> initRoutes3D(Map<String, List<List<double>>> routeCoordinates,
      Map<String, Color> lineColors, Map<String, List<bool>> segmentUnderground) async {}
  @override
  Future<void> updateStations3D(List<Map<String, dynamic>> stations) async {}
  @override
  void setUndergroundVisible(bool visible) {}
  @override
  Future<void> updateDelayShield3D(Map<String, int> delayInfo) async {}
}
