import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../core/map_interface.dart';

class MapboxEngine extends StatefulWidget {
  final CameraInfo initialCamera;
  final Function(IMapController) onMapCreated;

  const MapboxEngine({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<MapboxEngine> createState() => _MapboxEngineState();
}

class _MapboxEngineState extends State<MapboxEngine> implements IMapController {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  // 관리 중인 소스/레이어 ID 추적
  final Set<String> _polylineIds = {};
  final Set<String> _circleMarkerIds = {};

  @override
  void moveTo(double lat, double lng, {double? zoom, double? pitch, double? bearing}) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  @override
  void setPitch(double pitch) => _mapboxMap?.setCamera(CameraOptions(pitch: pitch));

  @override
  void setBearing(double bearing) => _mapboxMap?.setCamera(CameraOptions(bearing: bearing));

  @override
  void setZoom(double zoom) => _mapboxMap?.setCamera(CameraOptions(zoom: zoom));

  @override
  void setStyle(String styleUri) => _mapboxMap?.loadStyleURI(styleUri);

  @override
  void toggleLayer(String layerId, bool visible) {
    _mapboxMap?.style.styleLayerExists(layerId).then((exists) {
      if (exists) {
        _mapboxMap?.style.setStyleLayerProperty(layerId, 'visibility', visible ? 'visible' : 'none');
      }
    });
  }

  @override
  void setFilter(String layerId, dynamic filter) {
    _mapboxMap?.style.setStyleLayerProperty(layerId, 'filter', filter);
  }

  @override
  void setLightPreset(String preset) {
    _mapboxMap?.style.setStyleLayerProperty("basemap", "light-preset", preset);
  }

  @override
  void setTerrain(bool enabled) {
    // v2.x 스타일 레이어 속성 제어
  }

  // ── 마커 (Annotation) ──

  @override
  Future<void> addMarker(String id, double lat, double lng, {String? title, String? iconPath}) async {
    if (_pointAnnotationManager == null) return;

    _pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      textField: title,
      textColor: Colors.white.toARGB32(),
      textSize: 12.0,
      textOffset: [0, 2.0],
      iconImage: 'marker-15',
    ));
  }

  @override
  void removeMarker(String id) {}

  @override
  void clearMarkers() {
    _pointAnnotationManager?.deleteAll();
  }

  // ── 폴리라인 (노선 경로) ──

  @override
  Future<void> addPolyline(String id, List<List<double>> coordinates, {
    Color color = Colors.blue,
    double width = 3.0,
    double opacity = 1.0,
  }) async {
    if (_polylineAnnotationManager == null) return;

    final points = coordinates.map((c) =>
      Point(coordinates: Position(c[1], c[0])) // [lat, lng] → Position(lng, lat)
    ).toList();

    if (points.length < 2) return;

    await _polylineAnnotationManager?.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: points.map((p) => p.coordinates).toList()),
        lineColor: color.toARGB32(),
        lineWidth: width,
        lineOpacity: opacity,
      ),
    );
    _polylineIds.add(id);
  }

  @override
  void removePolyline(String id) {
    _polylineIds.remove(id);
  }

  @override
  void clearPolylines() {
    _polylineAnnotationManager?.deleteAll();
    _polylineIds.clear();
  }

  // ── 원형 마커 (열차 위치) ──

  @override
  Future<void> addCircleMarker(String id, double lat, double lng, {
    Color color = Colors.red,
    double radius = 6.0,
    Color strokeColor = Colors.white,
    double strokeWidth = 2.0,
  }) async {
    if (_circleAnnotationManager == null) return;

    await _circleAnnotationManager?.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        circleColor: color.toARGB32(),
        circleRadius: radius,
        circleStrokeColor: strokeColor.toARGB32(),
        circleStrokeWidth: strokeWidth,
        circleSortKey: 10, // 노선 위에 렌더링
      ),
    );
    _circleMarkerIds.add(id);
  }

  @override
  void removeCircleMarker(String id) {
    _circleMarkerIds.remove(id);
  }

  @override
  void clearCircleMarkers() {
    _circleAnnotationManager?.deleteAll();
    _circleMarkerIds.clear();
  }

  // ── 역 마커 ──

  @override
  Future<void> addStationMarker(String id, double lat, double lng, {
    String? name,
    Color color = Colors.white,
    double radius = 3.0,
  }) async {
    if (_circleAnnotationManager == null) return;

    await _circleAnnotationManager?.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        circleColor: color.toARGB32(),
        circleRadius: radius,
        circleStrokeColor: Colors.black.toARGB32(),
        circleStrokeWidth: 1.0,
        circleSortKey: 5,
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
    });

    mapboxMap.annotations.createCircleAnnotationManager().then((manager) {
      _circleAnnotationManager = manager;
    });

    mapboxMap.annotations.createPolylineAnnotationManager().then((manager) {
      _polylineAnnotationManager = manager;
    });

    widget.onMapCreated(this);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      onMapCreated: _onMapCreated,
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(widget.initialCamera.lng, widget.initialCamera.lat)),
        zoom: widget.initialCamera.zoom,
        pitch: widget.initialCamera.pitch,
        bearing: widget.initialCamera.bearing,
      ),
      styleUri: MapboxStyles.STANDARD,
    );
  }
}
