import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/map_interface.dart';
import 'core/api_keys.dart';
import 'map_engines/mapbox_engine.dart';
import 'map_engines/google_map_engine.dart';
import 'map_engines/naver_map_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ApiKeys 클래스에서 값 가져오기
  MapboxOptions.setAccessToken(ApiKeys.mapboxAccessToken);

  // Naver Map SDK 초기화
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
  double _pitch = 0.0;
  double _zoom = 12.0;
  CameraInfo _cameraInfo = CameraInfo(lat: 37.5665, lng: 126.9780, zoom: 12.0, pitch: 0.0, bearing: 0.0);

  void _onMapCreated(IMapController controller) => _mapController = controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(key: ValueKey(_currentMapType), child: _buildActiveMapEngine()),
          Positioned(top: 60, right: 20, child: _buildDebugPanel()),
          Positioned(bottom: 40, left: 20, right: 20, child: _buildControlPanel()),
          Positioned(top: 60, left: 20, child: _buildMapSwitcher()),
        ],
      ),
    );
  }

  Widget _buildActiveMapEngine() {
    switch (_currentMapType) {
      case MapType.mapbox: return MapboxEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
      case MapType.google: return GoogleMapEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
      case MapType.naver: return NaverMapEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated);
    }
  }

  Widget _buildMapSwitcher() {
    return Card(
      elevation: 10, color: Colors.black.withOpacity(0.85),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: MapType.values.map((type) => IconButton(
            icon: Icon(type == MapType.mapbox ? Icons.layers : type == MapType.google ? Icons.language : Icons.map,
            color: _currentMapType == type ? Colors.blueAccent : Colors.white24),
            onPressed: () => setState(() { _currentMapType = type; _mapController = null; }),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Card(color: Colors.black.withOpacity(0.7), child: Container(padding: const EdgeInsets.all(12.0), width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_currentMapType.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
      const Divider(height: 15, color: Colors.white10),
      _debugRow('LAT', _cameraInfo.lat.toStringAsFixed(4)),
      _debugRow('LNG', _cameraInfo.lng.toStringAsFixed(4)),
    ])));
  }

  Widget _debugRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 10))]);

  Widget _buildControlPanel() {
    return Card(color: Colors.black.withOpacity(0.8), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisSize: MainAxisSize.min, children: [
      _sliderRow('PITCH', _pitch, 0, 60, (v) { setState(() => _pitch = v); _mapController?.setPitch(v); }),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _quickActionBtn('CITY HALL', 37.5665, 126.9780),
        _quickActionBtn('GANGNAM', 37.4979, 127.0276),
      ]),
    ])));
  }

  Widget _sliderRow(String l, double v, double min, double max, Function(double) f) => Row(children: [Text(l, style: const TextStyle(fontSize: 9)), Expanded(child: Slider(value: v, min: min, max: max, onChanged: f)), Text('${v.toInt()}')]);
  Widget _quickActionBtn(String l, double lat, double lng) => OutlinedButton(onPressed: () => setState(() { _cameraInfo = CameraInfo(lat: lat, lng: lng, zoom: _zoom, pitch: _pitch, bearing: 0.0); _mapController?.moveTo(lat, lng); }), child: Text(l, style: const TextStyle(fontSize: 10)));
}
