/// 서울 지하철 데이터 모델 - MiniTokyo3D 스타일 실시간 시각화용

import 'package:flutter/material.dart';

/// 지하철 노선 정보
class SubwayLine {
  final String id;        // e.g., '1001' for 1호선
  final String name;      // e.g., '1호선'
  final Color color;
  final List<StationInfo> stations;

  const SubwayLine({
    required this.id,
    required this.name,
    required this.color,
    required this.stations,
  });
}

/// 역 정보
class StationInfo {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<String> transferLines; // 환승 가능한 노선 ID 목록

  const StationInfo({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.transferLines = const [],
  });
}

/// 실시간 열차 위치 (API: realtimePosition)
class TrainPosition {
  final String subwayId;      // 노선 ID (1001, 1002, ...)
  final String subwayName;    // 노선명 (1호선, 2호선, ...)
  final String stationId;     // 현재 역 ID
  final String stationName;   // 현재 역명
  final String trainNo;       // 열차번호
  final String lastRecvDate;  // 최종수신일
  final String recvTime;      // 최종수신시간
  final int direction;        // 0: 상행/내선, 1: 하행/외선
  final String terminalId;    // 종착역 ID
  final String terminalName;  // 종착역명
  final int trainStatus;      // 0:진입, 1:도착, 2:출발, 3:전역출발
  final int expressType;      // 1:급행, 0:일반, 7:특급
  final bool isLastTrain;     // 막차 여부

  const TrainPosition({
    required this.subwayId,
    required this.subwayName,
    required this.stationId,
    required this.stationName,
    required this.trainNo,
    required this.lastRecvDate,
    required this.recvTime,
    required this.direction,
    required this.terminalId,
    required this.terminalName,
    required this.trainStatus,
    required this.expressType,
    required this.isLastTrain,
  });

  factory TrainPosition.fromJson(Map<String, dynamic> json) {
    return TrainPosition(
      subwayId: json['subwayId'] ?? '',
      subwayName: json['subwayNm'] ?? '',
      stationId: json['statnId'] ?? '',
      stationName: json['statnNm'] ?? '',
      trainNo: json['trainNo'] ?? '',
      lastRecvDate: json['lastRecptnDt'] ?? '',
      recvTime: json['recptnDt'] ?? '',
      direction: int.tryParse(json['updnLine']?.toString() ?? '0') ?? 0,
      terminalId: json['statnTid'] ?? '',
      terminalName: json['statnTnm'] ?? '',
      trainStatus: int.tryParse(json['trainSttus']?.toString() ?? '0') ?? 0,
      expressType: int.tryParse(json['directAt']?.toString() ?? '0') ?? 0,
      isLastTrain: json['lstcarAt'] == '1',
    );
  }

  /// trainStatus에 따른 열차의 역 기준 상대적 위치 비율 (0.0~1.0)
  /// 전역출발(3) → 진입(0) → 도착(1) → 출발(2) 순서
  double get segmentProgress {
    switch (trainStatus) {
      case 3: return 0.0;   // 전역 출발 (이전역 떠남)
      case 0: return 0.8;   // 진입 (현재역에 거의 도착)
      case 1: return 1.0;   // 도착 (현재역 도착)
      case 2: return 0.0;   // 출발 (현재역 떠남 → 다음 구간 시작)
      default: return 0.5;
    }
  }

  String get statusText {
    switch (trainStatus) {
      case 0: return '진입';
      case 1: return '도착';
      case 2: return '출발';
      case 3: return '전역출발';
      default: return '운행중';
    }
  }

  String get directionText => direction == 0 ? '상행' : '하행';
}

/// 실시간 도착 정보 (API: realtimeStationArrival)
class ArrivalInfo {
  final String subwayId;
  final String direction;       // 상행/하행
  final String trainLineName;   // 방면 정보
  final String stationName;
  final String trainType;       // 급행/일반
  final int arrivalSeconds;     // 도착까지 남은 초
  final String trainNo;
  final String destinationName; // 종착역
  final String arrivalMsg;      // "3분 후 도착" 등
  final String arrivalMsg2;     // 상세 메시지
  final String recvTime;
  final int arrivalCode;        // 0~5, 99

  const ArrivalInfo({
    required this.subwayId,
    required this.direction,
    required this.trainLineName,
    required this.stationName,
    required this.trainType,
    required this.arrivalSeconds,
    required this.trainNo,
    required this.destinationName,
    required this.arrivalMsg,
    required this.arrivalMsg2,
    required this.recvTime,
    required this.arrivalCode,
  });

