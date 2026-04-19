import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/map_interface.dart';
import 'core/api_keys.dart';
import 'map_engines/mapbox_engine.dart';
import 'map_engines/google_map_engine.dart';
import 'map_engines/naver_map_engine.dart';
import 'models/subway_models.dart';
import 'widgets/subway_overlay.dart';
import 'widgets/weather_widget.dart';
import 'widgets/subway_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxOptions.setAccessToken(ApiKeys.mapboxAccessToken);
  MapboxMapsOptions.setLanguage('ko');


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
  bool _showSettings = false;

  final CameraInfo _cameraInfo = CameraInfo(
    lat: 37.5665, lng: 126.9780, zoom: 13.0, pitch: 45.0, bearing: 0.0,
  );

  // 지하철 오버레이 컨트롤러
  final SubwayOverlayController _subwayController = SubwayOverlayController();

  // 선택된 열차 정보
  InterpolatedTrainPosition? _selectedTrain;
  InterpolatedTrainPosition? _lastSelectedTrain;

  // 역 클릭 상세 패널
  String? _selectedMapStation;
  StationInfo? _selectedMapStationInfo;
  List<ArrivalInfo> _selectedMapStationArrivals = [];
  bool _mapStationLoading = false;
  // 슬라이드아웃 애니메이션용
  String? _lastSelectedMapStation;
  StationInfo? _lastSelectedMapStationInfo;
  List<ArrivalInfo> _lastMapStationArrivals = [];

  // 지하철 패널 드래그 위치
  Offset _subwayPanelOffset = const Offset(20, 60);

  @override
  void initState() {
    super.initState();
    _subwayController.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _subwayController.onTrainSelected = (train) {
      if (mounted) {
        setState(() {
          _selectedTrain = train;
          if (train != null) _lastSelectedTrain = train;
        });
      }
    };
    _subwayController.onStationSelected = (name, info, arrivals, loading) {
      if (mounted) {
        setState(() {
          _selectedMapStation = name;
          _selectedMapStationInfo = info;
          _selectedMapStationArrivals = arrivals;
          _mapStationLoading = loading;
          if (name != null) {
            _lastSelectedMapStation = name;
            _lastSelectedMapStationInfo = info;
            _lastMapStationArrivals = arrivals;
          }
          // 역 도착 데이터 갱신 시 last도 업데이트
          if (name != null && !loading) {
            _lastMapStationArrivals = arrivals;
          }
        });
      }
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

  void _switchMapType(MapType type) {
    if (type == _currentMapType) return;
    setState(() {
      _currentMapType = type;
      _mapController = null;
    });
    if (_subwayController.isActive) {
      _subwayController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomTabBar(),
      body: _showSettings
          ? SettingsPage(
              subwayController: _subwayController,
              mapController: _mapController,
            )
          : Stack(
              children: [
                // 지도 엔진
                Positioned.fill(key: ValueKey(_currentMapType), child: _buildActiveMapEngine()),

                // 날씨/시간 위젯 (우상단)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: WeatherTimeWidget(environment: _subwayController.environment),
                ),

                // 지하철 컨트롤 패널 (드래그 가능, 상단 좌측)
                Positioned(
                  left: _subwayPanelOffset.dx,
                  top: _subwayPanelOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final size = MediaQuery.of(context).size;
                        final dx = (_subwayPanelOffset.dx + details.delta.dx).clamp(0.0, size.width - 60);
                        final dy = (_subwayPanelOffset.dy + details.delta.dy).clamp(0.0, size.height - 60);
                        _subwayPanelOffset = Offset(dx, dy);
                      });
                    },
                    child: SubwayControlPanel(
                      controller: _subwayController,
                      onRefresh: () => setState(() {}),
                    ),
                  ),
                ),

                // 열차 상세 패널 (바텀 슬라이드 애니메이션)
                if (_lastSelectedTrain != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: _selectedTrain != null ? Curves.easeOutCubic : Curves.easeInCubic,
                    bottom: _selectedTrain != null ? 70 : -280,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _selectedTrain != null ? 1.0 : 0.0,
                      child: TrainDetailPanel(
                        train: (_selectedTrain ?? _lastSelectedTrain)!,
                        delayMinutes: _subwayController.trainDelays[(_selectedTrain ?? _lastSelectedTrain)!.trainNo] ?? 0,
                        onClose: () {
                          _subwayController.deselectTrain();
                        },
                      ),
                    ),
                  ),

                // 역 상세 패널 (바텀 슬라이드 애니메이션)
                if (_lastSelectedMapStation != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: _selectedMapStation != null ? Curves.easeOutCubic : Curves.easeInCubic,
                    bottom: _selectedMapStation != null ? 70 : -450,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _selectedMapStation != null ? 1.0 : 0.0,
                      child: StationDetailPanel(
                        stationName: (_selectedMapStation ?? _lastSelectedMapStation)!,
                        stationInfo: _selectedMapStation != null ? _selectedMapStationInfo : _lastSelectedMapStationInfo,
                        arrivals: _selectedMapStation != null ? _selectedMapStationArrivals : _lastMapStationArrivals,
                        isLoading: _mapStationLoading,
                        onClose: () {
                          _subwayController.deselectStation();
                        },
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

  // ── 하단 탭바 (리퀴드 글라스) ──
  Widget _buildBottomTabBar() {
    final tabIndex = _showSettings ? 3 : _currentMapType.index;
    return CNTabBar(
      currentIndex: tabIndex,
      onTap: (index) {
        if (index < MapType.values.length) {
          setState(() => _showSettings = false);
          _switchMapType(MapType.values[index]);
        } else {
          setState(() {
            _showSettings = !_showSettings;
            if (_showSettings && _subwayController.isActive) {
              _subwayController.stop();
            }
          });
        }
      },
      items: const [
        CNTabBarItem(label: 'Mapbox', customIcon: Icons.layers),
        CNTabBarItem(label: 'Google', customIcon: Icons.language),
        CNTabBarItem(label: 'Naver', customIcon: Icons.map),
        CNTabBarItem(label: '설정', customIcon: Icons.settings),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 설정 페이지
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class SettingsPage extends StatefulWidget {
  final SubwayOverlayController subwayController;
  final IMapController? mapController;

  const SettingsPage({
    super.key,
    required this.subwayController,
    this.mapController,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lightPreset = 'auto';

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF0a0a1a),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, bottomPadding + 80),
        children: [
          const Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          _sectionHeader('성능'),
          _buildPerformanceSection(),
          const SizedBox(height: 24),
          _sectionHeader('라이팅'),
          _buildLightingSection(),
          const SizedBox(height: 24),
          _sectionHeader('정보'),
          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    final isAndroid = Platform.isAndroid;
    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.speed,
            title: '렌더링 백엔드',
            subtitle: isAndroid
                ? 'OpenGL ES (Mapbox SDK 기본값)'
                : 'Metal (자동)',
            trailing: Icon(
              isAndroid ? Icons.auto_awesome : Icons.check_circle,
              size: 18,
              color: Colors.white38,
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          _settingTile(
            icon: Icons.animation,
            title: '애니메이션 프레임 레이트',
            subtitle: '60fps (자동 적응형)',
            trailing: const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
          ),
          const Divider(height: 1, color: Colors.white10),
          _settingTile(
            icon: Icons.memory,
            title: '렌더링 최적화',
            subtitle: 'StringBuffer GeoJSON, 동시실행 방지, 캐싱',
            trailing: const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildLightingSection() {
    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('라이트 프리셋', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['auto', 'day', 'night', 'dawn', 'dusk'].map((preset) {
                final isSelected = _lightPreset == preset;
                return ChoiceChip(
                  label: Text(preset.toUpperCase(), style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.white54,
                  )),
                  selected: isSelected,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.white10,
                  onSelected: (_) {
                    setState(() => _lightPreset = preset);
                    widget.subwayController.autoLighting = (preset == 'auto');
                    if (preset == 'auto') {
                      final env = widget.subwayController.environment;
                      if (env != null) {
                        widget.mapController?.applyWeatherEffect(lightPreset: env.lightPreset);
                      }
                    } else {
                      widget.mapController?.setLightPreset(preset);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.info_outline,
            title: '맵 엔진',
            subtitle: 'Mapbox Maps SDK v11 (mapbox_maps_flutter 2.21.0)',
          ),
          const Divider(height: 1, color: Colors.white10),
          _settingTile(
            icon: Icons.phone_android,
            title: '플랫폼',
            subtitle: Platform.isAndroid
                ? 'Android (${Platform.operatingSystemVersion})'
                : 'iOS (${Platform.operatingSystemVersion})',
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.white54),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      trailing: trailing,
      dense: true,
    );
  }
}
