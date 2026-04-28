import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:collection';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/api_keys.dart';
import '../data/seoul_subway_data.dart';
import '../models/subway_models.dart';

/// 최단경로 탐색 유형
enum PathSearchType {
  duration, // 최소 시간
  distance, // 최단 거리
  transfer, // 최소 환승
}

/// 경로 구간 정보
class PathSegment {
  final String lineName;
  final String lineId;
  final List<String> stations;
  final int travelTimeSec;
  final double distanceKm;
  final bool isTransfer;

  const PathSegment({
    required this.lineName,
    required this.lineId,
    required this.stations,
    required this.travelTimeSec,
    required this.distanceKm,
    this.isTransfer = false,
  });
}

/// 전체 경로 결과
class PathResult {
  final String departure;
  final String arrival;
  final PathSearchType searchType;
  final int totalTimeSec;
  final double totalDistanceKm;
  final int transferCount;
  final List<PathSegment> segments;
  final bool isLocal; // 로컬 계산 결과 여부

  const PathResult({
    required this.departure,
    required this.arrival,
    required this.searchType,
    required this.totalTimeSec,
    required this.totalDistanceKm,
    required this.transferCount,
    required this.segments,
    this.isLocal = false,
  });

  String get totalTimeFormatted {
    final min = totalTimeSec ~/ 60;
    if (min >= 60) return '${min ~/ 60}시간 ${min % 60}분';
    return '$min분';
  }
}

/// 서울 지하철 최단경로 탐색 서비스
/// 1차: data.go.kr API 호출
/// 2차: 로컬 BFS 경로 계산 (폴백)
class PathFindingService {
  static const String _baseUrl = 'https://apis.data.go.kr/B553766/path/getShtrmPath';

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 그래프 캐시 (최초 1회 빌드)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static bool _graphBuilt = false;
  // 역명 → 속한 노선ID 목록
  static final Map<String, Set<String>> _stationLines = {};
  // (역명, 노선ID) → 해당 노선에서의 인접역 목록 [(역명, 소요시간초)]
  static final Map<String, List<_Edge>> _adj = {};

  /// 두 역 좌표 사이 거리(km) 기반 소요시간 추정 (평균 35km/h)
  static int _estimateTimeSec(StationInfo a, StationInfo b) {
    final dLat = (a.lat - b.lat) * 111.0; // 위도 1도 ≈ 111km
    final dLng = (a.lng - b.lng) * 88.0;  // 경도 1도 ≈ 88km (서울 위도 기준)
    final distKm = sqrt(dLat * dLat + dLng * dLng) * 1.3; // 직선 × 1.3 보정
    return (distKm / 35.0 * 3600).round().clamp(60, 600); // 최소 1분, 최대 10분
  }

  static void _buildGraph() {
    if (_graphBuilt) return;

    for (final entry in SubwayColors.lineColors.entries) {
      final lineId = entry.key;
      final stations = SeoulSubwayData.getLineStations(lineId);

      for (int i = 0; i < stations.length; i++) {
        final s = stations[i];
        final key = '${s.name}|$lineId';
        _stationLines.putIfAbsent(s.name, () => {}).add(lineId);
        _adj.putIfAbsent(key, () => []);

        // 다음 역 연결
        if (i + 1 < stations.length) {
          final next = stations[i + 1];
          final nextKey = '${next.name}|$lineId';
          _adj.putIfAbsent(nextKey, () => []);
          // travelNextSec이 0이면 좌표 기반 추정
          final timeSec = s.travelNextSec > 0
              ? s.travelNextSec
              : _estimateTimeSec(s, next);
          _adj[key]!.add(_Edge(next.name, lineId, timeSec));
          _adj[nextKey]!.add(_Edge(s.name, lineId, timeSec));
        }
      }
    }

    // 환승 간선 추가 (같은 이름 다른 노선 → 환승시간 180초)
    for (final entry in _stationLines.entries) {
      final name = entry.key;
      final lines = entry.value.toList();
      for (int i = 0; i < lines.length; i++) {
        for (int j = i + 1; j < lines.length; j++) {
          final keyA = '$name|${lines[i]}';
          final keyB = '$name|${lines[j]}';
          _adj[keyA]!.add(_Edge(name, lines[j], 180, isTransfer: true));
          _adj[keyB]!.add(_Edge(name, lines[i], 180, isTransfer: true));
        }
      }
    }

    _graphBuilt = true;
    developer.log('[PathFinding] 그래프 빌드 완료: ${_stationLines.length}개 역');
  }

