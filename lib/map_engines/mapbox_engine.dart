import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../core/map_interface.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';

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

  // ── 3D Style Layer 관련 ──
  static const _trainSourceId = 'subway-trains-source';
  static const _trainLayerId = 'subway-trains-layer';
  static const _selectedTrainSourceId = 'subway-selected-train-source';
  static const _selectedTrainLayerId = 'subway-selected-train-layer';
  static const _selectedStationSourceId = 'subway-selected-station-source';
  static const _selectedStationLayerId = 'subway-selected-station-layer';
  static const _routeSurfaceSourceId = 'subway-routes-surface-source';
  static const _routeSurfaceLayerId = 'subway-routes-surface-layer';
  static const _routeUndergroundSourceId = 'subway-routes-underground-source';
  static const _routeUndergroundLayerId = 'subway-routes-underground-layer';
  static const _stationSourceId = 'subway-stations-source';
  static const _stationDotLayerId = 'subway-stations-dot-layer';
  static const _stationLabelLayerId = 'subway-stations-label-layer';
  static const _stationOutlineLayerId = 'subway-stations-outline-layer';
  // 열차별 지연 표시 레이어
  static const _delaySourceId = 'subway-delay-source';
  static const _delayGlowLayerId = 'subway-delay-glow-layer';
  static const _delayLabelLayerId = 'subway-delay-label-layer';
  bool _layersInitialized3D = false;
  // ignore: unused_field
  bool _undergroundVisible = true;

  // 열차 탭 / 맵 빈 곳 탭 콜백
  void Function(String trainNo)? _onTrainTapped;
  void Function(String stationName)? _onStationTapped;
  VoidCallback? _onMapTappedEmpty;
  bool _isFollowing = false;
  String? _selectedTrainNo;
  String? _selectedStationName;

  // 서울 위도에서의 미터→도 변환 계수
  static const double _mPerDegLat = 111320.0;
  static const double _mPerDegLng = 88000.0; // ~111320 * cos(37.5°)

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
    try {
      _mapboxMap?.style.setStyleImportConfigProperty("basemap", "lightPreset", preset);
    } catch (e) {
      debugPrint('[MapboxEngine] lightPreset 설정 실패: $e');
    }
  }

  @override
  void applyWeatherEffect({
    required String lightPreset,
    double fogOpacity = 0.0,
    double atmosphereRange = 1.0,
    double rainIntensity = 0.0,
    double snowIntensity = 0.0,
  }) {
    if (_mapboxMap == null) return;

    // 1) 라이트 프리셋 적용
    setLightPreset(lightPreset);

    // 2) Fog (안개/시정 효과) — Standard style atmosphere config
    if (fogOpacity > 0) {
      try {
        // Standard style의 fog 설정 — config property 사용
        _mapboxMap!.style.setStyleImportConfigProperty(
          "basemap", "fog", fogOpacity > 0.3 ? "high" : "low",
        );
      } catch (e) {
        debugPrint('[MapboxEngine] fog 설정 실패 (무시): $e');
      }
    }
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

  /// Color 밝게 만들기 (amount: 0.0~1.0)
  static Color _brightenColor(Color c, double amount) {
    final r = (c.r + (1.0 - c.r) * amount).clamp(0.0, 1.0);
    final g = (c.g + (1.0 - c.g) * amount).clamp(0.0, 1.0);
    final b = (c.b + (1.0 - c.b) * amount).clamp(0.0, 1.0);
    return Color.from(alpha: c.a, red: r, green: g, blue: b);
  }

  /// Color → CSS rgba 문자열
  static String _colorToRgba(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return 'rgba($r,$g,$b,1)';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 3D Style Layer 기반 지하철 시각화
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Future<void> init3DLayers() async {
    if (_mapboxMap == null || _layersInitialized3D) return;

    final style = _mapboxMap!.style;
    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

    try {
      // 1) 열차 위치 — FillExtrusionLayer (실제 3D 블록)
      await style.addSource(GeoJsonSource(id: _trainSourceId, data: emptyGeoJson));

      // 3D 기둥 (메인 몸체) — emissive로 야간에도 자체 발광
      await style.addLayer(FillExtrusionLayer(
        id: _trainLayerId,
        sourceId: _trainSourceId,
        fillExtrusionColorExpression: ['to-color', ['get', 'color']],
        fillExtrusionBaseExpression: ['get', 'base'],
        fillExtrusionHeightExpression: ['get', 'top'],
        fillExtrusionOpacity: 0.85,
        fillExtrusionVerticalGradient: true,
        fillExtrusionEmissiveStrength: 1.0,
      ));

      debugPrint('[MapboxEngine] ✅ 열차 FillExtrusionLayer 생성 완료');

      // 1-b) 선택된 열차 하이라이트 — 노선색 발광 링 (CircleLayer)
      await style.addSource(GeoJsonSource(id: _selectedTrainSourceId, data: emptyGeoJson));

      // 외곽 발광 (큰 원 + 블러)
      await style.addLayer(CircleLayer(
        id: _selectedTrainLayerId,
        sourceId: _selectedTrainSourceId,
        circleColorExpression: ['to-color', ['get', 'color']],
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          10, 8.0,
          13, 16.0,
          15, 28.0,
          17, 45.0,
        ],
        circleBlur: 0.6,
        circleOpacityExpression: ['get', 'opacity'],
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 9,
        circleEmissiveStrength: 1.0,
      ));

      // 내부 링 (선명한 작은 원)
      await style.addLayer(CircleLayer(
        id: '${_selectedTrainLayerId}-inner',
        sourceId: _selectedTrainSourceId,
        circleColorExpression: ['to-color', ['get', 'color']],
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          10, 4.0,
          13, 8.0,
          15, 14.0,
          17, 22.0,
        ],
        circleOpacityExpression: ['get', 'innerOpacity'],
        circleStrokeColorExpression: ['to-color', ['get', 'color']],
        circleStrokeWidthExpression: [
          'interpolate', ['linear'], ['zoom'],
          10, 1.0,
          15, 2.5,
        ],
        circleStrokeOpacity: 0.9,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 10,
        circleEmissiveStrength: 1.0,
      ));

      // 1-c) 선택된 역 하이라이트 — 발광 링 (CircleLayer)
      await style.addSource(GeoJsonSource(id: _selectedStationSourceId, data: emptyGeoJson));
      await style.addLayer(CircleLayer(
        id: _selectedStationLayerId,
        sourceId: _selectedStationSourceId,
        circleColorExpression: ['to-color', ['get', 'color']],
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          10, 10.0,
          13, 22.0,
          15, 38.0,
          17, 55.0,
        ],
        circleBlur: 0.5,
        circleOpacityExpression: ['get', 'opacity'],
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 2,
        circleEmissiveStrength: 1.0,
      ));

      // 2) 지상 노선 경로 — LineLayer (3D 고도)
      await style.addSource(GeoJsonSource(id: _routeSurfaceSourceId, data: emptyGeoJson));

      await style.addLayer(LineLayer(
        id: _routeSurfaceLayerId,
        sourceId: _routeSurfaceSourceId,
        lineColorExpression: ['to-color', ['get', 'color']],
        lineWidthExpression: [
          'interpolate', ['linear'], ['zoom'],
          8, 1.5,
          11, 3.0,
          14, 5.0,
          17, 8.0,
        ],
        lineOpacity: 0.9,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineEmissiveStrength: 0.8,
      ));

      debugPrint('[MapboxEngine] ✅ 지상 노선 LineLayer 생성 완료');

      // 3) 지하 노선 경로 — LineLayer (바닥, 점선으로 구분)
      await style.addSource(GeoJsonSource(id: _routeUndergroundSourceId, data: emptyGeoJson));

      await style.addLayer(LineLayer(
        id: _routeUndergroundLayerId,
        sourceId: _routeUndergroundSourceId,
        lineColorExpression: ['to-color', ['get', 'color']],
        lineWidthExpression: [
          'interpolate', ['linear'], ['zoom'],
          8, 1.0,
          11, 2.0,
          14, 4.0,
          17, 7.0,
        ],
        lineOpacity: 0.7,
        lineDasharray: [3.0, 2.0],
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineEmissiveStrength: 1.0,
      ));

      debugPrint('[MapboxEngine] ✅ 지하 노선 LineLayer 생성 완료');

      // 4) 역 마커 — MiniTokyo3D 스타일 (줌 반응형)
      await style.addSource(GeoJsonSource(id: _stationSourceId, data: emptyGeoJson));

      // 역 외곽선 (노선색)
      await style.addLayer(CircleLayer(
        id: _stationOutlineLayerId,
        sourceId: _stationSourceId,
        circleColorExpression: ['to-color', ['get', 'color']],
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          8, 1.5,
          11, 3.0,
          13, 5.0,
          15, 8.0,
          17, 12.0,
        ],
        circleStrokeWidth: 0.0,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 3,
        circleEmissiveStrength: 0.8,
      ));

      // 역 내부 (흰색 — MiniTokyo3D 스타일)
      await style.addLayer(CircleLayer(
        id: _stationDotLayerId,
        sourceId: _stationSourceId,
        circleColor: Colors.white.toARGB32(),
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          8, 0.8,
          11, 1.8,
          13, 3.0,
          15, 5.5,
          17, 9.0,
        ],
        circleStrokeWidth: 0.0,
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 4,
        circleEmissiveStrength: 0.8,
      ));

      // 환승역은 더 크게 (isTransfer property)
      // → CircleLayer expression으로 처리

      // 역명 라벨 (줌 14 이상에서 표시)
      await style.addLayer(SymbolLayer(
        id: _stationLabelLayerId,
        sourceId: _stationSourceId,
        textFieldExpression: ['get', 'name'],
        textSize: 11.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: const Color(0xFF1a1a2e).toARGB32(),
        textHaloWidth: 1.5,
        textOffsetExpression: ['literal', [0, 1.5]],
        textAnchor: TextAnchor.TOP,
        textOptional: true,
        textAllowOverlap: false,
        minZoom: 14.0,
        textEmissiveStrength: 1.0,
      ));

      debugPrint('[MapboxEngine] ✅ 역 마커 레이어 생성 완료');

      // 5) 열차별 지연 표시 — 발광 링 + "N분" 라벨
      await style.addSource(GeoJsonSource(id: _delaySourceId, data: emptyGeoJson));

      // 빨간 발광 링 (지연 열차 주변)
      await style.addLayer(CircleLayer(
        id: _delayGlowLayerId,
        sourceId: _delaySourceId,
        circleColorExpression: ['to-color', ['get', 'color']],
        circleRadiusExpression: [
          'interpolate', ['linear'], ['zoom'],
          10, 10.0,
          13, 18.0,
          15, 30.0,
          17, 48.0,
        ],
        circleBlur: 0.6,
        circleOpacityExpression: ['get', 'opacity'],
        circlePitchAlignment: CirclePitchAlignment.MAP,
        circleSortKey: 8,
        circleEmissiveStrength: 1.0,
      ));

      // "N분 지연" 라벨 — 확대 시(줌 14+)에만 표시
      await style.addLayer(SymbolLayer(
        id: _delayLabelLayerId,
        sourceId: _delaySourceId,
        textFieldExpression: ['get', 'label'],
        textSizeExpression: [
          'interpolate', ['linear'], ['zoom'],
          16, 9.0,
          17, 11.0,
          18, 13.0,
        ],
        textColor: Colors.white.toARGB32(),
        textHaloColor: const Color(0xFFCC2222).toARGB32(),
        textHaloWidth: 2.0,
        textOffsetExpression: ['literal', [0, -2.2]],
        textAnchor: TextAnchor.BOTTOM,
        textAllowOverlap: true,
        textEmissiveStrength: 1.0,
        minZoom: 16.0,
      ));

      debugPrint('[MapboxEngine] ✅ 열차 지연 표시 레이어 생성 완료');

      _layersInitialized3D = true;
    } catch (e) {
      debugPrint('[MapboxEngine] ❌ 3D 레이어 초기화 실패: $e');
    }
  }

  @override
  void cleanup3DLayers() {
    if (_mapboxMap == null || !_layersInitialized3D) return;
    final style = _mapboxMap!.style;

    for (final layerId in [
      _delayLabelLayerId, _delayGlowLayerId,
      _stationLabelLayerId, _stationDotLayerId, _stationOutlineLayerId,
      _selectedStationLayerId,
      '${_selectedTrainLayerId}-inner', _selectedTrainLayerId, _trainLayerId,
      _routeSurfaceLayerId, _routeUndergroundLayerId,
    ]) {
      style.removeStyleLayer(layerId);
    }
    for (final sourceId in [
      _delaySourceId,
      _stationSourceId, _selectedStationSourceId,
      _selectedTrainSourceId, _trainSourceId,
      _routeSurfaceSourceId, _routeUndergroundSourceId,
    ]) {
      style.removeStyleSource(sourceId);
    }
    _layersInitialized3D = false;
  }

  /// GeoJSON 소스 데이터 직접 업데이트 (getSource 대신 setStyleSourceProperty 사용)
  Future<void> _updateSourceData(String sourceId, String geojson) async {
    try {
      await _mapboxMap!.style.setStyleSourceProperty(sourceId, 'data', geojson);
    } catch (e) {
      debugPrint('[MapboxEngine] ❌ 소스 업데이트 실패 ($sourceId): $e');
    }
  }

  // 복선 트랙 오프셋 (미터) — 상행/하행 분리 거리
  static const double _trackOffsetM = 15.0;

  /// 진행방향 기준 수직으로 오프셋된 좌표 계산
  /// direction: 0=상행(왼쪽), 1=하행(오른쪽)
  static List<double> _offsetPosition(
    double lat, double lng, double bearing, int direction,
  ) {
    final rad = bearing * 3.14159265 / 180.0;
    // 수직 방향: bearing + 90°(오른쪽) 또는 -90°(왼쪽)
    final sign = direction == 0 ? -1.0 : 1.0;
    final perpX = sign * cos(rad) * _trackOffsetM; // 수직 오프셋 X
    final perpY = sign * -sin(rad) * _trackOffsetM; // 수직 오프셋 Y
    return [
      lat + perpY / _mPerDegLat,
      lng + perpX / _mPerDegLng,
    ];
  }

  /// 열차 위치를 3D 블록용 Polygon으로 변환
  /// 진행방향(bearing)에 맞게 회전 + 상행/하행 오프셋 적용
  List<List<double>> _trainPolygon(
    double lat, double lng, double bearing, bool isExpress, int direction,
  ) {
    // 상행/하행 복선 오프셋 적용
    final offset = _offsetPosition(lat, lng, bearing, direction);
    final oLat = offset[0];
    final oLng = offset[1];

    final lengthM = isExpress ? 60.0 : 45.0;
    final widthM = isExpress ? 25.0 : 20.0;
    final halfL = lengthM / 2;
    final halfW = widthM / 2;

    final rad = bearing * 3.14159265 / 180.0;
    final cosB = cos(rad);
    final sinB = sin(rad);

    final offsets = <List<double>>[
      [-halfW, -halfL],
      [ halfW, -halfL],
      [ halfW,  halfL],
      [-halfW,  halfL],
    ];

    final coords = <List<double>>[];
    for (final o in offsets) {
      final rotX =  o[0] * cosB + o[1] * sinB;
      final rotY = -o[0] * sinB + o[1] * cosB;
      coords.add([oLng + rotX / _mPerDegLng, oLat + rotY / _mPerDegLat]);
    }
    coords.add([coords[0][0], coords[0][1]]);
    return coords;
  }

  /// 노선 좌표를 상행/하행 방향으로 오프셋하여 복선 생성
  static List<List<double>> _offsetRoute(
    List<List<double>> coords, // [lng, lat] 형식
    double offsetM,
  ) {
    if (coords.length < 2) return coords;
    final result = <List<double>>[];

    for (int i = 0; i < coords.length; i++) {
      // 전후 점으로 방향 계산
      final prev = i > 0 ? coords[i - 1] : coords[i];
      final next = i < coords.length - 1 ? coords[i + 1] : coords[i];
      final dLng = next[0] - prev[0];
      final dLat = next[1] - prev[1];
      final len = sqrt(dLng * dLng + dLat * dLat);
      if (len == 0) {
        result.add(coords[i]);
        continue;
      }
      // 수직 방향 (오른쪽 90도)
      final perpLng = -dLat / len * offsetM / _mPerDegLng;
      final perpLat =  dLng / len * offsetM / _mPerDegLat;
      result.add([coords[i][0] + perpLng, coords[i][1] + perpLat]);
    }
    return result;
  }

  @override
  Future<void> updateTrainPositions3D(List<InterpolatedTrainPosition> trains, {Map<String, int> trainDelays = const {}}) async {
    if (_mapboxMap == null || !_layersInitialized3D) return;

    // 열차 높이 (미터)
    const trainHeight = 20.0;

    final features = trains.map((train) {
      final color = SubwayColors.getColor(train.subwayId);
      final isSelected = train.trainNo == _selectedTrainNo;
      final delayMin = trainDelays[train.trainNo] ?? 0;
      final isDelayed = delayMin >= 2;

      // 지연 열차: 빨간색 계열, 선택 열차: 밝은 색
      final String colorStr;
      if (isSelected) {
        colorStr = _colorToRgba(_brightenColor(color, 0.3));
      } else if (isDelayed) {
        // 지연 심각도에 따라 원래 색에 빨간 톤 혼합
        final blend = (delayMin / 15.0).clamp(0.0, 1.0); // 15분 이상이면 완전 빨강
        final r = (color.r + (1.0 - color.r) * blend).clamp(0.0, 1.0);
        final g = (color.g * (1.0 - blend * 0.7)).clamp(0.0, 1.0);
        final b = (color.b * (1.0 - blend * 0.7)).clamp(0.0, 1.0);
        colorStr = 'rgba(${(r*255).round()},${(g*255).round()},${(b*255).round()},1)';
      } else {
        colorStr = _colorToRgba(color);
      }
      final height = isSelected ? trainHeight + 10 : trainHeight;
      final isExpress = train.expressType == 1;
      final polygon = _trainPolygon(
        train.lat, train.lng, train.bearing, isExpress, train.direction,
      );

      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [polygon],
        },
        'properties': {
          'color': colorStr,
          'base': train.altitude,
          'top': train.altitude + height,
          'trainNo': train.trainNo,
          'subwayId': train.subwayId,
          'subwayName': train.subwayName,
          'stationName': train.stationName,
          'direction': train.direction,
          'terminalName': train.terminalName,
          'trainStatus': train.trainStatus,
          'expressType': train.expressType,
          'isLastTrain': train.isLastTrain,
        },
      };
    }).toList();

    final geojson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    await _updateSourceData(_trainSourceId, geojson);

    // 선택된 열차 하이라이트 (발광 링 + 펄스)
    if (_selectedTrainNo != null) {
      final selectedFeatures = <Map<String, dynamic>>[];
      for (final train in trains) {
        if (train.trainNo == _selectedTrainNo) {
          final color = SubwayColors.getColor(train.subwayId);
          final colorStr = _colorToRgba(color);

          // 펄스 애니메이션 (1500ms 주기, 삼각파)
          final p = (DateTime.now().millisecondsSinceEpoch % 1500) / 1500.0 * 2.0;
          final pulse = p < 1.0 ? p : 2.0 - p; // 0→1→0
          final outerOpacity = 0.15 + pulse * 0.35; // 0.15 ~ 0.50
          final innerOpacity = 0.05 + pulse * 0.15; // 0.05 ~ 0.20

          selectedFeatures.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [train.lng, train.lat],
            },
            'properties': {
              'color': colorStr,
              'opacity': outerOpacity,
              'innerOpacity': innerOpacity,
            },
          });
          break;
        }
      }
      await _updateSourceData(_selectedTrainSourceId, jsonEncode({
        'type': 'FeatureCollection',
        'features': selectedFeatures,
      }));
    } else {
      await _updateSourceData(_selectedTrainSourceId,
        '{"type":"FeatureCollection","features":[]}');
    }

    // 열차별 지연 표시 (빨간 발광 링 + "N분" 라벨)
    if (trainDelays.isNotEmpty) {
      final delayFeatures = <Map<String, dynamic>>[];
      // 2초 주기 펄스
      final p = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0 * 2.0;
      final pulse = p < 1.0 ? p : 2.0 - p;

      for (final train in trains) {
        final delayMin = trainDelays[train.trainNo];
        if (delayMin == null || delayMin < 2) continue;

        // 지연 심각도에 따른 색상
        final String delayColor;
        if (delayMin >= 10) {
          delayColor = 'rgba(220,30,30,1)';
        } else if (delayMin >= 5) {
          delayColor = 'rgba(255,60,60,1)';
        } else {
          delayColor = 'rgba(255,160,40,1)';
        }

        final opacity = 0.2 + pulse * 0.4;

        delayFeatures.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [train.lng, train.lat],
          },
          'properties': {
            'color': delayColor,
            'opacity': opacity,
            'label': '$delayMin분 지연',
          },
        });
      }

      await _updateSourceData(_delaySourceId, jsonEncode({
        'type': 'FeatureCollection',
        'features': delayFeatures,
      }));
    } else {
      await _updateSourceData(_delaySourceId,
        '{"type":"FeatureCollection","features":[]}');
    }

    // 선택된 역 하이라이트 (발광 링 + 펄스)
    if (_selectedStationName != null) {
      final station = SeoulSubwayData.findStation(_selectedStationName!);
      if (station != null) {
        // 역이 속한 첫 번째 노선 색상
        Color stationColor = Colors.blueAccent;
        for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
          final stations = SeoulSubwayData.getLineStations(entry.key);
          if (stations.any((s) => s.name == _selectedStationName)) {
            stationColor = SubwayColors.getColor(entry.key);
            break;
          }
        }
        final colorStr = _colorToRgba(stationColor);

        final p = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0 * 2.0;
        final pulse = p < 1.0 ? p : 2.0 - p;
        final opacity = 0.2 + pulse * 0.4;

        await _updateSourceData(_selectedStationSourceId, jsonEncode({
          'type': 'FeatureCollection',
          'features': [{
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [station.lng, station.lat],
            },
            'properties': {
              'color': colorStr,
              'opacity': opacity,
            },
          }],
        }));
      }
    }
  }

  @override
  Future<void> initRoutes3D(
    Map<String, List<List<double>>> routeCoordinates,
    Map<String, Color> lineColors,
    Map<String, List<bool>> segmentUnderground,
  ) async {
    if (_mapboxMap == null || !_layersInitialized3D) return;

    final surfaceFeatures = <Map<String, dynamic>>[];
    final undergroundFeatures = <Map<String, dynamic>>[];

    for (final entry in routeCoordinates.entries) {
      final lineId = entry.key;
      final coords = entry.value; // [[lat, lng], ...]
      final color = lineColors[lineId] ?? Colors.grey;
      final colorStr = _colorToRgba(color);
      final underground = segmentUnderground[lineId] ?? [];

      // 세그먼트를 지상/지하로 분할 후, 각각 복선(좌/우)으로 생성
      void addSegment(List<List<double>> seg, bool isUG) {
        if (seg.length < 2) return;
        // 복선: 좌우 오프셋
        final left = _offsetRoute(seg, -_trackOffsetM);
        final right = _offsetRoute(seg, _trackOffsetM);
        for (final track in [left, right]) {
          final feature = {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': track,
            },
            'properties': {'color': colorStr, 'lineId': lineId},
          };
          if (isUG) {
            undergroundFeatures.add(feature);
          } else {
            surfaceFeatures.add(feature);
          }
        }
      }

      List<List<double>> currentSegment = [];
      bool currentIsUnderground = underground.isNotEmpty && underground[0];

      for (int i = 0; i < coords.length; i++) {
        final isUG = i < underground.length ? underground[i] : true;
        final coord = [coords[i][1], coords[i][0]]; // [lat,lng] → [lng,lat]

        if (i > 0 && isUG != currentIsUnderground) {
          currentSegment.add(coord);
          addSegment(currentSegment, currentIsUnderground);
          currentSegment = [coord];
          currentIsUnderground = isUG;
        } else {
          currentSegment.add(coord);
        }
      }
      addSegment(currentSegment, currentIsUnderground);
    }

    // Source 업데이트 (setStyleSourceProperty 직접 사용)
    await _updateSourceData(_routeSurfaceSourceId, jsonEncode({
      'type': 'FeatureCollection',
      'features': surfaceFeatures,
    }));

    await _updateSourceData(_routeUndergroundSourceId, jsonEncode({
      'type': 'FeatureCollection',
      'features': undergroundFeatures,
    }));

    debugPrint('[MapboxEngine] Routes 3D: ${surfaceFeatures.length} surface, '
        '${undergroundFeatures.length} underground segments');
  }

  @override
  Future<void> updateStations3D(List<Map<String, dynamic>> stations) async {
    if (_mapboxMap == null || !_layersInitialized3D) return;

    final features = stations.map((s) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [s['lng'], s['lat']],
      },
      'properties': {
        'name': s['name'],
        'color': s['color'],
        'isTransfer': s['isTransfer'] ?? false,
      },
    }).toList();

    final geojson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    await _updateSourceData(_stationSourceId, geojson);
    debugPrint('[MapboxEngine] 🚉 역 ${stations.length}개 업데이트');
  }

  @override
  Future<void> updateDelayShield3D(Map<String, int> delayInfo) async {
    // 열차별 지연은 updateTrainPositions3D에서 직접 처리
  }

  @override
  void setUndergroundVisible(bool visible) {
    _undergroundVisible = visible;
    if (_mapboxMap != null && _layersInitialized3D) {
      _mapboxMap!.style.setStyleLayerProperty(
        _routeUndergroundLayerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
    }
  }

  @override
  void setOnTrainTapped(void Function(String trainNo)? callback) {
    _onTrainTapped = callback;
  }

  @override
  void setOnStationTapped(void Function(String stationName)? callback) {
    _onStationTapped = callback;
  }

  @override
  void setOnMapTappedEmpty(VoidCallback? callback) {
    _onMapTappedEmpty = callback;
  }

  @override
  void setSelectedTrain(String? trainNo) {
    _selectedTrainNo = trainNo;
    if (trainNo == null) {
      _isFollowing = false;
    }
  }

  @override
  void setSelectedStation(String? stationName) {
    _selectedStationName = stationName;
    if (stationName == null) {
      // 하이라이트 제거
      _updateSourceData(_selectedStationSourceId,
        '{"type":"FeatureCollection","features":[]}');
    }
  }

  @override
  void followTrain(double lat, double lng, double bearing) {
    if (_mapboxMap == null) return;
    if (!_isFollowing) {
      // 최초 선택 또는 열차 전환 시 flyTo로 부드럽게 이동
      _isFollowing = true;
      _flyToEndTime = DateTime.now().millisecondsSinceEpoch + _flyToDurationMs;
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 15.5,
          pitch: 55,
        ),
        MapAnimationOptions(duration: _flyToDurationMs),
      );
    } else {
      // flyTo 진행 중이면 무시
      if (DateTime.now().millisecondsSinceEpoch < _flyToEndTime) return;
      // 추적 중: setCamera로 강제 고정
      _mapboxMap!.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
      ));
    }
  }

  static const int _flyToDurationMs = 800;
  int _flyToEndTime = 0;

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // 맵 탭 리스너 — 열차 클릭 감지
    mapboxMap.setOnMapTapListener((mapContentGestureContext) {
      _handleMapTap(mapContentGestureContext);
    });

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

  /// 맵 탭 처리: 열차 레이어 hit test
  Future<void> _handleMapTap(MapContentGestureContext context) async {
    if (_mapboxMap == null || !_layersInitialized3D) return;

    final screenPoint = context.touchPosition;
    // 탭 주변 영역에서 열차 레이어 feature 검색
    final screenBox = ScreenBox(
      min: ScreenCoordinate(x: screenPoint.x - 30, y: screenPoint.y - 30),
      max: ScreenCoordinate(x: screenPoint.x + 30, y: screenPoint.y + 30),
    );

    try {
      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(screenBox),
        RenderedQueryOptions(layerIds: [_trainLayerId]),
      );

      if (features.isNotEmpty) {
        final feature = features.first?.queriedFeature.feature;
        if (feature != null) {
          final props = feature['properties'];
          if (props is Map) {
            final trainNo = props['trainNo'];
            if (trainNo != null && _onTrainTapped != null) {
              _onTrainTapped!(trainNo.toString());
              return;
            }
          }
        }
      }

      // 열차 못 찾으면 역 레이어 검색
      final stationBox = ScreenBox(
        min: ScreenCoordinate(x: screenPoint.x - 40, y: screenPoint.y - 40),
        max: ScreenCoordinate(x: screenPoint.x + 40, y: screenPoint.y + 40),
      );
      final stationFeatures = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(stationBox),
        RenderedQueryOptions(layerIds: [_stationOutlineLayerId, _stationDotLayerId]),
      );

      if (stationFeatures.isNotEmpty) {
        final feature = stationFeatures.first?.queriedFeature.feature;
        if (feature != null) {
          final props = feature['properties'];
          if (props is Map) {
            final name = props['name'];
            if (name != null && _onStationTapped != null) {
              _onStationTapped!(name.toString());
              return;
            }
          }
        }
      }

      // 빈 곳 탭 — 선택 해제
      if (_isFollowing) {
        _isFollowing = false;
      }
      _onMapTappedEmpty?.call();
    } catch (e) {
      debugPrint('[MapboxEngine] 탭 쿼리 실패: $e');
    }
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
