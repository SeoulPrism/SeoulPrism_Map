import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/map_interface.dart';
import 'core/api_keys.dart';
import 'map_engines/mapbox_engine.dart';
import 'models/subway_models.dart';
import 'widgets/subway_overlay.dart';
import 'widgets/weather_widget.dart';
import 'widgets/subway_panel.dart';
import 'widgets/station_search_bar.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxOptions.setAccessToken(ApiKeys.mapboxAccessToken);
  MapboxMapsOptions.setLanguage('ko');

  await SettingsService.init();

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
  IMapController? _mapController;
  bool _settingsOpen = false;

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
    // 자동으로 데모 모드 시작
    if (!_subwayController.isActive) {
      _subwayController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 65;
    final screenHeight = MediaQuery.of(context).size.height;
    final stationPanelMaxHeight = screenHeight * 0.3;

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBottomTabBar(),
      body: Stack(
        children: [
          // 지도 엔진 (항상 렌더링)
          Positioned.fill(child: MapboxEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated)),

          // 검색바 + 프로필 (상단, 리퀴드 글라스)
          StationSearchBar(
            onStationSelected: (name) {
              _subwayController.selectStation(name);
            },
          ),

          // 날씨/시간 위젯 (검색바 아래, 우측)
          if (_subwayController.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              right: 12,
              child: WeatherTimeWidget(environment: _subwayController.environment),
            ),

          // 열차 상세 패널 (바텀 슬라이드 애니메이션)
          if (_lastSelectedTrain != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: _selectedTrain != null ? Curves.easeOutCubic : Curves.easeInCubic,
              bottom: _selectedTrain != null ? bottomInset : -280,
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

          // 역 상세 패널 (바텀 슬라이드 — 화면 30% 제한)
          if (_lastSelectedMapStation != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: _selectedMapStation != null ? Curves.easeOutCubic : Curves.easeInCubic,
              bottom: _selectedMapStation != null ? bottomInset : -(stationPanelMaxHeight + 50),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _selectedMapStation != null ? 1.0 : 0.0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: stationPanelMaxHeight),
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
            ),

          // 설정 패널 오버레이 (바텀시트 스타일)
          _buildSettingsOverlay(context, screenHeight, bottomInset),
        ],
      ),
    );
  }

  // ── 하단 탭바 (리퀴드 글라스) ──
  Widget _buildBottomTabBar() {
    return CNTabBar(
      currentIndex: _settingsOpen ? 1 : 0,
      onTap: (index) {
        setState(() {
          if (index == 1) {
            _settingsOpen = !_settingsOpen;
          } else {
            _settingsOpen = false;
          }
        });
      },
      items: const [
        CNTabBarItem(label: '지도', customIcon: Icons.map),
        CNTabBarItem(label: '설정', customIcon: Icons.settings),
      ],
    );
  }

  // ── 설정 오버레이 패널 ──
  Widget _buildSettingsOverlay(BuildContext context, double screenHeight, double bottomInset) {
    final panelHeight = screenHeight * 0.55;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: _settingsOpen ? Curves.easeOutCubic : Curves.easeInCubic,
      bottom: _settingsOpen ? 0 : -panelHeight - 50,
      left: 0,
      right: 0,
      height: panelHeight,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _settingsOpen ? 1.0 : 0.0,
        child: SettingsPanel(
          subwayController: _subwayController,
          mapController: _mapController,
          onClose: () => setState(() => _settingsOpen = false),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 설정 오버레이 패널 (지도 위 바텀시트)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class SettingsPanel extends StatefulWidget {
  final SubwayOverlayController subwayController;
  final IMapController? mapController;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.subwayController,
    this.mapController,
    required this.onClose,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  String _lightPreset = SettingsService.instance.lightPreset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE60a0a1a),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들 + 닫기
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Text('설정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // 컨텐츠 스크롤
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 65),
              children: [
                _sectionHeader('지하철'),
                _buildSubwaySection(),
                const SizedBox(height: 16),
                _sectionHeader('표시'),
                _buildToggleSection(),
                const SizedBox(height: 16),
                _sectionHeader('노선 필터'),
                _buildLineFilterSection(),
                const SizedBox(height: 16),
                _sectionHeader('성능'),
                _buildQualitySection(),
                const SizedBox(height: 16),
                _sectionHeader('라이팅'),
                _buildLightingSection(),
                const SizedBox(height: 16),
                _sectionHeader('정보'),
                _buildInfoSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSubwaySection() {
    final ctrl = widget.subwayController;
    final isActive = ctrl.isActive;
    final isDemo = ctrl.mode == SubwayMode.demo;

    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // 전원 + 모드
            Row(
              children: [
                Icon(Icons.train, size: 18, color: isActive ? Colors.greenAccent : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  isActive ? (isDemo ? 'DEMO 실행 중' : 'LIVE 실행 중') : '꺼짐',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey,
                  ),
                ),
                const Spacer(),
                // 모드 전환
                GestureDetector(
                  onTap: () {
                    ctrl.setMode(isDemo ? SubwayMode.live : SubwayMode.demo);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDemo ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDemo ? Colors.orangeAccent : Colors.blueAccent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isDemo ? 'DEMO' : 'LIVE',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: isDemo ? Colors.orangeAccent : Colors.blueAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 전원 버튼
                GestureDetector(
                  onTap: () {
                    if (isActive) {
                      ctrl.stop();
                    } else {
                      ctrl.start();
                    }
                    setState(() {});
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white10,
                      border: Border.all(color: isActive ? Colors.greenAccent : Colors.grey, width: 1.5),
                    ),
                    child: Icon(Icons.power_settings_new, size: 14,
                        color: isActive ? Colors.greenAccent : Colors.grey),
                  ),
                ),
              ],
            ),
            // 상태 정보
            if (isActive) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('열차 ${ctrl.currentTrains.length}대',
                      style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  if (ctrl.lastUpdate != null)
                    Text(
                      '갱신 ${ctrl.lastUpdate!.hour.toString().padLeft(2, '0')}:${ctrl.lastUpdate!.minute.toString().padLeft(2, '0')}:${ctrl.lastUpdate!.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSection() {
    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            _toggleRow('노선 경로', widget.subwayController.showRoutes, (v) {
              widget.subwayController.toggleRoutes(v);
              setState(() {});
            }),
            _toggleRow('열차 위치', widget.subwayController.showTrains, (v) {
              widget.subwayController.toggleTrains(v);
              setState(() {});
            }),
            _toggleRow('역 표시', widget.subwayController.showStations, (v) {
              widget.subwayController.toggleStations(v);
              setState(() {});
            }),
            const Divider(height: 12, color: Colors.white12),
            _toggleRow('서울시 공공 API (60s)', widget.subwayController.useSeoulApi, (v) {
              widget.subwayController.setUseSeoulApi(v);
              setState(() {});
            }),
            _toggleRow('네이버 API (5s)', widget.subwayController.useNaverApi, (v) {
              widget.subwayController.setUseNaverApi(v);
              setState(() {});
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLineFilterSection() {
    final ctrl = widget.subwayController;
    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('표시할 노선 선택', style: TextStyle(fontSize: 10, color: Colors.white70)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ctrl.setLineFilter(null);
                    setState(() {});
                  },
                  child: const Text('전체', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: SubwayColors.lineColors.entries.map((entry) {
                final lineId = entry.key;
                final color = entry.value;
                final name = SubwayColors.lineNames[lineId] ?? lineId;
                final isSelected = ctrl.selectedLines == null ||
                    ctrl.selectedLines!.contains(lineId);

                return GestureDetector(
                  onTap: () {
                    final current = ctrl.selectedLines ??
                        Set<String>.from(SubwayColors.lineColors.keys);
                    if (current.contains(lineId)) {
                      current.remove(lineId);
                    } else {
                      current.add(lineId);
                    }
                    ctrl.setLineFilter(current.isEmpty ? null : current);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
                      border: Border.all(color: isSelected ? color : Colors.white12, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(name, style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? color : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Transform.scale(
            scale: 0.7,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySection() {
    final ctrl = widget.subwayController;
    final current = ctrl.qualityPreset;
    final isAndroid = Platform.isAndroid;

    final presets = <String, (String, String, IconData)>{
      'high':   ('고사양', '60fps · 부드러운 애니메이션', Icons.hd),
      'medium': ('중간',   '30fps · 균형 잡힌 성능', Icons.sd),
      'low':    ('저사양', '10fps · 배터리 절약', Icons.battery_saver),
    };

    return Card(
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 품질 프리셋 선택
            ...presets.entries.map((e) {
              final key = e.key;
              final (label, desc, icon) = e.value;
              final isSelected = current == key;
              return GestureDetector(
                onTap: () {
                  ctrl.setQualityPreset(key);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.white10,
                      width: isSelected ? 1.2 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: isSelected ? Colors.blueAccent : Colors.white38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.white70,
                            )),
                            Text(desc, style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? Colors.white54 : Colors.white30,
                            )),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, size: 16, color: Colors.blueAccent),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 16, color: Colors.white10),
            // 시스템 정보
            Row(
              children: [
                Icon(Icons.memory, size: 14, color: Colors.white30),
                const SizedBox(width: 6),
                Text(
                  '렌더링: ${isAndroid ? "OpenGL ES" : "Metal"} · GeoJSON 캐싱',
                  style: const TextStyle(fontSize: 9, color: Colors.white30),
                ),
              ],
            ),
          ],
        ),
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
            const Text('라이트 프리셋', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
                    SettingsService.instance.setLightPreset(preset);
                    SettingsService.instance.setAutoLighting(preset == 'auto');
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
            subtitle: 'Mapbox Maps SDK v11',
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
      leading: Icon(icon, size: 18, color: Colors.white54),
      title: Text(title, style: const TextStyle(fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      trailing: trailing,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