  /// 최단경로 검색 (API → 로컬 폴백)
  Future<PathResult> findPath({
    required String departure,
    required String arrival,
    PathSearchType searchType = PathSearchType.duration,
    List<String>? excludeTransferStations,
    List<String>? throughStations,
  }) async {
    // API 키가 있으면 먼저 API 시도
    if (ApiKeys.dataGoKrApiKey.isNotEmpty) {
      final apiResult = await _findPathViaApi(
        departure: departure,
        arrival: arrival,
        searchType: searchType,
        excludeTransferStations: excludeTransferStations,
        throughStations: throughStations,
      );
      if (apiResult != null) return apiResult;
    }

    // 로컬 BFS 폴백
    return _findPathLocal(departure, arrival, searchType);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // API 호출
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<PathResult?> _findPathViaApi({
    required String departure,
    required String arrival,
    required PathSearchType searchType,
    List<String>? excludeTransferStations,
    List<String>? throughStations,
  }) async {
    try {
      final searchTypeStr = switch (searchType) {
        PathSearchType.duration => 'duration',
        PathSearchType.distance => 'distance',
        PathSearchType.transfer => 'transfer',
      };

      final now = DateTime.now();
      final searchDt = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

      final params = <String, String>{
        'serviceKey': ApiKeys.dataGoKrApiKey,
        'dataType': 'JSON',
        'dptreStnNm': departure,
        'arvlStnNm': arrival,
        'searchDt': searchDt,
        'searchType': searchTypeStr,
      };

      if (excludeTransferStations != null && excludeTransferStations.isNotEmpty) {
        params['exclTrfstnNms'] = excludeTransferStations.join(',');
      }
      if (throughStations != null && throughStations.isNotEmpty) {
        params['thrghStnNms'] = throughStations.join(',');
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      developer.log('[PathFinding] API 요청: $departure → $arrival');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      return _parseApiResponse(json, departure, arrival, searchType);
    } catch (e) {
      developer.log('[PathFinding] API 실패, 로컬 폴백: $e');
      return null;
    }
  }

  PathResult? _parseApiResponse(
    Map<String, dynamic> json,
    String departure, String arrival, PathSearchType searchType,
  ) {
    try {
      final body = json['body'];
      if (body == null) return null;
      final items = body['items'] ?? body['item'];
      if (items == null) return null;
      final List<dynamic> itemList = items is List ? items : [items];

      final segments = <PathSegment>[];
      int totalTime = 0;
      double totalDist = 0;
      int transfers = 0;

      for (final item in itemList) {
        final lineName = item['lnNm']?.toString() ?? '';
        final lineId = _lineNameToId(lineName);
        final stationNames = <String>[];
        final stnNm = item['stnNm']?.toString();
        final dptre = item['dptreStnNm']?.toString();
        final arvl = item['arvlStnNm']?.toString();
        if (dptre != null) stationNames.add(dptre);
        if (stnNm != null && !stationNames.contains(stnNm)) stationNames.add(stnNm);
        if (arvl != null && !stationNames.contains(arvl)) stationNames.add(arvl);

        final time = _parseInt(item['mvTm'] ?? 0);
        final dist = _parseDouble(item['mvDist'] ?? 0);
        final isTrf = item['trfYn']?.toString() == 'Y';
        totalTime += time;
        totalDist += dist;
        if (isTrf) transfers++;

        segments.add(PathSegment(
          lineName: lineName, lineId: lineId, stations: stationNames,
          travelTimeSec: time, distanceKm: dist / 1000, isTransfer: isTrf,
        ));
      }

      totalTime = _parseInt(body['totalTm'] ?? totalTime);
      totalDist = _parseDouble(body['totalDist'] ?? totalDist);
      transfers = _parseInt(body['trfCnt'] ?? transfers);

      return PathResult(
        departure: departure, arrival: arrival, searchType: searchType,
        totalTimeSec: totalTime, totalDistanceKm: totalDist / 1000,
        transferCount: transfers, segments: segments,
      );
    } catch (e) {
      developer.log('[PathFinding] API 파싱 에러: $e');
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 로컬 BFS 경로 탐색 (Dijkstra)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  PathResult _findPathLocal(String departure, String arrival, PathSearchType searchType) {
    _buildGraph();

    final depLines = _stationLines[departure];
    final arrLines = _stationLines[arrival];
    if (depLines == null || arrLines == null) {
      return PathResult(
        departure: departure, arrival: arrival, searchType: searchType,
        totalTimeSec: 0, totalDistanceKm: 0, transferCount: 0,
        segments: [], isLocal: true,
      );
    }

    // Dijkstra (최소 시간 or 최소 환승)
    final useTransferWeight = searchType == PathSearchType.transfer;
    final dist = <String, int>{};
    final prev = <String, String>{};
    final prevEdge = <String, _Edge>{};
    final pq = SplayTreeSet<_PQEntry>((a, b) {
      final cmp = a.cost.compareTo(b.cost);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });

    // 시작점: 출발역의 모든 노선
    for (final lineId in depLines) {
      final key = '$departure|$lineId';
      dist[key] = 0;
      pq.add(_PQEntry(key, 0));
    }

    while (pq.isNotEmpty) {
      final cur = pq.first;
      pq.remove(cur);

      if (cur.cost > (dist[cur.key] ?? 999999)) continue;

      final curName = cur.key.split('|')[0];
      if (curName == arrival) break;

      for (final edge in _adj[cur.key] ?? <_Edge>[]) {
        final nextKey = '${edge.toStation}|${edge.lineId}';
        final weight = useTransferWeight
            ? (edge.isTransfer ? 10000 : 1) // 환승 패널티
            : edge.timeSec;
        final newCost = cur.cost + weight;

        if (newCost < (dist[nextKey] ?? 999999)) {
          dist[nextKey] = newCost;
          prev[nextKey] = cur.key;
          prevEdge[nextKey] = edge;
          pq.add(_PQEntry(nextKey, newCost));
        }
      }
    }

    // 도착점에서 최소 비용 노선 찾기
    String? endKey;
    int minCost = 999999;
    for (final lineId in arrLines) {
      final key = '$arrival|$lineId';
      if ((dist[key] ?? 999999) < minCost) {
        minCost = dist[key]!;
        endKey = key;
      }
    }

    if (endKey == null) {
      return PathResult(
        departure: departure, arrival: arrival, searchType: searchType,
        totalTimeSec: 0, totalDistanceKm: 0, transferCount: 0,
        segments: [], isLocal: true,
      );
    }

    // 경로 역추적
    final path = <String>[endKey];
    while (prev.containsKey(path.last)) {
      path.add(prev[path.last]!);
    }
    path.reversed;
    final reversedPath = path.reversed.toList();

    // 경로를 구간(같은 노선)별로 그룹핑
    final segments = <PathSegment>[];
    int totalTime = 0;
    int transfers = 0;
    String? currentLineId;
    List<String> currentStations = [];
    int currentTime = 0;

    for (int i = 0; i < reversedPath.length; i++) {
      final parts = reversedPath[i].split('|');
      final stationName = parts[0];
      final lineId = parts[1];

      if (i > 0) {
        final edge = prevEdge[reversedPath[i]];
        if (edge != null) {
          totalTime += edge.timeSec;
          if (edge.isTransfer) {
            // 이전 구간 저장
            if (currentStations.isNotEmpty && currentLineId != null) {
              segments.add(PathSegment(
                lineName: _lineIdToName(currentLineId),
                lineId: currentLineId,
                stations: List.from(currentStations),
                travelTimeSec: currentTime,
                distanceKm: _estimateDistance(currentTime),
              ));
            }
            // 환승 구간 추가
            segments.add(PathSegment(
              lineName: '환승',
              lineId: '',
              stations: [stationName],
              travelTimeSec: edge.timeSec,
              distanceKm: 0,
              isTransfer: true,
            ));
            transfers++;
            currentStations = [stationName];
            currentLineId = lineId;
            currentTime = 0;
            continue;
          }
          currentTime += edge.timeSec;
        }
      }

      if (lineId != currentLineId) {
        if (currentStations.isNotEmpty && currentLineId != null) {
          segments.add(PathSegment(
            lineName: _lineIdToName(currentLineId),
            lineId: currentLineId,
            stations: List.from(currentStations),
            travelTimeSec: currentTime,
            distanceKm: _estimateDistance(currentTime),
          ));
          currentTime = 0;
        }
        currentLineId = lineId;
        currentStations = [stationName];
      } else {
        if (!currentStations.contains(stationName)) {
          currentStations.add(stationName);
        }
      }
    }

    // 마지막 구간 저장
    if (currentStations.isNotEmpty && currentLineId != null) {
      segments.add(PathSegment(
        lineName: _lineIdToName(currentLineId),
        lineId: currentLineId,
        stations: currentStations,
        travelTimeSec: currentTime,
        distanceKm: _estimateDistance(currentTime),
      ));
    }

    return PathResult(
      departure: departure,
      arrival: arrival,
      searchType: searchType,
      totalTimeSec: totalTime,
      totalDistanceKm: segments.fold(0.0, (sum, s) => sum + s.distanceKm),
      transferCount: transfers,
      segments: segments,
      isLocal: true,
    );
  }

  // 소요시간 기반 거리 추정 (평균 35km/h)
  double _estimateDistance(int timeSec) {
    return (timeSec / 3600.0) * 35.0;
  }

  int _parseInt(dynamic v) => v is int ? v : v is double ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
  double _parseDouble(dynamic v) => v is double ? v : v is int ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _lineNameToId(String name) {
    const m = {
      '1호선': '1001', '2호선': '1002', '3호선': '1003', '4호선': '1004',
      '5호선': '1005', '6호선': '1006', '7호선': '1007', '8호선': '1008',
      '9호선': '1009', '경의중앙선': '1063', '공항철도': '1065',
      '경춘선': '1067', '수인분당선': '1075', '신분당선': '1077',
      '우이신설선': '1092', 'GTX-A': '1032', '서해선': '1093',
      '신림선': '1094', '경강선': '1081',
    };
    return m[name] ?? '';
  }

  String _lineIdToName(String id) {
    return SubwayColors.lineNames[id] ?? id;
  }
}

class _Edge {
  final String toStation;
  final String lineId;
  final int timeSec;
  final bool isTransfer;

  const _Edge(this.toStation, this.lineId, this.timeSec, {this.isTransfer = false});
}

class _PQEntry {
  final String key;
  final int cost;

  const _PQEntry(this.key, this.cost);
}
