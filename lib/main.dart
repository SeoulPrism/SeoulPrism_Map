import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/map_interface.dart';
import 'core/api_keys.dart';
import 'map_engines/mapbox_engine.dart';
import 'map_engines/google_map_engine.dart';
import 'map_engines/naver_map_engine.dart';
import 'models/subway_models.dart';
import 'widgets/subway_overlay.dart';
import 'widgets/subway_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxOptions.setAccessToken(ApiKeys.mapboxAccessToken);

  await NaverMapSdk.instance.initialize(
    clientId: ApiKeys.naverClientId,
  );

  runApp(const SeoulPrismApp());
}

class SeoulPrismApp extends StatelessWidget {
  const SeoulPrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeoulPrism_Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  MapType _currentMapType = MapType.mapbox;
  IMapController? _mapController;

  double _pitch = 45.0;
  double _zoom = 13.0; // 서울 전체가 보이도록 약간 축소
  bool _isTerrainEnabled = false;
  String _lightPreset = 'day';

  CameraInfo _cameraInfo = CameraInfo(
    lat: 37.5665, lng: 126.9780, zoom: 13.0, pitch: 45.0, bearing: 0.0,
  );

  // 지하철 오버레이 컨트롤러
  final SubwayOverlayController _subwayController = SubwayOverlayController();

  // 도착정보 팝업 상태
  String? _selectedStation;
  List<ArrivalInfo> _selectedStationArrivals = [];
  bool _showArrivalPanel = false;

  // 선택된 열차 정보
  InterpolatedTrainPosition? _selectedTrain;

  // 지하철 패널 드래그 위치
  Offset _subwayPanelOffset = const Offset(20, 200);

  @override
  void initState() {
    super.initState();
    _subwayController.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _subwayController.dispose();
    super.dispose();
  }

  void _onMapCreated(IMapController controller) {
    _mapController = controller;
    _subwayController.attachMap(controller);
  }

  // 랜덤 마커 스트레스 테스트
  void _stressTestMarkers() {
    if (_mapController == null) return;
    _mapController!.clearMarkers();
    final random = Random();
    for (int i = 0; i < 50; i++) {
      double lat = 37.5665 + (random.nextDouble() - 0.5) * 0.02;
      double lng = 126.9780 + (random.nextDouble() - 0.5) * 0.02;
      _mapController!.addMarker('marker_$i', lat, lng, title: 'POI $i');
    }
  }

  // 역 도착정보 조회
  Future<void> _showStationArrival(String stationName) async {
    setState(() {
      _selectedStation = stationName;
      _showArrivalPanel = true;
      _selectedStationArrivals = [];
    });

    final arrivals = await _subwayController.getStationArrivals(stationName);
    if (mounted) {
      setState(() {
        _selectedStationArrivals = arrivals;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(key: ValueKey(_currentMapType), child: _buildActiveMapEngine()),

          // 맵 스위처 (상단 좌측)
          Positioned(top: 60, left: 20, child: _buildMapSwitcher()),

          // 디버그 패널 (상단 우측)
          Positioned(top: 60, right: 20, child: _buildDebugPanel()),

          // 지하철 컨트롤 패널 (드래그 가능)
          Positioned(
            left: _subwayPanelOffset.dx,
            top: _subwayPanelOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _subwayPanelOffset += details.delta;
                });
              },
              child: SubwayControlPanel(
                controller: _subwayController,
                onRefresh: () => setState(() {}),
              ),
            ),
          ),

          // 컨트롤 패널 (하단)
          Positioned(bottom: 30, left: 20, right: 20, child: _buildControlPanel()),

