import 'dart:convert';
import 'dart:async';

/// 서울시 공공데이터 API 연동을 위한 서비스 클래스
/// 현재는 가상(Mock) 데이터를 반환하도록 구현됨.
class SeoulApiService {
  // 가상 API 호출 지연 시간 시뮬레이션
  static const Duration _mockDelay = Duration(milliseconds: 500);

  /// 서울시 따릉이 실시간 대여소 정보 Mock API
  Future<List<Map<String, dynamic>>> fetchBikeStations() async {
    await Future.delayed(_mockDelay);
    
    // 가상 데이터 (서울시청 근처 따릉이소)
    return [
      {
        "stationId": "ST-1",
        "stationName": "서울시청 광장 옆",
        "lat": 37.5665,
        "lng": 126.9780,
        "parkingBikeTotCnt": 15,
      },
      {
        "stationId": "ST-2",
        "stationName": "강남역 1번 출구",
        "lat": 37.4979,
        "lng": 127.0276,
        "parkingBikeTotCnt": 8,
      },
      {
        "stationId": "ST-3",
        "stationName": "홍대입구역 2번 출구",
        "lat": 37.5567,
        "lng": 126.9236,
        "parkingBikeTotCnt": 3,
      }
    ];
  }

  /// 서울시 도로 소통 정보 Mock API
  Future<Map<String, dynamic>> fetchTrafficStatus() async {
    await Future.delayed(_mockDelay);
    return {
      "status": "normal",
      "congestion_level": 2, // 1: 원활, 2: 보통, 3: 정체
      "last_updated": DateTime.now().toIso8601String(),
    };
  }

  /// 서울시 행정구역 경계 데이터 (GeoJSON) Mock API
  Future<String> fetchSeoulBoundaries() async {
    await Future.delayed(_mockDelay);
    // 실제로는 복잡한 GeoJSON 문자열이 반환됨
    return jsonEncode({
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"name": "Jung-gu"},
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [[126.97, 37.56], [126.98, 37.56], [126.98, 37.57], [126.97, 37.56]]
            ]
          }
        }
      ]
    });
  }
}
