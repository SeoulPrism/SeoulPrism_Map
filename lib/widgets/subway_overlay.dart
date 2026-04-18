import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../services/seoul_subway_service.dart';
import '../services/train_interpolator.dart';
import '../services/train_simulator.dart';
import '../data/subway_geojson_loader.dart';
import '../data/route_geometry.dart';
import '../core/map_interface.dart';
import '../services/environment_service.dart';

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
  bool _showRoutes = true;
  bool _showTrains = true;
  bool _showStations = true;
  SubwayMode _mode = SubwayMode.demo;
  bool autoLighting = true; // true = 환경 서비스가 라이팅 제어

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
  static const int _animIntervalMs = 16; // ~60fps
  // Live 모드: 5분마다 API 호출
  static const int _liveApiFetchSec = 300;
  // 데모 모드 보간 주기 (10초)
  static const int _demoIntervalSec = 10;
  int _fetchIntervalSec = 300;
  int get _totalSteps => (_fetchIntervalSec * 1000) ~/ _animIntervalMs;

  // Live 모드: API 전환 시 부드러운 블렌딩
  DateTime? _apiTransitionStart;
  final Map<String, _AnimPos3D> _preApiPositions = {};
  static const double _apiTransitionDurationSec = 1.5; // API 데이터 전환 블렌딩 시간
  bool _layersInitialized3D = false;

  // 선택된 노선 필터 (null이면 전부 표시)
  Set<String>? _selectedLines;

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

    // 카메라를 역으로 이동
    if (_selectedStationInfo != null) {
      _mapController?.moveTo(
        _selectedStationInfo!.lat,
        _selectedStationInfo!.lng,
        zoom: 15.5,
        pitch: 50,
      );
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
    if (wasActive) start();
    onStateChanged?.call();
  }

  /// 시각화 시작
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    _lastError = null;
    onStateChanged?.call();

    // OSM 노선 경로 초기화
    try {
      if (!_routeGeometry.isInitialized) {
        await _routeGeometry.init();
        _interpolator.setRouteGeometry(_routeGeometry);
        _simulator.setRouteGeometry(_routeGeometry);
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
      // Live 모드: API 5분 + 매 프레임 연속 보간 (60fps)
      _fetchIntervalSec = _liveApiFetchSec;
      await _fetchAndRender();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: _liveApiFetchSec),
        (_) => _fetchAndRender(),
      );
      debugPrint('[SubwayOverlay] 📡 Live 모드 시작 (API ${_liveApiFetchSec}s + 60fps 연속 보간)');
    }

    // 애니메이션 타이머 (~60fps)
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: _animIntervalMs),
      (_) => _animationTick(),
    );

    // 환경 서비스 (시간/날씨) 시작
    _envService.onUpdated = () {
      _applyEnvironment();
      onStateChanged?.call();
    };
    _envService.start();
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

  /// 시각화 중지
  void stop() {
    _isActive = false;
    _envService.stop();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _animationTimer?.cancel();
    _animationTimer = null;
    _prevPositions.clear();
    _targetPositions.clear();
    _preApiPositions.clear();
    _apiTransitionStart = null;
    _clearAllOverlays();
    onStateChanged?.call();
  }

  /// 노선 필터 설정
  void setLineFilter(Set<String>? lines) {
    _selectedLines = lines;
    if (_isActive) {
      _renderAnimatedTrains();
      if (_showRoutes) _drawSubwayRoutes();
    }
    onStateChanged?.call();
  }

  /// 노선 경로 표시 토글
  void toggleRoutes(bool show) {
    _showRoutes = show;
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
    if (_isActive) {
      if (show) {
        _drawStationMarkers();
      } else {
        _mapController?.updateStations3D([]);
      }
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

  /// API에서 데이터 fetch (Live 모드)
  Future<void> _fetchAndRender() async {
    _adjustInterval();
    if (!_isActive) return;

    try {
      // API 전환 블렌딩: 현재 렌더링 중인 위치를 저장
      _preApiPositions.clear();
      for (final train in _currentTrains) {
        _preApiPositions[train.trainNo] = _AnimPos3D(
          train.lat, train.lng, train.altitude, train.isUnderground,
        );
      }

      final lineNames = _getSelectedLineApiNames();
      final allPositions = await _apiService.fetchAllTrainPositions(
        lineNames: lineNames,
      );

      final allTrains = <TrainPosition>[];
      for (final positions in allPositions.values) {
        allTrains.addAll(positions);
      }

      // 시뮬레이터에 스냅샷 저장 + 연속 보간 프리컴퓨트
      _simulator.updateApiSnapshot(allTrains);
      _simulator.prepareContinuousExtrapolation();

      _totalTrainCount = allTrains.length;
      _lastUpdate = DateTime.now();
      _lastError = null;

      // 블렌딩 시작 (이전 위치 → 새 연속 보간 위치)
      if (_preApiPositions.isNotEmpty) {
        _apiTransitionStart = DateTime.now();
      }
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

    // 시뮬레이터에서 현재 프레임의 정밀 위치 계산
    final framePositions = _simulator.getFramePositions();
    if (framePositions.isEmpty) return;

    // API 전환 블렌딩: 새 API 데이터 수신 직후 부드러운 전환
    double blendT = 1.0;
    if (_apiTransitionStart != null) {
      final elapsed =
          DateTime.now().difference(_apiTransitionStart!).inMilliseconds / 1000.0;
      if (elapsed < _apiTransitionDurationSec) {
        blendT = _easeInOut((elapsed / _apiTransitionDurationSec).clamp(0.0, 1.0));
      } else {
        _apiTransitionStart = null;
        _preApiPositions.clear();
      }
    }

    final filtered = <InterpolatedTrainPosition>[];
    for (final train in framePositions) {
      if (_selectedLines != null && !_selectedLines!.contains(train.subwayId)) {
        continue;
      }

      double lat = train.lat;
      double lng = train.lng;
      double bearing = train.bearing;

      // 블렌딩 중이면 이전 위치에서 부드럽게 전환
      if (blendT < 1.0) {
        final prev = _preApiPositions[train.trainNo];
        if (prev != null) {
          lat = _lerp(prev.lat, train.lat, blendT);
          lng = _lerp(prev.lng, train.lng, blendT);
          final dLat = train.lat - prev.lat;
          final dLng = train.lng - prev.lng;
          if (dLat.abs() > 1e-7 || dLng.abs() > 1e-7) {
            bearing = _bearingFromDelta(dLat, dLng);
          }
        }
      }

      filtered.add(InterpolatedTrainPosition(
        trainNo: train.trainNo,
        subwayId: train.subwayId,
        subwayName: train.subwayName,
        lat: lat,
        lng: lng,
        altitude: 0,
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

    _currentTrains = filtered;
    _totalTrainCount = filtered.length;
    _mapController!.updateTrainPositions3D(filtered);

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

    _mapController!.updateTrainPositions3D(interpolated);
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

      // 지선도 추가 (seongsu, sinjeong, macheon 등)
      for (final entry in geojsonRoutes.entries) {
        if (entry.key.startsWith('${lineId}_') && entry.value.length >= 2) {
          routeCoords[entry.key] = entry.value;
          lineColors[entry.key] = color;
          segmentUnderground[entry.key] = entry.value.map((coord) {
            final nearestStation = _findNearestStation(stations, coord[0], coord[1]);
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

  /// 역 마커를 3D 스타일로 그리기 (MiniTokyo3D 스타일)
  Future<void> _drawStationMarkers() async {
    if (_mapController == null) return;

    final stationData = <Map<String, dynamic>>[];
    final addedNames = <String>{}; // 중복 방지 (환승역)

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      if (_selectedLines != null && !_selectedLines!.contains(lineId)) continue;

      final stations = SeoulSubwayData.getLineStations(lineId);
      final color = SubwayColors.getColor(lineId);
      final colorStr = 'rgba(${(color.r * 255).round()},${(color.g * 255).round()},${(color.b * 255).round()},1)';

      for (final station in stations) {
        if (addedNames.contains(station.name)) continue;
        addedNames.add(station.name);

        // OSM 경로에 스냅된 좌표 사용 (없으면 원래 좌표)
        final snapped = _routeGeometry.getStationPosition(lineId, station.name);
        stationData.add({
          'lat': snapped?[0] ?? station.lat,
          'lng': snapped?[1] ?? station.lng,
          'name': station.name,
          'color': colorStr,
          'isTransfer': station.transferLines.isNotEmpty,
        });
      }
    }

    await _mapController!.updateStations3D(stationData);
  }

  /// 모든 오버레이 제거
  void _clearAllOverlays() {
    _mapController?.cleanup3DLayers();
    _layersInitialized3D = false;
  }

  void dispose() {
    stop();
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