          // 역 도착정보 패널 (중앙)
          if (_showArrivalPanel && _selectedStation != null)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: StationArrivalPanel(
                  stationName: _selectedStation!,
                  arrivals: _selectedStationArrivals,
                  onClose: () => setState(() => _showArrivalPanel = false),
                ),
              ),
            ),

          // 열차 정보 툴팁
          if (_selectedTrain != null)
            Positioned(
              bottom: 220,
              left: 0,
              right: 0,
              child: Center(
                child: TrainInfoTooltip(
                  train: _selectedTrain!,
                  onClose: () => setState(() => _selectedTrain = null),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveMapEngine() {
    switch (_currentMapType) {
      case MapType.mapbox:
        return MapboxEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
      case MapType.google:
        return GoogleMapEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
      case MapType.naver:
        return NaverMapEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
    }
  }

  Widget _buildMapSwitcher() {
    return Card(
      elevation: 10,
      color: Colors.black.withOpacity(0.85),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: MapType.values.map((type) => IconButton(
            icon: Icon(
              type == MapType.mapbox ? Icons.layers
                  : type == MapType.google ? Icons.language
                  : Icons.map,
              color: _currentMapType == type ? Colors.blueAccent : Colors.white24,
            ),
            onPressed: () {
              setState(() {
                _currentMapType = type;
                _mapController = null;
              });
              // 맵 전환 시 지하철 오버레이 재연결
              if (_subwayController.isActive) {
                _subwayController.stop();
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Card(
      color: Colors.black.withOpacity(0.7),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentMapType.name.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(height: 15, color: Colors.white10),
            _debugRow('LAT', _cameraInfo.lat.toStringAsFixed(4)),
            _debugRow('LNG', _cameraInfo.lng.toStringAsFixed(4)),
            _debugRow('ZOOM', _zoom.toStringAsFixed(1)),
            const Divider(height: 15, color: Colors.white10),

            // 실시간 열차 수
            if (_subwayController.isActive) ...[
              _debugRow('TRAINS', '${_subwayController.currentTrains.length}'),
              _debugRow('API', '${_subwayController.totalTrainCount}'),
              if (_subwayController.lastError != null)
                Text('ERR: ${_subwayController.lastError}',
                    style: const TextStyle(fontSize: 7, color: Colors.redAccent),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              const Divider(height: 15, color: Colors.white10),
            ],

            const Text('ENGINE FEATURES', style: TextStyle(fontSize: 8, color: Colors.grey)),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('3D Terrain', style: TextStyle(fontSize: 10)),
                Switch.adaptive(
                  value: _isTerrainEnabled,
                  onChanged: (v) {
                    setState(() => _isTerrainEnabled = v);
                    _mapController?.setTerrain(v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(v, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );

  Widget _buildControlPanel() {
    return Card(
      color: Colors.black.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _actionChip('STRESS TEST', Icons.bolt, _stressTestMarkers),
                const SizedBox(width: 8),
                _actionChip('CLEAR', Icons.delete_outline, () => _mapController?.clearMarkers()),
                const Spacer(),
                DropdownButton<String>(
                  value: _lightPreset,
                  items: ['day', 'night', 'dawn', 'dusk']
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 10))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _lightPreset = v);
                      _mapController?.setLightPreset(v);
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white10),
            _sliderRow('PITCH', _pitch, 0, 75, (v) {
              setState(() => _pitch = v);
              _mapController?.setPitch(v);
            }),
            _sliderRow('ZOOM', _zoom, 8, 20, (v) {
              setState(() => _zoom = v);
              _mapController?.setZoom(v);
            }),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickActionBtn('CITY HALL', 37.5665, 126.9780),
                  _quickActionBtn('GANGNAM', 37.4979, 127.0276),
                  _quickActionBtn('HONGDAE', 37.5567, 126.9236),
                  const SizedBox(width: 8),
                  // 역 도착정보 조회 버튼들
                  _stationBtn('서울역'),
                  _stationBtn('강남'),
                  _stationBtn('홍대입구'),
                  _stationBtn('잠실'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String l, IconData i, VoidCallback onTap) => ActionChip(
    avatar: Icon(i, size: 14),
    label: Text(l, style: const TextStyle(fontSize: 9)),
    onPressed: onTap,
    backgroundColor: Colors.blueGrey[900],
  );

  Widget _sliderRow(String l, double v, double min, double max, Function(double) f) =>
      Row(children: [
        SizedBox(width: 40, child: Text(l, style: const TextStyle(fontSize: 9))),
        Expanded(child: Slider(value: v, min: min, max: max, onChanged: f)),
        Text('${v.toInt()}', style: const TextStyle(fontSize: 9)),
      ]);

  Widget _quickActionBtn(String l, double lat, double lng) => Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: OutlinedButton(
      onPressed: () {
        setState(() {
          _cameraInfo = CameraInfo(lat: lat, lng: lng, zoom: _zoom, pitch: _pitch, bearing: 0.0);
        });
        _mapController?.moveTo(lat, lng, zoom: _zoom, pitch: _pitch);
      },
      child: Text(l, style: const TextStyle(fontSize: 9)),
    ),
  );

  Widget _stationBtn(String stationName) => Padding(
    padding: const EdgeInsets.only(right: 4.0),
    child: OutlinedButton.icon(
      icon: const Icon(Icons.train, size: 12),
      label: Text(stationName, style: const TextStyle(fontSize: 9)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.greenAccent,
        side: const BorderSide(color: Colors.greenAccent, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      onPressed: () => _showStationArrival(stationName),
    ),
  );
}
