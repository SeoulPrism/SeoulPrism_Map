import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../services/seoul_subway_service.dart';
import '../services/train_interpolator.dart';
import '../services/train_simulator.dart';
import '../data/subway_geojson_loader.dart';
import '../data/route_geometry.dart';
import '../core/map_interface.dart';
import '../services/environment_service.dart';
import '../services/settings_service.dart';
import '../services/congestion_service.dart';
import '../services/closure_service.dart';

/// 운행 모드
enum SubwayMode {
  /// API 실시간 + 시간표 보간 (5분 API, 사이는 시간표 추정)
  live,
  /// 데모 모드 — API 호출 없이 시뮬레이션
  demo,
}

/// MiniTokyo3D 스타일 지하철 시각화 오버레이 컨트롤러
/// 실시간 열차 위치 + 노선 경로를 지도 위에 렌더링
class SubwayOverlayController {
  final SeoulSubwayService _apiService = SeoulSubwayService();
  final TrainInterpolator _interpolator = TrainInterpolator();
  final TrainSimulator _simulator = TrainSimulator();
  final RouteGeometry _routeGeometry = RouteGeometry();
  final EnvironmentService _envService = EnvironmentService();

  IMapController? _mapController;
  Timer? _refreshTimer;
  Timer? _animationTimer;
  bool _isActive = false;
  bool _showRoutes;
  bool _showTrains;
  bool _showStations;
  SubwayMode _mode;
  bool autoLighting;

  SubwayOverlayController()
      : _showRoutes = SettingsService.instance.showRoutes,
        _showTrains = SettingsService.instance.showTrains,
        _showStations = SettingsService.instance.showStations,
        _mode = SettingsService.instance.mode == 'live' ? SubwayMode.live : SubwayMode.demo,
        autoLighting = SettingsService.instance.autoLighting {
    // 품질 프리셋 초기 적용
    switch (_qualityPreset) {
      case 'medium': _animIntervalMs = 33; break;
      case 'low': _animIntervalMs = 100; break;
      default: _animIntervalMs = 16; break;
    }
  }

  // 현재 상태
  List<InterpolatedTrainPosition> _currentTrains = [];
  final Map<String, List<ArrivalInfo>> _arrivalCache = {};
  String? _lastError;
  DateTime? _lastUpdate;
  int _totalTrainCount = 0;

  // 애니메이션 상태
  Map<String, _AnimPos3D> _prevPositions = {};
  Map<String, _AnimPos3D> _targetPositions = {};
  double _animProgress = 1.0;
  // 품질 프리셋에 따라 조절되는 값
  int _animIntervalMs = 16; // ~60fps (high), 33ms=30fps (medium), 100ms=10fps (low)
  // Live 모드: 네이버 10초 (메인) + 서울시 600초 (보조, 네이버 미지원 노선만)
  static const int _liveApiFetchSec = 60; // 1분 (1호선/수인분당/신분당 등 7개 노선만)
  static const int _naverApiFetchMs = 100;   // 0.1초 (병렬 요청, 무제한)
  Timer? _naverRefreshTimer;
  bool _isNaverFetching = false; // 겹침 방지 가드
  bool _naverFieldsLogged = false; // API 필드 로그 1회용
  // 데모 모드 보간 주기 (10초)
  static const int _demoIntervalSec = 10;
  int _fetchIntervalSec = 60;
  int get _totalSteps => (_fetchIntervalSec * 1000) ~/ _animIntervalMs;

  /// 현재 품질 프리셋
  String _qualityPreset = SettingsService.instance.qualityPreset;
  String get qualityPreset => _qualityPreset;

  // Live 모드: API 전환 시 부드러운 블렌딩
  // (교정형 시뮬에서는 블렌딩 불필요 — 시뮬레이터가 자체적으로 부드러운 전환)
  bool _layersInitialized3D = false;

  // 선택된 노선 필터 (null이면 전부 표시)
  Set<String>? _selectedLines = SettingsService.instance.selectedLines;

  // 열차 선택 & 카메라 추적
  String? _selectedTrainNo;
  InterpolatedTrainPosition? _selectedTrainData;
  DateTime? _followStartTime; // flyTo 애니메이션 완료 대기용
  static const int _flyToDurationMs = 900; // flyTo 시간 (ms)

  // 역 선택 상태
  String? _selectedStationName;
  StationInfo? _selectedStationInfo;
  List<ArrivalInfo> _selectedStationArrivals = [];
  bool _stationLoading = false;

  // 열차별 지연 상태
  Map<String, int> _trainDelays = {}; // trainNo → delayMinutes
  Timer? _alertTimer;
  static const int _alertFetchIntervalSec = 300; // 5분마다 지연 감지 (API 쿼터 절약)

  // 콜백
  VoidCallback? onStateChanged;
  void Function(String stationName, List<ArrivalInfo> arrivals)? onStationTapped;
  void Function(InterpolatedTrainPosition? train)? onTrainSelected;
  void Function(String? stationName, StationInfo? info, List<ArrivalInfo> arrivals, bool loading)? onStationSelected;

