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
  bool _isActive = false;
  bool _showRoutes = true;
  bool _showTrains = true;
  bool _showStations = false;

  // 현재 상태
  List<InterpolatedTrainPosition> _currentTrains = [];
  Map<String, List<ArrivalInfo>> _arrivalCache = {};
  String? _lastError;
  DateTime? _lastUpdate;
  int _totalTrainCount = 0;

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

  /// 시각화 시작 (15초 간격 갱신)
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

    // 주기적 갱신 (15초)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndRender(),
    );
  }

  /// 시각화 중지
  void stop() {
    _isActive = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _clearAllOverlays();
    onStateChanged?.call();
  }

  /// 노선 필터 설정
  void setLineFilter(Set<String>? lines) {
    _selectedLines = lines;
    if (_isActive) {
      _renderTrains();
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
        _renderTrains();
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
      // 역 마커는 addMarker로 추가되므로 별도 제거 필요
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

  /// 데이터 fetch + 렌더링
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

      if (_showTrains) {
        _renderTrains();
      }
    } catch (e) {
      _lastError = e.toString();
    }
    onStateChanged?.call();
  }

  /// 열차 위치를 지도에 렌더링
  void _renderTrains() {
    if (_mapController == null) return;
    _mapController!.clearCircleMarkers();

    for (final train in _currentTrains) {
      // 노선 필터 적용
      if (_selectedLines != null && !_selectedLines!.contains(train.subwayId)) {
        continue;
      }

      final color = SubwayColors.getColor(train.subwayId);
      final radius = train.expressType == 1 ? 8.0 : 6.0; // 급행은 더 크게

      _mapController!.addCircleMarker(
        'train_${train.trainNo}',
        train.lat,
        train.lng,
        color: color,
        radius: radius,
        strokeColor: train.isLastTrain ? Colors.red : Colors.white,
        strokeWidth: train.isLastTrain ? 3.0 : 1.5,
      );
    }
  }

  /// 지하철 노선 경로를 지도에 그리기
  Future<void> _drawSubwayRoutes() async {
    if (_mapController == null) return;
    _mapController!.clearPolylines();

    for (final entry in SeoulSubwayData.lineIdToApiName.entries) {
      final lineId = entry.key;

      // 노선 필터 적용
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
