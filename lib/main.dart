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
import 'data/seoul_subway_data.dart';
import 'services/settings_service.dart';
import 'services/path_finding_service.dart';
import 'data/subway_geojson_loader.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'theme/app_spacing.dart';
import 'widgets/app_badge.dart';
import 'dart:math';

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
      theme: AppTheme.dark,
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
  // 길찾기 모드 / 검색 포커스 상태
  bool _isNavMode = false;
  bool _isSearchFocused = false;

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

  // ── 경로 지도 표시 ──

  int _routeAnimId = 0; // 애니메이션 취소용

  Future<void> _drawRouteOnMap(PathResult route) async {
    final mc = _mapController;
    if (mc == null) return;

    _clearRouteFromMap();
    final animId = ++_routeAnimId;

    // GeoJSON 선로 좌표 로드
    final geojsonRoutes = await SubwayGeoJsonLoader.load();

    // 전체 구간 좌표 미리 계산
    final segmentData = <({List<List<double>> coords, Color color, StationInfo first, StationInfo last})>[];
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final segment in route.segments) {
      if (segment.isTransfer || segment.stations.length < 2) continue;
      final firstStn = SeoulSubwayData.findStation(segment.stations.first);
      final lastStn = SeoulSubwayData.findStation(segment.stations.last);
      if (firstStn == null || lastStn == null) continue;

      final lineCoords = geojsonRoutes[segment.lineId];
      List<List<double>> segCoords;
      if (lineCoords != null && lineCoords.length >= 2) {
        segCoords = _extractSegmentFromRoute(lineCoords, firstStn, lastStn);
      } else {
        segCoords = segment.stations
            .map((n) => SeoulSubwayData.findStation(n))
            .where((s) => s != null)
            .map((s) => [s!.lat, s.lng])
            .toList();
      }
      if (segCoords.length < 2) continue;

      final color = SubwayColors.lineColors[segment.lineId] ?? AppColors.accent;
      segmentData.add((coords: segCoords, color: color, first: firstStn, last: lastStn));

      for (final c in segCoords) {
        if (c[0] < minLat) minLat = c[0];
        if (c[0] > maxLat) maxLat = c[0];
        if (c[1] < minLng) minLng = c[1];
        if (c[1] > maxLng) maxLng = c[1];
      }
    }

    if (segmentData.isEmpty) return;

    // 카메라 이동 (먼저)
    if (minLat < maxLat && minLng < maxLng) {
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      final span = max(maxLat - minLat, maxLng - minLng);
      final zoom = span > 0.3 ? 10.0 : span > 0.15 ? 11.0 : span > 0.08 ? 12.0 : 13.0;
      mc.moveTo(centerLat, centerLng, zoom: zoom, pitch: 30);
    }

    // 출발 마커 (먼저 표시)
    final depInfo = SeoulSubwayData.findStation(route.departure);
    if (depInfo != null) {
      mc.addCircleMarker('route_dep', depInfo.lat, depInfo.lng,
        color: AppColors.success, radius: 12, strokeColor: AppColors.textPrimary, strokeWidth: 4);
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (_routeAnimId != animId) return;

    // 구간별 순차 애니메이션: 폴리라인을 점진적으로 그리기
    for (int s = 0; s < segmentData.length; s++) {
      if (_routeAnimId != animId) return;
      final seg = segmentData[s];

      // 구간 시작 마커
      mc.addCircleMarker('route_mk_${s}_s', seg.first.lat, seg.first.lng,
        color: seg.color, radius: 8, strokeColor: Colors.white, strokeWidth: 3);

      // 폴리라인을 점진적으로 늘리며 그리기
      final totalPoints = seg.coords.length;
      final step = max(1, totalPoints ~/ 8); // 8단계로 나눠서 그리기

      for (int i = step; i <= totalPoints; i += step) {
        if (_routeAnimId != animId) return;
        final partial = seg.coords.sublist(0, min(i, totalPoints));
        if (partial.length >= 2) {
          // 이전 폴리라인 제거 후 더 긴 것으로 교체
          mc.removePolyline('route_seg_$s');
          await mc.addPolyline('route_seg_$s', partial,
            color: seg.color, width: 6.0, opacity: 0.9);
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 마지막에 전체 좌표로 확정
      if (_routeAnimId != animId) return;
      mc.removePolyline('route_seg_$s');
      await mc.addPolyline('route_seg_$s', seg.coords,
        color: seg.color, width: 6.0, opacity: 0.9);

      // 구간 끝 마커
      mc.addCircleMarker('route_mk_${s}_e', seg.last.lat, seg.last.lng,
        color: seg.color, radius: 8, strokeColor: Colors.white, strokeWidth: 3);

      // 구간 사이 짧은 딜레이 (환승 느낌)
      if (s < segmentData.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // 도착 마커 (마지막에 표시)
    if (_routeAnimId != animId) return;
    final arrInfo = SeoulSubwayData.findStation(route.arrival);
    if (arrInfo != null) {
      mc.addCircleMarker('route_arr', arrInfo.lat, arrInfo.lng,
        color: AppColors.danger, radius: 12, strokeColor: AppColors.textPrimary, strokeWidth: 4);
    }
  }

  /// GeoJSON 선로 좌표에서 두 역 사이 구간만 추출
  List<List<double>> _extractSegmentFromRoute(
    List<List<double>> routeCoords,
    StationInfo startStation,
    StationInfo endStation,
  ) {
    // 선로 좌표에서 각 역에 가장 가까운 인덱스 찾기
    int startIdx = _findClosestIndex(routeCoords, startStation.lat, startStation.lng);
    int endIdx = _findClosestIndex(routeCoords, endStation.lat, endStation.lng);

    if (startIdx == endIdx) return [[startStation.lat, startStation.lng], [endStation.lat, endStation.lng]];

    // 방향 보정 (startIdx가 endIdx보다 뒤에 있을 수 있음)
    if (startIdx > endIdx) {
      final temp = startIdx;
      startIdx = endIdx;
      endIdx = temp;
    }

    return routeCoords.sublist(startIdx, endIdx + 1);
  }

  int _findClosestIndex(List<List<double>> coords, double lat, double lng) {
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < coords.length; i++) {
      final dLat = coords[i][0] - lat;
      final dLng = coords[i][1] - lng;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void _clearRouteFromMap() {
    final mc = _mapController;
    if (mc == null) return;
    mc.clearPolylines();
    mc.clearCircleMarkers();
  }

  void _onMapCreated(IMapController controller) {
    _mapController = controller;
    _subwayController.attachMap(controller);
    // 맵 탭 시 키보드 내림
    controller.setOnAnyMapTap(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
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
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: _buildBottomTabBar(),
      body: Stack(
        children: [
          // 지도 엔진 (항상 렌더링)
          Positioned.fill(child: MapboxEngine(initialCamera: _cameraInfo, onMapCreated: _onMapCreated)),

          // 검색바 + 길찾기 + 프로필 (상단, 리퀴드 글라스)
          StationSearchBar(
            onStationSelected: (name) {
              _subwayController.selectStation(name);
            },
            onRouteFound: (route) => _drawRouteOnMap(route),
            onNavModeChanged: (isNav) {
              setState(() => _isNavMode = isNav);
              if (!isNav) _clearRouteFromMap();
            },
            onFocusChanged: (focused) {
              setState(() => _isSearchFocused = focused);
            },
          ),

          // 날씨/시간 위젯 (검색바 아래 좌측, 검색 포커스/길찾기 시 페이드아웃)
          if (_subwayController.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 62,
              left: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                opacity: (_isNavMode || _isSearchFocused) ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isNavMode || _isSearchFocused,
                  child: WeatherTimeWidget(environment: _subwayController.environment),
                ),
              ),
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
                child: ClipRect(
                  child: SizedBox(
                    height: stationPanelMaxHeight,
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
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: AppSpacing.xl, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들 + 닫기
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
            child: Row(
              children: [
                Text('설정', style: AppTypography.titleMd),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: AppSpacing.xl, color: AppColors.textTertiary),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          // 컨텐츠 스크롤
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, MediaQuery.of(context).padding.bottom + 65),
              children: [
                _sectionHeader('지하철'),
                _buildSubwaySection(),
                const SizedBox(height: AppSpacing.lg),
                _sectionHeader('표시'),
                _buildToggleSection(),
                const SizedBox(height: AppSpacing.lg),
                _sectionHeader('노선 필터'),
                _buildLineFilterSection(),
                const SizedBox(height: AppSpacing.lg),
                _sectionHeader('성능'),
                _buildQualitySection(),
                const SizedBox(height: AppSpacing.lg),
                _sectionHeader('라이팅'),
                _buildLightingSection(),
                const SizedBox(height: AppSpacing.lg),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          children: [
            // 전원 + 모드
            Row(
              children: [
                Icon(Icons.train, size: 18, color: isActive ? AppColors.success : Colors.grey),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isActive ? (isDemo ? 'DEMO 실행 중' : 'LIVE 실행 중') : '꺼짐',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.textPrimary : Colors.grey,
                  ),
                ),
                const Spacer(),
                // 모드 전환
                Semantics(
                  label: isDemo ? 'LIVE 모드로 전환' : 'DEMO 모드로 전환',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      ctrl.setMode(isDemo ? SubwayMode.live : SubwayMode.demo);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDemo ? AppColors.warning : AppColors.accent).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isDemo ? AppColors.warning : AppColors.accent,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isDemo ? 'DEMO' : 'LIVE',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDemo ? AppColors.warning : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // 전원 버튼
                AppCircleButton(
                  icon: Icons.power_settings_new,
                  onTap: () {
                    if (isActive) {
                      ctrl.stop();
                    } else {
                      ctrl.start();
                    }
                    setState(() {});
                  },
                  semanticLabel: isActive ? '지하철 끄기' : '지하철 켜기',
                  size: AppSpacing.buttonSm,
                  iconSize: 14,
                  color: isActive ? AppColors.success.withValues(alpha: 0.2) : AppColors.surfaceOverlay,
                  borderColor: isActive ? AppColors.success : Colors.grey,
                ),
              ],
            ),
            // 상태 정보
            if (isActive) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('열차 ${ctrl.currentTrains.length}대',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  if (ctrl.lastUpdate != null)
                    Text(
                      '갱신 ${ctrl.lastUpdate!.hour.toString().padLeft(2, '0')}:${ctrl.lastUpdate!.minute.toString().padLeft(2, '0')}:${ctrl.lastUpdate!.second.toString().padLeft(2, '0')}',
                      style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
            const Divider(height: AppSpacing.md, color: AppColors.divider),
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('표시할 노선 선택', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ctrl.setLineFilter(null);
                    setState(() {});
                  },
                  child: Text('전체', style: AppTypography.caption.copyWith(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: SubwayColors.lineColors.entries.map((entry) {
                final lineId = entry.key;
                final color = entry.value;
                final name = SubwayColors.lineNames[lineId] ?? lineId;
                final isSelected = ctrl.selectedLines == null ||
                    ctrl.selectedLines!.contains(lineId);

                return AppFilterChip(
                  label: name,
                  color: color,
                  isSelected: isSelected,
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
          Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary)),
          Transform.scale(
            scale: 0.7,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.success,
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.surfaceOverlay,
                      width: isSelected ? 1.2 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: isSelected ? AppColors.accent : AppColors.textDisabled),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            )),
                            Text(desc, style: AppTypography.caption.copyWith(
                              color: isSelected ? AppColors.textTertiary : AppColors.textMuted,
                            )),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: AppSpacing.lg, color: AppColors.accent),
                    ],
                  ),
                ),
              );
            }),
            Divider(height: AppSpacing.lg, color: AppColors.surfaceOverlay),
            // 시스템 정보
            Row(
              children: [
                Icon(Icons.memory, size: 14, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '렌더링: ${isAndroid ? "OpenGL ES" : "Metal"} · GeoJSON 캐싱',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('라이트 프리셋', style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: ['auto', 'day', 'night', 'dawn', 'dusk'].map((preset) {
                final isSelected = _lightPreset == preset;
                return ChoiceChip(
                  label: Text(preset.toUpperCase(), style: AppTypography.caption.copyWith(
                    color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
                  )),
                  selected: isSelected,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceOverlay,
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
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      child: Column(
        children: [
          _settingTile(
            icon: Icons.info_outline,
            title: '맵 엔진',
            subtitle: 'Mapbox Maps SDK v11',
          ),
          Divider(height: 1, color: AppColors.divider),
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
      leading: Icon(icon, size: 18, color: AppColors.textTertiary),
      title: Text(title, style: AppTypography.bodySm),
      subtitle: Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.textDisabled)),
      trailing: trailing,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
