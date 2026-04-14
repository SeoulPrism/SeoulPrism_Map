import 'dart:async';
import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/seoul_subway_data.dart';
import '../services/seoul_subway_service.dart';
import '../services/train_interpolator.dart';
import '../core/map_interface.dart';

/// MiniTokyo3D 스타일 지하철 시각화 오버레이 컨트롤러
/// 실시간 열차 위치 + 노선 경로를 지도 위에 렌더링
class SubwayOverlayController {
  final SeoulSubwayService _apiService = SeoulSubwayService();
  final TrainInterpolator _interpolator = TrainInterpolator();

  IMapController? _mapController;
  Timer? _refreshTimer;
  Timer? _animationTimer;
  bool _isActive = false;
  bool _showRoutes = true;
  bool _showTrains = true;
  bool _showStations = false;

  // 현재 상태
  List<InterpolatedTrainPosition> _currentTrains = [];
  final Map<String, List<ArrivalInfo>> _arrivalCache = {};
  String? _lastError;
  DateTime? _lastUpdate;
  int _totalTrainCount = 0;

  // 애니메이션 상태
  // trainNo → 이전 위치 (lerp 시작점)
  Map<String, _AnimPos> _prevPositions = {};
  // trainNo → 목표 위치 (lerp 도착점)
  Map<String, _AnimPos> _targetPositions = {};
  // 0.0 ~ 1.0, API 갱신마다 0으로 리셋
  double _animProgress = 1.0;
  static const int _animIntervalMs = 200;
  static const int _fetchIntervalSec = 15;
  // 한 사이클에서 진행할 총 스텝 수
  static final int _totalSteps = (_fetchIntervalSec * 1000) ~/ _animIntervalMs;

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
  List<InterpolatedTrainPosition> get currentTrains => _currentTrains;
  String? get lastError => _lastError;
  DateTime? get lastUpdate => _lastUpdate;
  int get totalTrainCount => _totalTrainCount;
  Set<String>? get selectedLines => _selectedLines;

  void attachMap(IMapController controller) {
    _mapController = controller;
  }

  /// 시각화 시작
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    _lastError = null;
    onStateChanged?.call();

    // 초기 노선 그리기
    if (_showRoutes) {
      await _drawSubwayRoutes();
    }

    // 첫 데이터 로드
    await _fetchAndRender();

    // 주기적 API 갱신
    _refreshTimer = Timer.periodic(
      Duration(seconds: _fetchIntervalSec),
      (_) => _fetchAndRender(),
    );

    // 애니메이션 타이머 (200ms 간격으로 열차 위치 보간)
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
        _mapController?.clearPolylines();
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
        _mapController?.clearCircleMarkers();
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

  /// 데이터 fetch + 애니메이션 타겟 설정
  Future<void> _fetchAndRender() async {
    try {
      final allPositions = await _apiService.fetchAllTrainPositions();

      final allTrains = <TrainPosition>[];
      for (final positions in allPositions.values) {
        allTrains.addAll(positions);
      }

      _totalTrainCount = allTrains.length;
      _currentTrains = _interpolator.interpolateAll(allTrains);
      _lastUpdate = DateTime.now();
      _lastError = null;

      // 이전 target → prev로 이동, 새 target 설정
      _prevPositions = Map.from(_targetPositions);
      _targetPositions = {};
      for (final train in _currentTrains) {
        _targetPositions[train.trainNo] = _AnimPos(train.lat, train.lng);
        // 새로 등장한 열차는 target 위치에서 시작
        _prevPositions.putIfAbsent(train.trainNo, () => _AnimPos(train.lat, train.lng));
      }

      // 애니메이션 진행도 리셋
      _animProgress = 0.0;

      if (_showTrains) {
        _renderAnimatedTrains();
      }
    } catch (e) {
      _lastError = e.toString();
    }
    onStateChanged?.call();
  }

  /// 애니메이션 틱: 열차 위치를 한 스텝 전진
  void _animationTick() {
    if (!_isActive || !_showTrains) return;
    if (_targetPositions.isEmpty) return;

    // 진행도 증가
    _animProgress += 1.0 / _totalSteps;
    if (_animProgress > 1.0) _animProgress = 1.0;

    _renderAnimatedTrains();
  }

  /// 현재 애니메이션 진행도에 따라 열차 렌더링
  void _renderAnimatedTrains() {
    if (_mapController == null) return;
    _mapController!.clearCircleMarkers();

    // easeInOut 곡선 적용
    final t = _easeInOut(_animProgress.clamp(0.0, 1.0));

    for (final train in _currentTrains) {
      // 노선 필터 적용
      if (_selectedLines != null && !_selectedLines!.contains(train.subwayId)) {
        continue;
      }

      final prev = _prevPositions[train.trainNo];
      final target = _targetPositions[train.trainNo];
      if (target == null) continue;

      // prev가 있으면 보간, 없으면 target 위치
      final lat = prev != null ? _lerp(prev.lat, target.lat, t) : target.lat;
      final lng = prev != null ? _lerp(prev.lng, target.lng, t) : target.lng;

      final color = SubwayColors.getColor(train.subwayId);
      final radius = train.expressType == 1 ? 8.0 : 6.0;

      _mapController!.addCircleMarker(
        'train_${train.trainNo}',
        lat,
        lng,
        color: color,
        radius: radius,
        strokeColor: train.isLastTrain ? Colors.red : Colors.white,
        strokeWidth: train.isLastTrain ? 3.0 : 1.5,
      );
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// ease-in-out 곡선 (부드러운 출발/도착)
  double _easeInOut(double t) => t * t * (3.0 - 2.0 * t);

  /// 지하철 노선 경로를 지도에 그리기
  Future<void> _drawSubwayRoutes() async {
    if (_mapController == null) return;
    _mapController!.clearPolylines();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;

      if (_selectedLines != null && !_selectedLines!.contains(lineId)) {
        continue;
      }

      final stations = SeoulSubwayData.getLineStations(lineId);
      if (stations.length < 2) continue;

      final coordinates = stations
          .map((s) => [s.lat, s.lng])
          .toList();

      final color = SubwayColors.getColor(lineId);

      await _mapController!.addPolyline(
        'route_$lineId',
        coordinates,
        color: color,
        width: 3.0,
        opacity: 0.8,
      );
    }
  }

  /// 역 마커를 지도에 그리기
  Future<void> _drawStationMarkers() async {
    if (_mapController == null) return;

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;
      if (_selectedLines != null && !_selectedLines!.contains(lineId)) continue;

      final stations = SeoulSubwayData.getLineStations(lineId);
      final color = SubwayColors.getColor(lineId);

      for (final station in stations) {
        await _mapController!.addStationMarker(
          'stn_${station.id}',
          station.lat,
          station.lng,
          name: station.name,
          color: color,
        );
      }
    }
  }

  /// 모든 오버레이 제거
  void _clearAllOverlays() {
    _mapController?.clearPolylines();
    _mapController?.clearCircleMarkers();
  }

  void dispose() {
    stop();
  }
}

/// 애니메이션용 위치 데이터
class _AnimPos {
  final double lat;
  final double lng;
  const _AnimPos(this.lat, this.lng);
}