  factory ArrivalInfo.fromJson(Map<String, dynamic> json) {
    return ArrivalInfo(
      subwayId: json['subwayId'] ?? '',
      direction: json['updnLine'] ?? '',
      trainLineName: json['trainLineNm'] ?? '',
      stationName: json['statnNm'] ?? '',
      trainType: json['btrainSttus'] ?? '일반',
      arrivalSeconds: int.tryParse(json['barvlDt']?.toString() ?? '0') ?? 0,
      trainNo: json['btrainNo'] ?? '',
      destinationName: json['bstatnNm'] ?? '',
      arrivalMsg: json['arvlMsg2'] ?? '',
      arrivalMsg2: json['arvlMsg3'] ?? '',
      recvTime: json['recptnDt'] ?? '',
      arrivalCode: int.tryParse(json['arvlCd']?.toString() ?? '99') ?? 99,
    );
  }

  String get arrivalCodeText {
    switch (arrivalCode) {
      case 0: return '진입';
      case 1: return '도착';
      case 2: return '출발';
      case 3: return '전역출발';
      case 4: return '전역진입';
      case 5: return '전역도착';
      case 99: return '운행중';
      default: return '알수없음';
    }
  }
}

/// 지하도 공간정보 노드 (API: OA-21213)
class UndergroundNode {
  final String nodeId;
  final String nodeType;
  final double lat;
  final double lng;
  final String stationCode;
  final String stationName;
  final bool hasLift;
  final bool hasElevator;

  const UndergroundNode({
    required this.nodeId,
    required this.nodeType,
    required this.lat,
    required this.lng,
    required this.stationCode,
    required this.stationName,
    required this.hasLift,
    required this.hasElevator,
  });
}

/// 지하도 링크 (역 간 연결 통로)
class UndergroundLink {
  final String linkId;
  final String linkType;
  final String startNodeId;
  final String endNodeId;
  final double length;
  final List<List<double>> coordinates; // WKT에서 파싱된 좌표 목록

  const UndergroundLink({
    required this.linkId,
    required this.linkType,
    required this.startNodeId,
    required this.endNodeId,
    required this.length,
    required this.coordinates,
  });
}

/// 지하철 출입구 리프트 위치 (API: OA-21211)
class SubwayLift {
  final String nodeId;
  final double lat;
  final double lng;
  final String stationCode;
  final String stationName;
  final String districtName;

  const SubwayLift({
    required this.nodeId,
    required this.lat,
    required this.lng,
    required this.stationCode,
    required this.stationName,
    required this.districtName,
  });
}

/// 보간된 열차의 지도 상 위치
class InterpolatedTrainPosition {
  final String trainNo;
  final String subwayId;
  final String subwayName;
  final double lat;
  final double lng;
  final int direction;
  final String terminalName;
  final String stationName;
  final int trainStatus;
  final int expressType;
  final bool isLastTrain;
  final double bearing; // 열차 진행 방향 (지도 베어링)

  const InterpolatedTrainPosition({
    required this.trainNo,
    required this.subwayId,
    required this.subwayName,
    required this.lat,
    required this.lng,
    required this.direction,
    required this.terminalName,
    required this.stationName,
    required this.trainStatus,
    required this.expressType,
    required this.isLastTrain,
    required this.bearing,
  });
}

/// 서울 지하철 노선 ID → 색상 매핑
class SubwayColors {
  static const Map<String, Color> lineColors = {
    '1001': Color(0xFF0052A4), // 1호선 - 남색
    '1002': Color(0xFF00A84D), // 2호선 - 녹색
    '1003': Color(0xFFEF7C1C), // 3호선 - 주황
    '1004': Color(0xFF00A5DE), // 4호선 - 하늘색
    '1005': Color(0xFF996CAC), // 5호선 - 보라
    '1006': Color(0xFFCD7C2F), // 6호선 - 황토
    '1007': Color(0xFF747F00), // 7호선 - 올리브
    '1008': Color(0xFFE6186C), // 8호선 - 분홍
    '1009': Color(0xFFBDB092), // 9호선 - 금색
    '1063': Color(0xFF77C4A3), // 경의중앙선
    '1065': Color(0xFF0090D2), // 공항철도
    '1067': Color(0xFF32A1C8), // 경춘선
    '1075': Color(0xFFEBA900), // 수인분당선
    '1077': Color(0xFFD4003B), // 신분당선
    '1092': Color(0xFFB7C452), // 우이신설선
    '1032': Color(0xFF9A6292), // GTX-A
  };

  static Color getColor(String subwayId) {
    return lineColors[subwayId] ?? Colors.grey;
  }

  static const Map<String, String> lineNames = {
    '1001': '1호선',
    '1002': '2호선',
    '1003': '3호선',
    '1004': '4호선',
    '1005': '5호선',
    '1006': '6호선',
    '1007': '7호선',
    '1008': '8호선',
    '1009': '9호선',
    '1063': '경의중앙선',
    '1065': '공항철도',
    '1067': '경춘선',
    '1075': '수인분당선',
    '1077': '신분당선',
    '1092': '우이신설선',
    '1032': 'GTX-A',
  };
}