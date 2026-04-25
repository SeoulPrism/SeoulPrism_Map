/// 서울 지하철 데이터 모델 - MiniTokyo3D 스타일 실시간 시각화용

import 'dart:math';
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
  final bool isUnderground; // true: 지하, false: 지상
  final int dwellSec;       // 정차시간 (초) — 실제 시간표 기반, 0이면 기본값 사용
  final int travelNextSec;  // 다음역까지 주행시간 (초) — 실제 시간표 기반, 0이면 거리 계산

  const StationInfo({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.transferLines = const [],
    this.isUnderground = true,
    this.dwellSec = 0,
    this.travelNextSec = 0,
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
  final int prevDepartureMs;  // 이전역 출발 시각 (epoch ms, 0=미제공)
  final int eventTimeMs;      // 이벤트 발생 시각 (epoch ms, 0=미제공)

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
    this.prevDepartureMs = 0,
    this.eventTimeMs = 0,
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
  /// trainStatus에 따른 열차의 역 기준 상대적 위치 비율 (0.0~1.0)
  /// 출발(2) → 역간이동(3) → 곧도착(0) → 정차중(1) 순서
  double get segmentProgress {
    switch (trainStatus) {
      case 2: return 0.0;   // 출발 — 현재역을 막 떠남
      case 3: return 0.3;   // 역간이동 — 다음역을 향해 이동 중
      case 0: return 0.8;   // 곧도착 — 다음역에 거의 도착
      case 1: return 1.0;   // 정차중 — 현재역에 서 있음
      default: return 0.5;
    }
  }

  /// 사람이 읽기 쉬운 상태 텍스트
  /// stationName 기준:
  ///   2=출발 → "{stationName} 출발"
  ///   3=역간이동 → "{stationName} 방면 이동중"
  ///   0=곧도착 → "{stationName} 곧 도착"
  ///   1=정차중 → "{stationName} 정차중"
  String get statusText {
    switch (trainStatus) {
      case 0: return '곧 도착';
      case 1: return '정차중';
      case 2: return '출발';
      case 3: return '이동중';
      default: return '운행중';
    }
  }

  /// 상세 상태 (역명 포함)
  String get statusDetailText {
    switch (trainStatus) {
      case 0: return '$stationName 곧 도착';
      case 1: return '$stationName 정차중';
      case 2: return '$stationName 출발';
      case 3: return '$stationName 방면 이동중';
      default: return '운행중';
    }
  }

  String get directionText => direction == 0 ? '상행' : '하행';

  /// 급행 유형 텍스트 (빈 문자열이면 일반)
  String get expressTypeText {
    switch (expressType) {
      case 1: return '급행';
      case 7: return '특급';
      default: return '';
    }
  }

  /// 급행 여부
  bool get isExpress => expressType != 0;
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
      case 0: return '곧 도착';
      case 1: return '정차중';
      case 2: return '출발';
      case 3: return '이전역 출발';
      case 4: return '이전역 곧 도착';
      case 5: return '이전역 정차중';
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
  final double altitude; // 3D 고도 (미터) — 지상: 30m, 지하: 0m
  final bool isUnderground; // 현재 지하 구간 여부
  final int direction;
  final String terminalName;
  final String stationName;
  final int trainStatus;
  final int expressType;
  final bool isLastTrain;
  final double bearing; // 열차 진행 방향 (지도 베어링)
  final double opacity; // 열차 투명도 (0.0~1.0, 텔레포트 페이드인용)

  const InterpolatedTrainPosition({
    required this.trainNo,
    required this.subwayId,
    required this.subwayName,
    required this.lat,
    required this.lng,
    this.altitude = 0,
    this.isUnderground = true,
    required this.direction,
    required this.terminalName,
    required this.stationName,
    required this.trainStatus,
    required this.expressType,
    required this.isLastTrain,
    required this.bearing,
    this.opacity = 1.0,
  });

  /// 상태 텍스트
  String get statusText {
    switch (trainStatus) {
      case 0: return '곧 도착';
      case 1: return '정차중';
      case 2: return '출발';
      case 3: return '이동중';
      default: return '운행중';
    }
  }

  /// 상세 상태 (역명 포함)
  String get statusDetailText {
    switch (trainStatus) {
      case 0: return '$stationName 곧 도착';
      case 1: return '$stationName 정차중';
      case 2: return '$stationName 출발';
      case 3: return '$stationName 방면 이동중';
      default: return '운행중';
    }
  }

  String get directionText => direction == 0 ? '상행' : '하행';

  /// 급행 유형 텍스트 (빈 문자열이면 일반)
  String get expressTypeText {
    switch (expressType) {
      case 1: return '급행';
      case 7: return '특급';
      default: return '';
    }
  }

  /// 급행 여부
  bool get isExpress => expressType != 0;
}

/// 지하철 지연/알림 정보
/// 실시간 도착정보의 배차간격 분석 + 키워드 탐지로 생성
class SubwayAlert {
  final String alertId;         // 알림 고유 ID
  final String subwayLineId;   // 노선 ID (1001, 1002 등)
  final String subwayLineName; // 노선명 (1호선 등)
  final String title;          // 알림 제목
  final String content;        // 알림 내용
  final String alertType;      // 알림 구분 (지연, 사고, 혼잡 등)
  final String beginTime;      // 이례 상황 시작 시각
  final String endTime;        // 이례 상황 종료 시각
  final DateTime receivedAt;   // 수신 시각
  final int delayMinutes;      // 추정 지연 시간 (분), 0이면 키워드만 감지

  const SubwayAlert({
    required this.alertId,
    required this.subwayLineId,
    required this.subwayLineName,
    required this.title,
    required this.content,
    required this.alertType,
    required this.beginTime,
    required this.endTime,
    required this.receivedAt,
    this.delayMinutes = 0,
  });

  /// 종료되지 않은 진행 중인 알림인지 확인
  bool get isActive => endTime.isEmpty || endTime == 'null' || endTime == '';

  /// 지연 관련 알림인지 확인
  bool get isDelay {
    if (delayMinutes > 0) return true;
    final lower = (title + content + alertType).toLowerCase();
    return lower.contains('지연') || lower.contains('delay') ||
           lower.contains('서행') || lower.contains('운행중지') ||
           lower.contains('운행 중지') || lower.contains('장애');
  }

  /// 표시용 지연 시간 텍스트
  String get delayText {
    if (delayMinutes <= 0) return alertType;
    return '약 $delayMinutes분 지연';
  }
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
    '1093': Color(0xFF8FC31F), // 서해선
    '1094': Color(0xFF6789CA), // 신림선
    '1081': Color(0xFF0054A6), // 경강선
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
    '1093': '서해선',
    '1094': '신림선',
    '1081': '경강선',
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MiniTokyo3D 방식: 순수 함수 기반 열차 위치 계산
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 하나의 열차가 역 A → 역 B를 이동하는 구간 정의.
/// 위치는 순수 함수: position = f(currentTimeMs, this segment)
/// 상태 누적 없음, 드리프트 없음, 텔레포트 없음.
class TrainSegment {
  final String trainNo;
  final String subwayId;    // 노선 ID (1001, 1002, ...)
  final String subwayName;  // 노선명
  final int direction;      // 0: 상행, 1: 하행
  final int expressType;    // 0: 일반, 1: 급행, 7: 특급
  final String terminalName;
  final bool isLastTrain;

  // 구간 시작/끝 (경로상 누적 거리, 미터)
  final double startDistM;
  final double endDistM;
  final String startStationName;
  final String endStationName;

  // 시각 (밀리초, epoch 기준)
  final int departureMs;  // 역 A 출발 시각
  final int arrivalMs;    // 역 B 도착 시각

  // 가속/감속 파라미터 (구간 생성 시 프리컴퓨트)
  final double accelTimeMs; // 가속 구간 시간 (ms)
  final double decelTimeMs; // 감속 구간 시간 (ms)
  final double cruiseSpeed; // 순항 속도 (정규화 단위/ms)

  // 지연 오프셋 (매 프레임 targetDelayMs를 향해 0.5%씩 이동)
  int delayMs;
  // API가 설정하는 목표 delay
  int targetDelayMs;
  // 다음 역 정차에서 적용할 보정
  int pendingCorrectionMs;

  // API 상태 고정 (짧은 보간 세그먼트에서 상태 깜빡임 방지)
  int? fixedStatus;         // null이면 progress 기반, 값 있으면 고정
  String? fixedStationName; // 고정 역명

  // 텔레포트 페이드인: 텔레포트 시점 (ms), 0이면 텔레포트 안 함
  int teleportAtMs = 0;
  static const int teleportFadeMs = 800; // 페이드인 시간

  // 역 목록 (다음 구간 생성용)
  final int fromStationIdx;
  final int toStationIdx;

  // 신뢰도 (비시간표 열차용)
  double confidence;

  TrainSegment({
    required this.trainNo,
    required this.subwayId,
    required this.subwayName,
    required this.direction,
    required this.expressType,
    required this.terminalName,
    required this.isLastTrain,
    required this.startDistM,
    required this.endDistM,
    required this.startStationName,
    required this.endStationName,
    required this.departureMs,
    required this.arrivalMs,
    required this.accelTimeMs,
    required this.decelTimeMs,
    required this.cruiseSpeed,
    this.delayMs = 0,
    this.targetDelayMs = 0,
    this.pendingCorrectionMs = 0,
    required this.fromStationIdx,
    required this.toStationIdx,
    this.confidence = 1.0,
  });

  /// 구간 총 소요시간 (ms)
  int get durationMs => arrivalMs - departureMs;

  /// MiniTokyo3D 핵심: 현재 시각 → 구간 내 진행률 (0.0~1.0)
  /// 순수 함수 — 동일 시각 = 동일 결과, 상태 없음
  double progress(int nowMs) {
    final effDep = departureMs + delayMs;
    final effArr = arrivalMs + delayMs;
    final duration = (effArr - effDep).toDouble();
    if (duration <= 0) return 1.0;

    final elapsed = (nowMs - effDep).clamp(0, effArr - effDep).toDouble();
    final remaining = duration - elapsed;

    if (elapsed < accelTimeMs) {
      // 가속 구간: t = (cruiseSpeed / accelTimeMs) * 0.5 * elapsed²
      return (cruiseSpeed / accelTimeMs) * 0.5 * elapsed * elapsed;
    } else if (remaining < decelTimeMs) {
      // 감속 구간: t = 1.0 - (cruiseSpeed / decelTimeMs) * 0.5 * remaining²
      return 1.0 - (cruiseSpeed / decelTimeMs) * 0.5 * remaining * remaining;
    } else {
      // 순항 구간: 선형
      final accelDist = cruiseSpeed * accelTimeMs * 0.5;
      return accelDist + cruiseSpeed * (elapsed - accelTimeMs);
    }
  }

  /// 현재 시각 → 경로상 누적 거리 (미터)
  double trackDistance(int nowMs) {
    final t = progress(nowMs).clamp(0.0, 1.0);
    return startDistM + (endDistM - startDistM) * t;
  }

  /// 구간이 완료되었는지 (도착 + 지연 반영)
  bool isComplete(int nowMs) => nowMs >= arrivalMs + delayMs;

  /// 정차(dwell) 중인지 (도착했지만 다음 구간 안 시작)
  bool isDwelling(int nowMs) => isComplete(nowMs);

  /// 현재 표시할 상태 코드
  int displayStatus(int nowMs) {
    if (fixedStatus != null) return fixedStatus!;
    final t = progress(nowMs);
    if (t >= 1.0) return 1; // 정차중
    if (t < 0.15) return 2; // 출발
    if (t > 0.85) return 0; // 곧 도착
    return 3; // 이동중
  }

  /// 현재 표시할 역명
  String displayStation(int nowMs) {
    if (fixedStationName != null) return fixedStationName!;
    return progress(nowMs) > 0.5 ? endStationName : startStationName;
  }

  /// 텔레포트 후 페이드인 opacity (0→1, 800ms)
  double displayOpacity(int nowMs) {
    if (teleportAtMs == 0) return 1.0;
    final elapsed = nowMs - teleportAtMs;
    if (elapsed >= teleportFadeMs) {
      teleportAtMs = 0; // 페이드인 완료
      return 1.0;
    }
    return (elapsed / teleportFadeMs).clamp(0.0, 1.0);
  }

  /// 팩토리: 소요시간(ms) + 거리(m) → 가감속 파라미터 자동 계산
  static TrainSegment create({
    required String trainNo,
    required String subwayId,
    required String subwayName,
    required int direction,
    int expressType = 0,
    String terminalName = '',
    bool isLastTrain = false,
    required double startDistM,
    required double endDistM,
    required String startStationName,
    required String endStationName,
    required int departureMs,
    required int arrivalMs,
    required int fromStationIdx,
    required int toStationIdx,
    int delayMs = 0,
    double confidence = 1.0,
  }) {
    final durationMs = (arrivalMs - departureMs).toDouble();
    if (durationMs <= 0) {
      return TrainSegment(
        trainNo: trainNo, subwayId: subwayId, subwayName: subwayName,
        direction: direction, expressType: expressType,
        terminalName: terminalName, isLastTrain: isLastTrain,
        startDistM: startDistM, endDistM: endDistM,
        startStationName: startStationName, endStationName: endStationName,
        departureMs: departureMs, arrivalMs: arrivalMs,
        accelTimeMs: 0, decelTimeMs: 0, cruiseSpeed: 0,
        delayMs: delayMs, fromStationIdx: fromStationIdx,
        toStationIdx: toStationIdx, confidence: confidence,
      );
    }

    // MiniTokyo3D 방식: 구간의 15%를 가속/감속에 할당
    const accelFrac = 0.15;
    final accelTimeMs = durationMs * accelFrac;
    final decelTimeMs = durationMs * accelFrac;
    // 순항 속도: 가속/감속 시간 절반을 빼고 남은 시간으로 전체 거리를 커버
    // cruiseSpeed * (duration - accelTime/2 - decelTime/2) = 1.0 (정규화)
    final cruiseDuration = durationMs - accelTimeMs / 2 - decelTimeMs / 2;
    final cruiseSpeed = cruiseDuration > 0 ? 1.0 / cruiseDuration : 1.0 / durationMs;

    return TrainSegment(
      trainNo: trainNo, subwayId: subwayId, subwayName: subwayName,
      direction: direction, expressType: expressType,
      terminalName: terminalName, isLastTrain: isLastTrain,
      startDistM: startDistM, endDistM: endDistM,
      startStationName: startStationName, endStationName: endStationName,
      departureMs: departureMs, arrivalMs: arrivalMs,
      accelTimeMs: accelTimeMs, decelTimeMs: decelTimeMs,
      cruiseSpeed: cruiseSpeed, delayMs: delayMs,
      fromStationIdx: fromStationIdx, toStationIdx: toStationIdx,
      confidence: confidence,
    );
  }
}