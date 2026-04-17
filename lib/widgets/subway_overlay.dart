import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../services/seoul_subway_service.dart';
import '../services/train_interpolator.dart';
import '../services/train_simulator.dart';
import '../core/map_interface.dart';

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

  IMapController? _mapController;
  Timer? _refreshTimer;
  Timer? _animationTimer;
  bool _isActive = false;
  bool _showRoutes = true;
  bool _showTrains = true;
  bool _showStations = true;
  SubwayMode _mode = SubwayMode.demo;

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

  // 콜백
  VoidCallback? onStateChanged;
  void Function(String stationName, List<ArrivalInfo> arrivals)? onStationTapped;

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

  void attachMap(IMapController controller) {
    _mapController = controller;
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

    // 3D 레이어 초기화
    if (!_layersInitialized3D) {
      await _mapController?.init3DLayers();
      _layersInitialized3D = true;
    }

    // 초기 노선 + 역 그리기
    if (_showRoutes) {
      await _drawSubwayRoutes();
    }
    if (_showStations) {
      await _drawStationMarkers();
    }

    if (_mode == SubwayMode.demo) {
      // 데모 모드: 시뮬레이터 초기화 + 10초마다 갱신
      _simulator.initDemoTrains();
      _fetchIntervalSec = _demoIntervalSec;
      _updateFromSimulator();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: _demoIntervalSec),
        (_) => _updateFromSimulator(),
      );
      debugPrint('[SubwayOverlay] 🎮 데모 모드 시작');
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
  }

  /// 시각화 중지
  void stop() {
    _isActive = false;
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

  /// 시뮬레이터에서 데이터 가져와 렌더링 (데모 모드)
  void _updateFromSimulator() {
    if (!_isActive) return;
    final positions = _simulator.generateDemoPositions();
    _applyTrainPositions(positions);
    _lastUpdate = DateTime.now();
    _lastError = null;
    debugPrint('[SubwayOverlay] 🎮 데모 열차 $_totalTrainCount개');
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

  /// 애니메이션 틱: 열차 위치를 한 스텝 전진
  void _animationTick() {
    if (!_isActive || !_showTrains) return;

    if (_mode == SubwayMode.live) {
      // Live 모드: 매 프레임 시간표 기반 연속 위치 계산
      _renderLiveContinuous();
    } else {
      // 데모 모드: 기존 prev→target 보간
      if (_targetPositions.isEmpty) return;
      _animProgress += 1.0 / _totalSteps;
      if (_animProgress > 1.0) _animProgress = 1.0;
      _renderAnimatedTrains();
    }
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

  /// 지하철 노선 경로를 3D로 그리기 (지상/지하 구분)
  Future<void> _drawSubwayRoutes() async {
    if (_mapController == null) return;

    final routeCoords = <String, List<List<double>>>{};
    final lineColors = <String, Color>{};
    final segmentUnderground = <String, List<bool>>{};

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      if (_selectedLines != null && !_selectedLines!.contains(lineId)) continue;

      final stations = SeoulSubwayData.getLineStations(lineId);
      if (stations.length < 2) continue;

      routeCoords[lineId] = stations.map((s) => [s.lat, s.lng]).toList();
      lineColors[lineId] = SubwayColors.getColor(lineId);
      segmentUnderground[lineId] = stations
          .map((s) => !SeoulSubwayData.isSurfaceStation(s.id))
          .toList();
    }

    await _mapController!.initRoutes3D(routeCoords, lineColors, segmentUnderground);
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

        stationData.add({
          'lat': station.lat,
          'lng': station.lng,
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