  // Getters
  bool get isActive => _isActive;
  bool get showRoutes => _showRoutes;
  bool get showTrains => _showTrains;
  bool get showStations => _showStations;
  SubwayMode get mode => _mode;
  List<InterpolatedTrainPosition> get currentTrains => _currentTrains;
  String? get lastError => _lastError;
  DateTime? get lastUpdate => _lastUpdate;
  int get totalTrainCount => _totalTrainCount;
  Set<String>? get selectedLines => _selectedLines;
  bool get useSeoulApi => SettingsService.instance.useSeoulApi;
  bool get useNaverApi => SettingsService.instance.useNaverApi;
  int get apiCallCount => _apiService.callCount;
  int get apiRemainingCalls => _apiService.remainingCalls;
  int get fetchIntervalSec => _fetchIntervalSec;
  EnvironmentData? get environment => _envService.current;
  String? get selectedStationName => _selectedStationName;
  StationInfo? get selectedStationInfo => _selectedStationInfo;
  List<ArrivalInfo> get selectedStationArrivals => _selectedStationArrivals;
  bool get stationLoading => _stationLoading;
  String? get selectedTrainNo => _selectedTrainNo;
  InterpolatedTrainPosition? get selectedTrainData => _selectedTrainData;
  Map<String, int> get trainDelays => _trainDelays;
  int get delayedTrainCount => _trainDelays.length;
  bool _showCongestion = false;
  bool get showCongestion => _showCongestion;
  CongestionService get congestionService => CongestionService.instance;

  void attachMap(IMapController controller) {
    _mapController = controller;

    // 열차 탭 콜백 등록
    controller.setOnTrainTapped((trainNo) {
      deselectStation(); // 역 선택 해제
      selectTrain(trainNo);
    });
    // 역 탭 콜백 등록
    controller.setOnStationTapped((stationName) {
      deselectTrain(); // 열차 선택 해제
      selectStation(stationName);
    });
    controller.setOnMapTappedEmpty(() {
      deselectTrain();
      deselectStation();
    });
  }

  /// 열차 선택 (카메라 추적 시작)
  void selectTrain(String trainNo) {
    // 다른 열차로 전환 시 flyTo 재실행을 위해 리셋
    _mapController?.setSelectedTrain(null); // _isFollowing = false
    _selectedTrainNo = trainNo;
    _followStartTime = DateTime.now(); // flyTo 완료까지 프레임 추적 차단
    _mapController?.setSelectedTrain(trainNo);
    // 현재 열차 목록에서 해당 열차 찾기
    _selectedTrainData = _findTrain(trainNo);
    if (_selectedTrainData != null) {
      _mapController?.followTrain(
        _selectedTrainData!.lat,
        _selectedTrainData!.lng,
        _selectedTrainData!.bearing,
      );
    }
    onTrainSelected?.call(_selectedTrainData);
    onStateChanged?.call();
  }

  /// 열차 선택 해제
  void deselectTrain() {
    _selectedTrainNo = null;
    _selectedTrainData = null;
    _followStartTime = null;
    _mapController?.setSelectedTrain(null);
    onTrainSelected?.call(null);
    onStateChanged?.call();
  }

  /// 역 선택 (도착정보 조회 + 카메라 이동)
  Future<void> selectStation(String stationName) async {
    _selectedStationName = stationName;
    _selectedStationInfo = SeoulSubwayData.findStation(stationName);
    _selectedStationArrivals = [];
    _stationLoading = true;

    // 카메라를 역으로 이동 — OSM 스냅 좌표 우선 (지도 위 점과 동일 위치)
    double? lat, lng;
    // RouteGeometry에서 스냅 좌표 찾기 (모든 노선에서)
    for (final lineId in SeoulSubwayData.lineIdToApiName.keys) {
      final snapped = _routeGeometry.getStationPosition(lineId, stationName);
      if (snapped != null) {
        lat = snapped[0];
        lng = snapped[1];
        break;
      }
    }
    // 스냅 좌표 없으면 StationInfo 좌표 폴백
    lat ??= _selectedStationInfo?.lat;
    lng ??= _selectedStationInfo?.lng;

    if (lat != null && lng != null) {
      _mapController?.moveTo(lat, lng, zoom: 15.5, pitch: 50);
    }

    // 역 하이라이트 효과
    _mapController?.setSelectedStation(stationName);

    onStationSelected?.call(stationName, _selectedStationInfo, [], true);
    onStateChanged?.call();

    // 도착정보 fetch
    final arrivals = await getStationArrivals(stationName);
    if (_selectedStationName == stationName) {
      _selectedStationArrivals = arrivals;
      _stationLoading = false;
      onStationSelected?.call(stationName, _selectedStationInfo, arrivals, false);
      onStateChanged?.call();
    }
  }

  /// 역 선택 해제
  void deselectStation() {
    if (_selectedStationName == null) return;
    _selectedStationName = null;
    _selectedStationInfo = null;
    _selectedStationArrivals = [];
    _stationLoading = false;
    _mapController?.setSelectedStation(null);
    onStationSelected?.call(null, null, [], false);
    onStateChanged?.call();
  }

  /// 열차 번호로 현재 목록에서 검색
  InterpolatedTrainPosition? _findTrain(String trainNo) {
    for (final train in _currentTrains) {
      if (train.trainNo == trainNo) return train;
    }
    return null;
  }

  /// 모드 변경 (활성 상태면 재시작)
  void setMode(SubwayMode newMode) {
    if (_mode == newMode) return;
    final wasActive = _isActive;
    if (wasActive) stop();
    _mode = newMode;
    SettingsService.instance.setMode(newMode == SubwayMode.live ? 'live' : 'demo');
    if (wasActive) start();
    onStateChanged?.call();
  }

  /// 시각화 시작
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    _lastError = null;
    onStateChanged?.call();

    // 시설 폐쇄 정보 로드 (비동기, 실패해도 무시)
    ClosureService.instance.fetch();

    // OSM 노선 경로 초기화
    try {
      if (!_routeGeometry.isInitialized) {
        await _routeGeometry.init();
        _interpolator.setRouteGeometry(_routeGeometry);
        _simulator.setRouteGeometry(_routeGeometry);
        _simulator.onTrainArrivedAtStation = () {
          // 역 도착 시 네이버 API 추가 호출 (정확도 보정)
          _fetchNaverApi();
        };
      }
    } catch (e) {
      debugPrint('[SubwayOverlay] ⚠️ RouteGeometry 초기화 실패 (직선 폴백): $e');
    }

    // 3D 레이어 초기화
    try {
      if (!_layersInitialized3D) {
        await _mapController?.init3DLayers();
        _layersInitialized3D = true;
      }
    } catch (e) {
      debugPrint('[SubwayOverlay] ⚠️ 3D 레이어 초기화 실패: $e');
    }

    // 초기 노선 + 역 그리기
    if (_showRoutes) {
      await _drawSubwayRoutes();
    }
    if (_showStations) {
      await _drawStationMarkers();
    }

    if (_mode == SubwayMode.demo) {
      // 데모 모드: 초기 스냅샷 1회 → 이후 getFramePositions()가 무한 전진
      _simulator.initDemoTrains();
      _fetchIntervalSec = _demoIntervalSec;
      _updateFromSimulatorContinuous();
      // 타이머 없음 — 연속 보간이 자체적으로 구간 전환 처리
      debugPrint('[SubwayOverlay] 🎮 데모 모드 시작 (60fps 연속 보간)');
    } else {
      _fetchIntervalSec = _liveApiFetchSec;
      // 서울시 공식 API — 항상 초기 1회 호출 (1호선 등 네이버 미지원 노선용)
      await _fetchAndRender();
      if (useSeoulApi) {
        _refreshTimer = Timer.periodic(
          const Duration(seconds: _liveApiFetchSec), (_) => _fetchAndRender(),
        );
      }
      // 네이버 비공식 API (설정에 따라)
      if (useNaverApi) {
        _fetchNaverApi();
        _naverRefreshTimer = Timer.periodic(
          const Duration(milliseconds: _naverApiFetchMs), (_) => _fetchNaverApi(),
        );
      }
      debugPrint('[SubwayOverlay] 📡 Live 모드 시작 '
          '(서울API:${useSeoulApi ? "${_liveApiFetchSec}s" : "OFF"} '
          '네이버:${useNaverApi ? "${_naverApiFetchMs}ms" : "OFF"})');
    }

    // 애니메이션 타이머 (~60fps)
    _animationTimer = Timer.periodic(
      Duration(milliseconds: _animIntervalMs),
      (_) => _animationTick(),
    );

    // 환경 서비스 (시간/날씨) 시작
    _envService.onUpdated = () {
      _applyEnvironment();
      onStateChanged?.call();
    };
    _envService.start();

    // 알림정보 (지연 방어막) 시작
    _fetchAlerts();
    _alertTimer = Timer.periodic(
      const Duration(seconds: _alertFetchIntervalSec),
      (_) => _fetchAlerts(),
    );
  }

  /// 환경(시간/날씨) 효과 맵에 적용
  void _applyEnvironment() {
    final env = _envService.current;
    if (env == null || _mapController == null) return;
    if (!autoLighting) return; // 수동 오버라이드 중

    double fogOpacity = 0.0;
    if (env.weather == WeatherCondition.fog) {
      fogOpacity = 0.6;
    } else if (env.weather == WeatherCondition.rain || env.weather == WeatherCondition.drizzle) {
      fogOpacity = 0.3;
    } else if (env.weather == WeatherCondition.snow) {
      fogOpacity = 0.25;
    } else if (env.weather == WeatherCondition.thunderstorm) {
      fogOpacity = 0.4;
    } else if (env.visibility < 5) {
      fogOpacity = (1.0 - env.visibility / 5.0) * 0.5;
    }

    _mapController!.applyWeatherEffect(
      lightPreset: env.lightPreset,
      fogOpacity: fogOpacity,
    );

    debugPrint('[SubwayOverlay] 🌤️ 환경 적용: ${env.lightPreset} | '
        '${env.weatherDescription} ${env.temperature.toStringAsFixed(1)}°C');
  }

  /// 열차별 지연 감지 + 맵 렌더링 업데이트
  Future<void> _fetchAlerts() async {
    try {
      _trainDelays = await _apiService.fetchTrainDelays();
      if (_trainDelays.isNotEmpty) {
        debugPrint('[SubwayOverlay] ⚠️ 지연 열차 ${_trainDelays.length}대');
      }
      onStateChanged?.call();
    } catch (e) {
      debugPrint('[SubwayOverlay] 지연 감지 실패 (무시): $e');
    }
  }

  /// 시각화 중지
  void stop() {
    _isActive = false;
    _envService.stop();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _naverRefreshTimer?.cancel();
    _naverRefreshTimer = null;
    _animationTimer?.cancel();
    _animationTimer = null;
    _alertTimer?.cancel();
    _alertTimer = null;
    _trainDelays.clear();
    _prevPositions.clear();
    _targetPositions.clear();
    _clearAllOverlays();
    onStateChanged?.call();
  }

  /// 노선 필터 설정
  void setLineFilter(Set<String>? lines) {
    _selectedLines = lines;
    SettingsService.instance.setSelectedLines(lines);
    if (_isActive) {
      _renderAnimatedTrains();
      if (_showRoutes) _drawSubwayRoutes();
    }
    onStateChanged?.call();
  }

  /// 노선 경로 표시 토글
  void toggleRoutes(bool show) {
    _showRoutes = show;
    SettingsService.instance.setShowRoutes(show);
    if (_isActive) {
      if (show) {
        _drawSubwayRoutes();
      } else {
        // 빈 데이터로 경로 클리어
        _mapController?.initRoutes3D({}, {}, {});
      }
    }
    onStateChanged?.call();
  }

  /// 열차 표시 토글
  void toggleTrains(bool show) {
    _showTrains = show;
    SettingsService.instance.setShowTrains(show);
    if (_isActive) {
      if (show) {
        _renderAnimatedTrains();
      } else {
        _mapController?.updateTrainPositions3D([]);
      }
    }
    onStateChanged?.call();
  }

  /// 역 표시 토글
  void toggleStations(bool show) {
    _showStations = show;
    SettingsService.instance.setShowStations(show);
    if (_isActive) {
      if (show) {
        _drawStationMarkers();
      } else {
        _mapController?.updateStations3D([], []);
      }
    }
    onStateChanged?.call();
  }

  /// API 소스 토글
  void setUseSeoulApi(bool v) {
    SettingsService.instance.setUseSeoulApi(v);
    if (_isActive && _mode == SubwayMode.live) {
      _refreshTimer?.cancel();
      if (v) {
        _refreshTimer = Timer.periodic(
          const Duration(seconds: _liveApiFetchSec), (_) => _fetchAndRender(),
        );
      } else {
        _refreshTimer = null;
      }
    }
    onStateChanged?.call();
  }

  /// 혼잡도 토글
  void setCongestionVisible(bool v) {
    _showCongestion = v;
    _mapController?.setCongestionVisible(v);
    if (v && !CongestionService.instance.isLoaded) {
      _loadCongestionData();
    }
    onStateChanged?.call();
  }

  Future<void> _loadCongestionData() async {
    final service = CongestionService.instance;
    final success = await service.fetch();
    if (!success || _mapController == null) return;

    // 역 좌표 매핑 — 전 노선 역 목록에서 검색
    final points = <Map<String, dynamic>>[];
    final allStations = SeoulSubwayData.allLines.expand((l) => l).toList();
    // 역명 → 좌표 맵 (중복 역명은 첫 번째 것 사용)
    final stationCoords = <String, StationInfo>{};
    for (final s in allStations) {
      stationCoords.putIfAbsent(s.name, () => s);
    }

    for (final entry in service.data.entries) {
      final name = entry.key;
      final congestion = entry.value;

      // 역 좌표 찾기 (정확 매칭 → 부분 매칭)
      var station = stationCoords[name];
      if (station == null) {
        // 괄호 제거 매칭: "잠실(송파구청)" → "잠실"
        final cleanName = name.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        station = stationCoords[cleanName];
      }
      if (station == null) continue;

      final weight = service.getCrowding(name);
      final total = congestion.total;
      final label = '${(total / 1000).toStringAsFixed(0)}k';

      points.add({
        'lat': station.lat,
        'lng': station.lng,
        'weight': weight,
        'label': label,
      });
    }

    await _mapController!.updateCongestionHeatmap(points);
    if (_showCongestion) {
      _mapController!.setCongestionVisible(true);
    }
    debugPrint('[SubwayOverlay] 🔥 혼잡도 데이터 로드: ${points.length}개 역');
    onStateChanged?.call();
  }

  void setUseNaverApi(bool v) {
    SettingsService.instance.setUseNaverApi(v);
    if (_isActive && _mode == SubwayMode.live) {
      _naverRefreshTimer?.cancel();
      if (v) {
        _naverRefreshTimer = Timer.periodic(
          const Duration(milliseconds: _naverApiFetchMs), (_) => _fetchNaverApi(),
        );
        _fetchNaverApi(); // 즉시 1회 호출
      } else {
        _naverRefreshTimer = null;
      }
    }
    onStateChanged?.call();
  }

  /// 품질 프리셋 적용
  /// high: 60fps, medium: 30fps, low: 10fps
  void setQualityPreset(String preset) {
    _qualityPreset = preset;
    SettingsService.instance.setQualityPreset(preset);
    switch (preset) {
      case 'high':
        _animIntervalMs = 16; // ~60fps
        break;
      case 'medium':
        _animIntervalMs = 33; // ~30fps
        break;
      case 'low':
        _animIntervalMs = 100; // ~10fps
        break;
    }
    // 실행 중이면 애니메이션 타이머 재시작
    if (_isActive && _animationTimer != null) {
      _animationTimer?.cancel();
      _animationTimer = Timer.periodic(
        Duration(milliseconds: _animIntervalMs),
        (_) => _animationTick(),
      );
    }
    onStateChanged?.call();
  }

  /// 특정 역의 도착 정보 조회
  Future<List<ArrivalInfo>> getStationArrivals(String stationName) async {
    try {
      final arrivals = await _apiService.fetchStationArrivals(stationName);
      _arrivalCache[stationName] = arrivals;
      return arrivals;
    } catch (e) {
      return _arrivalCache[stationName] ?? [];
    }
  }

  /// 예산에 따라 갱신 주기를 자동 조절하고 타이머 재시작
  void _adjustInterval() {
    final recommended = _apiService.recommendedIntervalSec;
    if (recommended == 0) {
      debugPrint('[SubwayOverlay] 🚫 API 한도 소진 — 자동 중지');
      _lastError = '일일 API 한도 소진 (${SeoulSubwayService.dailyLimit}건)';
      stop();
      return;
    }
    if (recommended != _fetchIntervalSec) {
      debugPrint('[SubwayOverlay] ⏱️ 갱신 주기 변경: ${_fetchIntervalSec}s → ${recommended}s '
          '(남은 호출: ${_apiService.remainingCalls})');
      _fetchIntervalSec = recommended;
      // 타이머 재시작
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        Duration(seconds: _fetchIntervalSec),
        (_) => _fetchAndRender(),
      );
    }
  }

  /// 선택된 노선의 API 이름 목록 반환
  List<String>? _getSelectedLineApiNames() {
    if (_selectedLines == null) return null; // 전체
    return _selectedLines!
        .map((id) => SeoulSubwayData.lineIdToApiName[id])
        .whereType<String>()
        .toList();
  }

  /// 시뮬레이터에서 데이터 가져와 연속 보간 준비 (데모 모드)
  /// Live 모드와 동일하게 OSM 경로를 따라 매 프레임 위치 계산
  void _updateFromSimulatorContinuous() {
    if (!_isActive) return;
    final positions = _simulator.generateDemoPositions();
    debugPrint('[SubwayOverlay] 🎮 데모 생성: ${positions.length}개');

    // 연속 보간 시스템에 스냅샷으로 등록 (Live 모드와 동일한 경로)
    _simulator.updateApiSnapshot(positions);
    _simulator.prepareContinuousExtrapolation();

    _totalTrainCount = positions.length;
    _lastUpdate = DateTime.now();
    _lastError = null;
    debugPrint('[SubwayOverlay] 🎮 데모 연속 보간 준비: ${positions.length}개');
    onStateChanged?.call();
  }

  /// 네이버 지도 API로 전 노선 실시간 위치 fetch (30초마다)
  /// 비공식 API, 제한 없음, 공식 API 사이 보조용
  Future<void> _fetchNaverApi() async {
    if (!_isActive || _mode != SubwayMode.live || !useNaverApi) return;
    if (_isNaverFetching) return; // 이전 요청 진행중이면 스킵
    _isNaverFetching = true;

    try {
      final trains = await _fetchNaverTrainPositions();
      if (trains.isEmpty) return;

      // 네이버 열차 → 기존 서울API 열차와 merge
      // 네이버 trainNo는 'N' prefix → 서울API와 충돌 없음
      // 서울API 열차(1호선/공항철도/GTX-A)는 유지, 네이버 열차는 최신으로 교체
      final seoulOnlyTrains = _simulator.lastApiSnapshot
          .where((t) => !t.trainNo.startsWith('N'))
          .toList();
      final merged = [...seoulOnlyTrains, ...trains];

      _simulator.updateApiSnapshot(merged);
      _simulator.prepareContinuousExtrapolation();
    } catch (e) {
      debugPrint('[SubwayOverlay] 네이버 API 실패: $e');
    } finally {
      _isNaverFetching = false;
    }
  }

  /// 네이버 지도 API에서 전 노선 열차 위치 가져오기
  /// 네이버 역명 정리: 끝의 '역'만 제거 (역삼, 역촌 등은 보존)
  static String _cleanStationName(String raw) {
    if (raw.endsWith('역') && raw.length > 1) {
      return raw.substring(0, raw.length - 1);
    }
    return raw;
  }

  /// 네이버 시간 문자열 (YYYYMMDDHHmmss) → epoch ms
  static int _parseNaverTime(String? timeStr) {
    if (timeStr == null || timeStr.length != 14) return 0;
    try {
      final dt = DateTime.parse(
        '${timeStr.substring(0, 4)}-${timeStr.substring(4, 6)}-${timeStr.substring(6, 8)}'
        'T${timeStr.substring(8, 10)}:${timeStr.substring(10, 12)}:${timeStr.substring(12, 14)}',
      );
      return dt.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  // 네이버 routeId → 서울시 API subwayId 매핑 (2025-04 재확인)
  static const Map<String, String> _naverRouteIds = {
    '2': '1002', '3': '1003', '4': '1004', '5': '1005',
    '6': '1006', '7': '1007', '8': '1008', '9': '1009',
    '101': '1063', // 경의중앙선
    '104': '1067', // 경춘선
    '109': '1077', // 신분당선
    '112': '1081', // 경강선
    '113': '1092', // 우이신설선
    '114': '1093', // 서해선
    '116': '1075', // 수인분당선
    '117': '1094', // 신림선
    // 1호선(200+): 복잡한 계통 분리 → 서울시 API로
    // 공항철도, GTX-A: 네이버 미지원 → 서울시 API로
  };

  Future<List<TrainPosition>> _fetchNaverTrainPositions() async {
    // 전 노선 병렬 요청 (순차 32개 → 병렬)
    final futures = <Future<List<TrainPosition>>>[];

    for (final entry in _naverRouteIds.entries) {
      for (final dir in [0, 1]) {
        futures.add(_fetchNaverSingleRoute(entry.key, entry.value, dir));
      }
    }

    final allResults = await Future.wait(futures);
    return allResults.expand((list) => list).toList();
  }

  Future<List<TrainPosition>> _fetchNaverSingleRoute(String routeId, String subwayId, int dir) async {
    final results = <TrainPosition>[];
    try {
      final url = Uri.parse(
        'https://pts.map.naver.com/end-subway/api/realtime/location/subway/integrated'
        '?direction=$dir&routeId=$routeId&caller=pc_web&lang=ko',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      }).timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // 디버그: 첫 요청의 첫 열차 필드 전체 출력 (1회만)
        if (data.isNotEmpty && routeId == '2' && dir == 0 && !_naverFieldsLogged) {
          _naverFieldsLogged = true;
          debugPrint('[NaverAPI] 샘플 응답 필드: ${data[0].keys.toList()}');
          debugPrint('[NaverAPI] 샘플 데이터: ${data[0]}');
        }
        for (final item in data) {
          if (item['operatingStatus'] == 'END') continue;
          final trainNos = item['trainNo'] as List? ?? [];
          final trainNo = trainNos.isNotEmpty
              ? (trainNos[0]['trainNo']?.toString() ?? '') : '';
          if (trainNo.isEmpty) continue;

          final statusCd = int.tryParse(item['statusCd']?.toString() ?? '0') ?? 0;
          final trainStatus = statusCd == 0 ? 0 : (statusCd == 1 ? 1 : 2);

          // 시간 파싱: prevStopDepartureTime, eventTime (YYYYMMDDHHmmss)
          final prevDepMs = _parseNaverTime(item['prevStopDepartureTime']?.toString());
          final eventMs = _parseNaverTime(item['eventTime']?.toString());

          results.add(TrainPosition(
            subwayId: subwayId,
            subwayName: SubwayColors.lineNames[subwayId] ?? '',
            stationId: item['stationId']?.toString() ?? '',
            stationName: _cleanStationName(item['stationName']?.toString() ?? ''),
            trainNo: 'N$trainNo',
                lastRecvDate: '',
                recvTime: '',
                direction: dir,
                terminalId: '',
                terminalName: item['heading']?.toString() ?? '',
                trainStatus: trainStatus,
                expressType: 0,
                isLastTrain: false,
                prevDepartureMs: prevDepMs,
                eventTimeMs: eventMs,
              ));
            }
          }
    } catch (_) {}
    return results;
  }

  /// API에서 데이터 fetch (Live 모드, 전체 노선)
  // 네이버 API가 커버하지 않는 노선 (서울시 공식 API로만 조회)
  // 네이버에서 커버 안 되는 노선만 서울시 API로
  static const List<String> _seoulApiOnlyLines = [
    '1호선', '공항철도', 'GTX-A',
  ];

  /// 서울시 공식 API fetch (네이버 미지원 노선만, 10분마다)
  Future<void> _fetchAndRender() async {
    _adjustInterval();
    if (!_isActive) return;

    try {
      // 네이버가 커버 못하는 노선만 서울시 API로 호출 (API 절약)
      final allPositions = await _apiService.fetchAllTrainPositions(
        lineNames: _seoulApiOnlyLines,
      );

      final allTrains = <TrainPosition>[];
      for (final positions in allPositions.values) {
        allTrains.addAll(positions);
      }

      // API가 빈 결과면 기존 시뮬 유지
      if (allTrains.isEmpty && _currentTrains.isNotEmpty) {
        debugPrint('[SubwayOverlay] ⚠️ API 빈 응답 — 기존 시뮬 유지');
        _lastError = 'API 빈 응답 (기존 열차 유지중)';
        return;
      }

      debugPrint('[SubwayOverlay] 📡 서울시 API: ${allTrains.length}대 (${_seoulApiOnlyLines.join(", ")})');

      // 교정형 시뮬레이션: API 데이터로 속도 교정 (위치 리셋 아님)
      _simulator.updateApiSnapshot(allTrains);
      _simulator.prepareContinuousExtrapolation();

      _totalTrainCount = allTrains.length;
      _lastUpdate = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SubwayOverlay] 🚨 fetch 실패: $e');
    }
    if (_lastError == null && _apiService.lastApiError != null) {
      _lastError = _apiService.lastApiError;
    }
    debugPrint('[SubwayOverlay] 📍 열차 $_totalTrainCount개 | 에러: ${_lastError ?? '없음'}');
    onStateChanged?.call();
  }

  /// 열차 위치 데이터를 보간 + 애니메이션 타겟에 적용
  void _applyTrainPositions(List<TrainPosition> allTrains) {
    _totalTrainCount = allTrains.length;
    _currentTrains = _interpolator.interpolateAll(allTrains);

    _prevPositions = Map.from(_targetPositions);
    _targetPositions = {};
    for (final train in _currentTrains) {
      _targetPositions[train.trainNo] = _AnimPos3D(
        train.lat, train.lng, train.altitude, train.isUnderground,
      );
      _prevPositions.putIfAbsent(
        train.trainNo,
        () => _AnimPos3D(train.lat, train.lng, train.altitude, train.isUnderground),
      );
    }

    _animProgress = 0.0;
    if (_showTrains) {
      _renderAnimatedTrains();
    }
  }

  /// 애니메이션 틱: 매 프레임 경로 추종 위치 계산 (데모/Live 공통)
  void _animationTick() {
    if (!_isActive || !_showTrains) return;
    // 데모/Live 모두 OSM 경로 기반 연속 보간 사용
    _renderLiveContinuous();
  }

  /// Live 모드: 매 프레임 시간표 기반 연속 위치 렌더링 (60fps)
  void _renderLiveContinuous() {
    if (_mapController == null || !_simulator.hasContinuousData) return;

    // 교정형 시뮬레이션: 매 프레임 물리 전진 (블렌딩 불필요)
    final framePositions = _simulator.getFramePositions();
    if (framePositions.isEmpty) return;

    final filtered = <InterpolatedTrainPosition>[];
    for (final train in framePositions) {
      if (_selectedLines != null && !_selectedLines!.contains(train.subwayId)) {
        continue;
      }
      filtered.add(train);
    }

    _currentTrains = filtered;
    _totalTrainCount = filtered.length;
    _mapController!.updateTrainPositions3D(filtered, trainDelays: _trainDelays);

    // 선택된 열차 카메라 추적
    if (_selectedTrainNo != null) {
      final tracked = _findTrain(_selectedTrainNo!);
      if (tracked != null) {
        // flyTo 애니메이션 완료 전까지는 easeTo 호출 차단
        final flyToElapsed = _followStartTime != null
            ? DateTime.now().difference(_followStartTime!).inMilliseconds
            : _flyToDurationMs + 1;
        if (flyToElapsed > _flyToDurationMs) {
          _mapController!.followTrain(tracked.lat, tracked.lng, tracked.bearing);
        }

        // 역 정보가 바뀔 때만 UI 갱신 (매 프레임 setState 방지)
        if (_selectedTrainData?.stationName != tracked.stationName ||
            _selectedTrainData?.trainStatus != tracked.trainStatus) {
          _selectedTrainData = tracked;
          onTrainSelected?.call(tracked);
        }
        _selectedTrainData = tracked;
      }
    }
  }

  /// 현재 애니메이션 진행도에 따라 열차 렌더링 (3D) — 데모 모드용
  void _renderAnimatedTrains() {
    if (_mapController == null) return;

    final t = _easeInOut(_animProgress.clamp(0.0, 1.0));
    final interpolated = <InterpolatedTrainPosition>[];

    for (final train in _currentTrains) {
      if (_selectedLines != null && !_selectedLines!.contains(train.subwayId)) {
        continue;
      }

      final prev = _prevPositions[train.trainNo];
      final target = _targetPositions[train.trainNo];
      if (target == null) continue;

      final lat = prev != null ? _lerp(prev.lat, target.lat, t) : target.lat;
      final lng = prev != null ? _lerp(prev.lng, target.lng, t) : target.lng;

      // 실제 이동 방향으로 bearing 계산 (prev→현재)
      double bearing = train.bearing;
      if (prev != null) {
        final dLat = target.lat - prev.lat;
        final dLng = target.lng - prev.lng;
        if (dLat.abs() > 1e-7 || dLng.abs() > 1e-7) {
          bearing = _bearingFromDelta(dLat, dLng);
        }
      }

      interpolated.add(InterpolatedTrainPosition(
        trainNo: train.trainNo,
        subwayId: train.subwayId,
        subwayName: train.subwayName,
        lat: lat,
        lng: lng,
        altitude: 0, // 전부 바닥
        isUnderground: train.isUnderground,
        direction: train.direction,
        terminalName: train.terminalName,
        stationName: train.stationName,
        trainStatus: train.trainStatus,
        expressType: train.expressType,
        isLastTrain: train.isLastTrain,
        bearing: bearing,
      ));
    }

    _mapController!.updateTrainPositions3D(interpolated, trainDelays: _trainDelays);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// ease-in-out 곡선 (부드러운 출발/도착)
  double _easeInOut(double t) => t * t * (3.0 - 2.0 * t);

  /// 좌표 차이로 bearing 계산 (degrees, North=0, clockwise)
  double _bearingFromDelta(double dLat, double dLng) {
    final rad = atan2(dLng, dLat);
    return (rad * 180.0 / pi + 360) % 360;
  }

  /// 지하철 노선 경로를 3D로 그리기 (OSM GeoJSON 실제 선로 geometry 사용)
  Future<void> _drawSubwayRoutes() async {
    if (_mapController == null) return;

    final routeCoords = <String, List<List<double>>>{};
    final lineColors = <String, Color>{};
    final segmentUnderground = <String, List<bool>>{};

    // OSM GeoJSON에서 실제 선로 geometry 로드
    final geojsonRoutes = await SubwayGeoJsonLoader.load();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      if (_selectedLines != null && !_selectedLines!.contains(lineId)) continue;

      final stations = SeoulSubwayData.getLineStations(lineId);
      final color = SubwayColors.getColor(lineId);

      // GeoJSON 메인 경로가 있으면 사용, 없으면 역 직선 폴백
      final geojsonCoords = geojsonRoutes[lineId];
      if (geojsonCoords != null && geojsonCoords.length >= 2) {
        routeCoords[lineId] = geojsonCoords;
        lineColors[lineId] = color;
        // 각 좌표점의 지하/지상 여부: 가장 가까운 역 기준으로 판별
        segmentUnderground[lineId] = geojsonCoords.map((coord) {
          final nearestStation = _findNearestStation(stations, coord[0], coord[1]);
          return nearestStation != null
              ? !SeoulSubwayData.isSurfaceStation(nearestStation.id)
              : true; // 기본: 지하
        }).toList();
      } else if (stations.length >= 2) {
        // GeoJSON 없는 노선: 기존 직선 폴백
        routeCoords[lineId] = stations.map((s) => [s.lat, s.lng]).toList();
        lineColors[lineId] = color;
        segmentUnderground[lineId] = stations
            .map((s) => !SeoulSubwayData.isSurfaceStation(s.id))
            .toList();
      }

      // 지선도 추가 (gyeongin, seongsu, sinjeong, macheon 등)
      for (final entry in geojsonRoutes.entries) {
        if (entry.key.startsWith('${lineId}_') && entry.value.length >= 2) {
          routeCoords[entry.key] = entry.value;
          lineColors[entry.key] = color;
          // 지선 전용 역 데이터가 있으면 그것으로 지상/지하 판별
          final branchStations = SeoulSubwayData.getBranchStations(entry.key);
          final stationsForClassify = branchStations.isNotEmpty ? branchStations : stations;
          segmentUnderground[entry.key] = entry.value.map((coord) {
            final nearestStation = _findNearestStation(stationsForClassify, coord[0], coord[1]);
            return nearestStation != null
                ? !SeoulSubwayData.isSurfaceStation(nearestStation.id)
                : true;
          }).toList();
        }
      }
    }

    await _mapController!.initRoutes3D(routeCoords, lineColors, segmentUnderground);
  }

  /// 좌표에서 가장 가까운 역 찾기
  StationInfo? _findNearestStation(List<StationInfo> stations, double lat, double lng) {
    if (stations.isEmpty) return null;
    StationInfo? nearest;
    double minDist = double.infinity;
    for (final s in stations) {
      final d = (s.lat - lat) * (s.lat - lat) + (s.lng - lng) * (s.lng - lng);
      if (d < minDist) {
        minDist = d;
        nearest = s;
      }
    }
    return nearest;
  }

  /// 역 마커를 MiniTokyo3D 스타일 필(pill)/캡슐로 그리기
  /// 환승역: 노선 수만큼 컬러 도트가 나열된 캡슐 모양
  /// 일반역: 단일 컬러 도트 (원형)
  Future<void> _drawStationMarkers() async {
    if (_mapController == null) return;

    // ── 1단계: 역별 경유 노선 ID 목록 + 좌표 + 베어링 집계 ──
    final stationLineIds = <String, List<String>>{}; // name → [lineId, ...]
    final stationCoord = <String, List<double>>{};   // name → [lat, lng]
    final stationBearing = <String, double>{};       // name → degrees

    void collectStations(List<StationInfo> stations, String lineId, String routeKey) {
      for (int i = 0; i < stations.length; i++) {
        final s = stations[i];
        stationLineIds.putIfAbsent(s.name, () => []);
        if (!stationLineIds[s.name]!.contains(lineId)) {
          stationLineIds[s.name]!.add(lineId);
        }
        if (!stationCoord.containsKey(s.name)) {
          final snapped = _routeGeometry.getStationPosition(routeKey, s.name);
          stationCoord[s.name] = [snapped?[0] ?? s.lat, snapped?[1] ?? s.lng];
          // 인접역으로 베어링 계산 (캡슐 방향 결정)
          if (stations.length >= 2) {
            final pi = i > 0 ? i - 1 : i;
            final ni = i < stations.length - 1 ? i + 1 : i;
            final dLng = (stations[ni].lng - stations[pi].lng) * 3.14159 / 180;
            final y = sin(dLng) * cos(stations[ni].lat * 3.14159 / 180);
            final x = cos(stations[pi].lat * 3.14159 / 180) *
                    sin(stations[ni].lat * 3.14159 / 180) -
                sin(stations[pi].lat * 3.14159 / 180) *
                    cos(stations[ni].lat * 3.14159 / 180) * cos(dLng);
            stationBearing[s.name] = (atan2(y, x) * 180 / 3.14159 + 360) % 360;
          }
        }
      }
    }

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      if (_selectedLines != null && !_selectedLines!.contains(lineId)) continue;
      collectStations(SeoulSubwayData.getLineStations(lineId), lineId, lineId);
    }
    for (final branchEntry in SeoulSubwayData.branchToLineId.entries) {
      final parentLineId = branchEntry.value;
      if (_selectedLines != null && !_selectedLines!.contains(parentLineId)) continue;
      collectStations(
        SeoulSubwayData.getBranchStations(branchEntry.key),
        parentLineId, branchEntry.key,
      );
    }

    // ── 2단계: 캡슐(pill) + 도트(dot) 데이터 생성 ──
    const slotMeters = 40.0; // 도트 간격 (미터)
    const degPerMeterLat = 1.0 / 111320.0;
    final degPerMeterLng = 1.0 / (111320.0 * cos(37.55 * 3.14159 / 180));

    final pills = <Map<String, dynamic>>[];
    final dots = <Map<String, dynamic>>[];

    for (final name in stationCoord.keys) {
      final coord = stationCoord[name]!;
      final lines = stationLineIds[name] ?? [];
      final n = lines.length;
      final bearing = stationBearing[name] ?? 0.0;

      // 캡슐 연장 방향 = 노선 진행 방향의 수직
      final perpRad = (bearing + 90) * 3.14159 / 180;
      final dLat = slotMeters * cos(perpRad) * degPerMeterLat;
      final dLng = slotMeters * sin(perpRad) * degPerMeterLng;

      final half = (n - 1) / 2.0;

      // 캡슐 배경 (LineString 양 끝점)
      pills.add({
        'name': name,
        'lineCount': n,
        'startLat': coord[0] - half * dLat,
        'startLng': coord[1] - half * dLng,
        'endLat': coord[0] + half * dLat,
        'endLng': coord[1] + half * dLng,
      });

      // 노선별 컬러 도트
      for (int i = 0; i < n; i++) {
        final offset = i - half;
        final color = SubwayColors.getColor(lines[i]);
        dots.add({
          'lat': coord[0] + offset * dLat,
          'lng': coord[1] + offset * dLng,
          'name': name,
          'color': 'rgba(${(color.r * 255).round()},${(color.g * 255).round()},${(color.b * 255).round()},1)',
        });
      }
    }

    await _mapController!.updateStations3D(pills, dots);
  }

  /// 모든 오버레이 제거
  void _clearAllOverlays() {
    _mapController?.cleanup3DLayers();
    _layersInitialized3D = false;
  }

  void dispose() {
    stop();
    _alertTimer?.cancel();
    _envService.dispose();
  }
}

/// 애니메이션용 3D 위치 데이터
class _AnimPos3D {
  final double lat;
  final double lng;
  final double altitude;
  final bool isUnderground;
  const _AnimPos3D(this.lat, this.lng, this.altitude, this.isUnderground);
}
