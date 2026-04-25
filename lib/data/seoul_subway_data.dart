/// 서울 지하철 노선별 역 좌표 데이터
/// MiniTokyo3D처럼 열차 위치를 노선 경로 위에 보간하기 위한 정적 데이터
///
/// 각 노선은 순서대로 정렬된 역 목록을 가지며,
/// 상행(direction=0)은 리스트 역순, 하행(direction=1)은 리스트 순서로 진행

import '../models/subway_models.dart';

class SeoulSubwayData {
  /// 노선 ID → API에서 사용하는 노선명 매핑
  static const Map<String, String> lineIdToApiName = {
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

  // ── 지상 구간 역 ID 목록 ──
  // 서울 지하철에서 지상으로 운행하는 구간의 역 ID
  // 여기에 포함되지 않은 역은 기본적으로 지하로 간주
  static const Set<String> surfaceStationIds = {
    // 1호선: 소요산 ~ 회기 (지상)
    '1001-100', '1001-101', '1001-102', '1001-103', '1001-104',
    '1001-105', '1001-106', '1001-107', '1001-108', '1001-109',
    '1001-110', '1001-111', '1001-112', '1001-113', '1001-114',
    '1001-115', '1001-116', '1001-117', '1001-118', '1001-119',
    '1001-120', '1001-121', '1001-122', '1001-123',
    // 1호선: 남영 ~ 신도림 (지상 고가)
    '1001-134', '1001-135', '1001-136', '1001-137', '1001-138',
    '1001-139', '1001-140',
    // 2호선: 성수 ~ 잠실나루 (지상 고가)
    '1002-210', '1002-211', '1002-212', '1002-213', '1002-214',
    // 2호선: 당산 ~ 합정 (한강 위 고가)
    '1002-236', '1002-237',
    // 3호선: 대화 ~ 지축 (지상)
    '1003-300', '1003-301', '1003-302', '1003-303', '1003-304',
    '1003-305', '1003-306', '1003-307', '1003-308', '1003-309',
    '1003-310',
    // 3호선: 옥수 (한강 위 고가)
    '1003-326',
    // 4호선: 동작 (한강 위)
    '1004-422',
    // 4호선: 남태령 (지상)
    '1004-425',
    // 7호선: 장암 ~ 도봉산 (지상)
    '1007-700', '1007-701',
    // 9호선: 개화 ~ 김포공항 (지상)
    '1009-900', '1009-901',
    // 9호선: 노량진 ~ 동작 (한강 위 고가)
    '1009-916', '1009-917', '1009-918', '1009-919',
    // 1호선 경부선: 구로 ~ 신창 (전구간 지상)
    '1001-141', '1001-142', '1001-143', '1001-144', '1001-145',
    '1001-146', '1001-147', '1001-148', '1001-149', '1001-150',
    '1001-151', '1001-152', '1001-153', '1001-154', '1001-155',
    '1001-156', '1001-157', '1001-158', '1001-159', '1001-160',
    '1001-161', '1001-162', '1001-163', '1001-164', '1001-165',
    '1001-166', '1001-167', '1001-168', '1001-169', '1001-170',
    '1001-171', '1001-172', '1001-173', '1001-174',
    // 4호선 안산선: 산본 ~ 오이도 (지상/고가)
    '1004-435', '1004-436', '1004-437', '1004-438', '1004-439',
    '1004-440', '1004-441', '1004-442', '1004-443', '1004-444',
    '1004-445', '1004-446', '1004-447',
    // 1호선 경인선: 구일 ~ 부천 (지상/고가)
    '1001-200', '1001-201', '1001-202', '1001-203', '1001-204',
    '1001-205', '1001-206',
    // 경의중앙선: 문산 ~ 수색 (지상), 서빙고~응봉 (지상/한강), 양원 ~ 지평 (지상)
    '1063-000', '1063-001', '1063-002', '1063-003', '1063-004',
    '1063-005', '1063-006', '1063-007', '1063-008', '1063-009',
    '1063-010', '1063-011', '1063-012', '1063-013', '1063-014',
    '1063-015', '1063-016', '1063-017',
    '1063-026', '1063-027', '1063-028', '1063-029', // 서빙고~응봉
    '1063-036', '1063-037', '1063-038', '1063-039', '1063-040',
    '1063-041', '1063-042', '1063-043', '1063-044', '1063-045',
    '1063-046', '1063-047', '1063-048', '1063-049', '1063-050',
    '1063-051', '1063-052', // 양원~지평
    // 공항철도: 김포공항 (지상), 영종~인천공항2터미널 (지상/고가)
    '1065-005', '1065-009', '1065-010', '1065-011', '1065-012', '1065-013',
    // 경춘선: 신내 ~ 춘천 (대부분 지상)
    '1067-005', '1067-006', '1067-007', '1067-008', '1067-009',
    '1067-010', '1067-011', '1067-012', '1067-013', '1067-014',
    '1067-015', '1067-016', '1067-017', '1067-018', '1067-019',
    '1067-020', '1067-021', '1067-022', '1067-023',
    // 수인분당선: 고색 ~ 인천 (수인선 구간 지상)
    '1075-037', '1075-038', '1075-039', '1075-040', '1075-041',
    '1075-042', '1075-043', '1075-044', '1075-045', '1075-046',
    '1075-047', '1075-048', '1075-049', '1075-050', '1075-051',
    '1075-052', '1075-053', '1075-054', '1075-055', '1075-056',
    '1075-057', '1075-058', '1075-059', '1075-060', '1075-061', '1075-062',
  };

  /// 해당 역이 지상인지 확인
  static bool isSurfaceStation(String stationId) {
    return surfaceStationIds.contains(stationId);
  }

  /// 역명으로 역 좌표 검색
  static StationInfo? findStation(String name) {
    // 1) 정확 매칭
    for (final line in allLines) {
      for (final station in line) {
        if (station.name == name) return station;
      }
    }
    // 2) 괄호 제거 매칭: "총신대입구(이수)" 검색 → "총신대입구(이수)" 찾음
    final clean = name.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (clean != name) {
      for (final line in allLines) {
        for (final station in line) {
          if (station.name == clean) return station;
        }
      }
    }
    // 3) 부역명/별칭 매칭: "이수" 검색 → "총신대입구(이수)" 찾음
    for (final line in allLines) {
      for (final station in line) {
        if (station.name.contains('($name)')) return station;
      }
    }
    // 4) 부분 매칭: "총신대입구" 검색 → "총신대입구(이수)" 찾음
    for (final line in allLines) {
      for (final station in line) {
        if (station.name.startsWith('$name(')) return station;
      }
    }
    return null;
  }

  /// 지선(branch) 키 → 부모 노선 ID 매핑
  static const Map<String, String> branchToLineId = {
    '1001_gyeongin': '1001',
    '1002_seongsu': '1002',
    '1002_sinjeong': '1002',
    '1005_macheon': '1005',
  };

  /// 특정 노선의 역 목록 가져오기
  static List<StationInfo> getLineStations(String lineId) {
    switch (lineId) {
      case '1001': return line1Stations;
      case '1002': return line2Stations;
      case '1003': return line3Stations;
      case '1004': return line4Stations;
      case '1005': return line5Stations;
      case '1006': return line6Stations;
      case '1007': return line7Stations;
      case '1008': return line8Stations;
      case '1009': return line9Stations;
      case '1063': return line1063Stations;
      case '1065': return line1065Stations;
      case '1067': return line1067Stations;
      case '1075': return line1075Stations;
      case '1077': return line1077Stations;
      case '1092': return line1092Stations;
      case '1032': return line1032Stations;
      case '1093': return line1093Stations;
      case '1094': return line1094Stations;
      case '1081': return line1081Stations;
      default: return [];
    }
  }

  /// 지선(branch) 역 목록 가져오기
  static List<StationInfo> getBranchStations(String branchKey) {
    switch (branchKey) {
      case '1001_gyeongin': return line1GyeonginStations;
      case '1002_seongsu': return line2SeongsuStations;
      case '1002_sinjeong': return line2SinjeongStations;
      case '1005_macheon': return line5MacheonStations;
      default: return [];
    }
  }

  /// 역명으로 해당 지선 키 찾기 (지선 전용 역이면 branchKey 반환, 아니면 null)
  /// 분기점 역(구로, 성수, 신도림, 강동 등)은 본선에도 있으므로 null 반환
  static String? findBranchForStation(String lineId, String stationName) {
    // 본선에 있는 역이면 본선 우선
    final mainStations = getLineStations(lineId);
    for (final s in mainStations) {
      if (s.name == stationName) return null;
    }
    // 본선에 없으면 지선 검색
    for (final branchKey in branchToLineId.keys) {
      if (!branchKey.startsWith('${lineId}_')) continue;
      final stations = getBranchStations(branchKey);
      for (final s in stations) {
        if (s.name == stationName) return branchKey;
      }
    }
    return null;
  }

  // ──────────────────────────────────────────
  // 1호선 급행/초급행(특급) 정차역 데이터
  // expressType: 0=일반, 1=급행, 7=특급(초급행)
  // ──────────────────────────────────────────

  /// 1호선 경부선 급행 정차역명 (A급행+B급행 합집합)
  /// 출처: https://icando99.com/entry/1호선-급행-노선도-정착역-시간표-알아보자
  /// A급행: 청량리→(각역)→가산디지털단지→금천구청→안양→금정→의왕→성균관대→수원→...
  /// B급행: 서울역→영등포→금천구청→안양→군포→의왕→성균관대→수원→...
  static const Set<String> line1ExpressStops = {
    // 경원선 급행 구간: 동두천~광운대 (여기만 역 건너뜀)
    '동두천', '동두천중앙', '지행', '덕정', '양주',
    '의정부', '회룡', '도봉산', '창동', '광운대',
    // 광운대~구로: 각역정차 구간 (급행도 전부 정차)
    '석계', '신이문', '외대앞', '회기',
    '청량리', '제기동', '신설동', '동묘앞', '동대문',
    '종로5가', '종로3가', '종각', '시청', '서울역',
    '남영', '용산', '노량진', '대방', '신길', '영등포',
    '신도림', '구로',
    // 경부선 급행 구간: 구로 이남 (여기서 역 건너뜀)
    // A급행: 가산디지털단지→금천구청→안양→금정→의왕→성균관대→수원
    // B급행: 금천구청→안양→군포→의왕→성균관대→수원
    '가산디지털단지', '금천구청', '안양', '금정',
    '군포', '의왕', '성균관대', '수원',
    // 수원 이남 급행
    '병점', '오산', '서정리', '평택', '성환', '두정', '천안',
    // 두정 이남 각역정차
    '봉명', '쌍용', '아산', '배방', '온양온천', '신창',
  };

  /// 1호선 특급(초급행) 정차역명
  /// B급행 기반: 서울역→영등포→금천구청→안양→수원→평택→천안→신창
  static const Set<String> line1SuperExpressStops = {
    '서울역', '영등포', '금천구청', '안양', '수원',
    '병점', '평택', '천안', '신창',
  };

  /// 1호선 경인선 급행 정차역명
  /// 급행: 구로→개봉→역곡→부천→송내→부평→동암→주안→제물포→동인천
  static const Set<String> line1GyeonginExpressStops = {
    '구로', '개봉', '역곡', '부천', '송내', '부평', '동암', '주안',
    '제물포', '동인천',
  };

  /// 1호선 경인선 특급 정차역명
  /// 특급: 용산→노량진→영등포→신도림→구로→역곡→부천→송내→부평→주안→동인천
  static const Set<String> line1GyeonginSuperExpressStops = {
    '구로', '역곡', '부천', '송내', '부평', '주안', '동인천',
  };

  /// 급행/초급행 열차의 정차역만 필터링하여 반환
  /// 일반 열차(expressType=0)이면 전체 역 목록 반환
  static List<StationInfo> getExpressStations(String lineId, int expressType) {
    if (expressType == 0) return getLineStations(lineId);

    if (lineId == '1001') {
      final stops = expressType == 7
          ? line1SuperExpressStops
          : line1ExpressStops;
      return line1Stations.where((s) => stops.contains(s.name)).toList();
    }
    // 다른 노선은 급행 데이터 미지원 → 전체 목록 반환
    return getLineStations(lineId);
  }

  /// 지선(branch) 급행 정차역 필터
  static List<StationInfo> getExpressBranchStations(String branchKey, int expressType) {
    if (expressType == 0) return getBranchStations(branchKey);

    if (branchKey == '1001_gyeongin') {
      final stops = expressType == 7
          ? line1GyeonginSuperExpressStops
          : line1GyeonginExpressStops;
      return line1GyeonginStations
          .where((s) => stops.contains(s.name))
          .toList();
    }
    return getBranchStations(branchKey);
  }

  /// 두 정차역 사이의 일반 역 구간 수 계산 (속도 계산용)
  /// 전체 역 목록에서 fromName ~ toName 사이에 몇 개의 일반 구간이 있는지 반환
  static int countNormalSegments(String lineId, String fromName, String toName) {
    final all = getLineStations(lineId);
    int fromIdx = -1, toIdx = -1;
    for (int i = 0; i < all.length; i++) {
      if (all[i].name == fromName) fromIdx = i;
      if (all[i].name == toName) toIdx = i;
    }
    if (fromIdx < 0 || toIdx < 0) return 1;
    return (toIdx - fromIdx).abs().clamp(1, all.length);
  }

  static List<List<StationInfo>> get allLines => [
    line1Stations, line2Stations, line3Stations, line4Stations,
    line5Stations, line6Stations, line7Stations, line8Stations, line9Stations,
    line1GyeonginStations, line2SeongsuStations, line2SinjeongStations,
    line5MacheonStations,
    line1063Stations, line1065Stations, line1067Stations,
    line1075Stations, line1077Stations, line1092Stations, line1032Stations,
    line1093Stations, line1094Stations, line1081Stations,
  ];

  // ──────────────────────────────────────────
  // 1호선 (소요산 ~ 인천/신창 방면, 서울 구간 주요역)
  // ──────────────────────────────────────────
  // dwellSec: 실제 정차시간(초), travelNextSec: 다음역까지 실제 주행시간(초)
  // 출처: 서울 열린데이터광장 OA-12034 시간표 API (SearchSTNTimeTableByIDService)
  static const List<StationInfo> line1Stations = [
    // ── 경원선 (소요산 → 청량리) ──
    StationInfo(id: '1001-100', name: '소요산', lat: 37.9472, lng: 127.0607, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1001-101', name: '동두천', lat: 37.9278, lng: 127.0547, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-102', name: '보산', lat: 37.9136, lng: 127.0572, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-103', name: '동두천중앙', lat: 37.9022, lng: 127.0564, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-104', name: '지행', lat: 37.8922, lng: 127.0556, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1001-105', name: '덕정', lat: 37.8444, lng: 127.0614, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-106', name: '덕계', lat: 37.8189, lng: 127.0564, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1001-107', name: '양주', lat: 37.7744, lng: 127.0447, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-108', name: '녹양', lat: 37.7589, lng: 127.0419, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-109', name: '가능', lat: 37.7483, lng: 127.0442, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-110', name: '의정부', lat: 37.7381, lng: 127.0459, transferLines: ['1092'], dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-111', name: '회룡', lat: 37.724416, lng: 127.04736, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-112', name: '망월사', lat: 37.7106, lng: 127.0474, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-113', name: '도봉산', lat: 37.6896, lng: 127.0447, transferLines: ['1007'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-114', name: '도봉', lat: 37.6790, lng: 127.0468, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-115', name: '방학', lat: 37.6690, lng: 127.0442, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-116', name: '창동', lat: 37.6530, lng: 127.0477, transferLines: ['1004'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-117', name: '녹천', lat: 37.6443, lng: 127.0516, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-118', name: '월계', lat: 37.6345, lng: 127.0583, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-119', name: '광운대', lat: 37.6249, lng: 127.0617, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-120', name: '석계', lat: 37.6158, lng: 127.0654, transferLines: ['1006'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-121', name: '신이문', lat: 37.6018, lng: 127.0673, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1001-122', name: '외대앞', lat: 37.5954, lng: 127.0630, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-123', name: '회기', lat: 37.5895, lng: 127.0585, transferLines: ['1063'], dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-124', name: '청량리', lat: 37.5804, lng: 127.0467, transferLines: ['1063', '1075'], dwellSec: 30, travelNextSec: 90),
    // ── 서울교통공사 1호선 (청량리 → 서울역) ──
    StationInfo(id: '1001-125', name: '제기동', lat: 37.5787, lng: 127.0375, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-126', name: '신설동', lat: 37.5752, lng: 127.0247, transferLines: ['1002', '1092'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-127', name: '동묘앞', lat: 37.5719, lng: 127.0165, transferLines: ['1006'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-128', name: '동대문', lat: 37.5711, lng: 127.0093, transferLines: ['1004'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-129', name: '종로5가', lat: 37.5706, lng: 127.0020, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-130', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1003', '1005'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-131', name: '종각', lat: 37.5702, lng: 126.9827, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-132', name: '시청', lat: 37.5647, lng: 126.9772, transferLines: ['1002'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-133', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1004', '1065', '1032'], dwellSec: 30, travelNextSec: 120),
    // ── 경부선 (서울역 → 구로 → 신창) ──
    StationInfo(id: '1001-134', name: '남영', lat: 37.5415, lng: 126.9717, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-135', name: '용산', lat: 37.5299, lng: 126.9648, transferLines: ['1063'], dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-136', name: '노량진', lat: 37.5132, lng: 126.9424, transferLines: ['1009'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-137', name: '대방', lat: 37.5134, lng: 126.9262, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1001-138', name: '신길', lat: 37.516862, lng: 126.917865, transferLines: ['1005'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-139', name: '영등포', lat: 37.5159, lng: 126.9075, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-140', name: '신도림', lat: 37.5088, lng: 126.8912, transferLines: ['1002'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-141', name: '구로', lat: 37.5033, lng: 126.8824, dwellSec: 60, travelNextSec: 240),
    StationInfo(id: '1001-142', name: '가산디지털단지', lat: 37.4816, lng: 126.8826, transferLines: ['1007'], dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-143', name: '독산', lat: 37.4669, lng: 126.8892, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-144', name: '금천구청', lat: 37.4568, lng: 126.8953, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-145', name: '석수', lat: 37.4341, lng: 126.9025, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-146', name: '관악', lat: 37.4192, lng: 126.9087, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-147', name: '안양', lat: 37.4006, lng: 126.9224, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-148', name: '명학', lat: 37.3846, lng: 126.9355, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-149', name: '금정', lat: 37.3717, lng: 126.9430, transferLines: ['1004'], dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-150', name: '군포', lat: 37.3536, lng: 126.9485, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-151', name: '당정', lat: 37.3434, lng: 126.9484, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-152', name: '의왕', lat: 37.3211, lng: 126.9481, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-153', name: '성균관대', lat: 37.3003, lng: 126.9711, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-154', name: '화서', lat: 37.283862, lng: 126.989627, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-155', name: '수원', lat: 37.2664, lng: 127.0002, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-156', name: '세류', lat: 37.2441, lng: 127.0137, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1001-157', name: '병점', lat: 37.2068, lng: 127.0331, dwellSec: 60, travelNextSec: 150),
    StationInfo(id: '1001-158', name: '세마', lat: 37.1875, lng: 127.0433, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-159', name: '오산대', lat: 37.1694, lng: 127.0631, dwellSec: 30, travelNextSec: 210),
    StationInfo(id: '1001-160', name: '오산', lat: 37.145885, lng: 127.06672, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-161', name: '진위', lat: 37.1094, lng: 127.0622, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-162', name: '송탄', lat: 37.0757, lng: 127.0543, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-163', name: '서정리', lat: 37.0575, lng: 127.0531, dwellSec: 30, travelNextSec: 510),
    StationInfo(id: '1001-163b', name: '지제', lat: 37.0188, lng: 127.0704, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1001-164', name: '평택', lat: 36.9907, lng: 127.0849, dwellSec: 30, travelNextSec: 390),
    StationInfo(id: '1001-165', name: '성환', lat: 36.9156, lng: 127.1278, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1001-166', name: '직산', lat: 36.8708, lng: 127.1439, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1001-167', name: '두정', lat: 36.834, lng: 127.1492, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1001-168', name: '천안', lat: 36.8112, lng: 127.1468, dwellSec: 30, travelNextSec: 120),
    // ── 장항선 (천안 → 신창) ──
    StationInfo(id: '1001-169', name: '봉명', lat: 36.8011, lng: 127.1356, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-170', name: '쌍용(나사렛대)', lat: 36.793759, lng: 127.1214, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-171', name: '아산', lat: 36.792, lng: 127.1051, dwellSec: 30, travelNextSec: 360),
    StationInfo(id: '1001-172', name: '배방', lat: 36.7778, lng: 127.0531, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1001-173', name: '온양온천', lat: 36.7806, lng: 127.0033, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1001-174', name: '신창', lat: 36.7694, lng: 126.9508, dwellSec: 30),
  ];

  // ──────────────────────────────────────────
  // 2호선 (순환선 - 시청 기점 시계방향)
  // ──────────────────────────────────────────
  static const List<StationInfo> line2Stations = [
    StationInfo(id: '1002-200', name: '시청', lat: 37.5647, lng: 126.9772, transferLines: ['1001']),
    StationInfo(id: '1002-201', name: '을지로입구', lat: 37.5660, lng: 126.9825, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-202', name: '을지로3가', lat: 37.5663, lng: 126.9920, dwellSec: 30, travelNextSec: 60, transferLines: ['1003']),
    StationInfo(id: '1002-203', name: '을지로4가', lat: 37.5669, lng: 126.9980, dwellSec: 30, travelNextSec: 90, transferLines: ['1005']),
    StationInfo(id: '1002-204', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, dwellSec: 60, travelNextSec: 90, transferLines: ['1004', '1005']),
    StationInfo(id: '1002-205', name: '신당', lat: 37.5659, lng: 127.0175, dwellSec: 30, travelNextSec: 60, transferLines: ['1006']),
    StationInfo(id: '1002-206', name: '상왕십리', lat: 37.5651, lng: 127.0290, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-207', name: '왕십리', lat: 37.5614, lng: 127.0378, dwellSec: 30, travelNextSec: 90, transferLines: ['1005', '1063', '1075']),
    StationInfo(id: '1002-208', name: '한양대', lat: 37.5558, lng: 127.0438, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-209', name: '뚝섬', lat: 37.5473, lng: 127.0474, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-210', name: '성수', lat: 37.5445, lng: 127.0558, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-211', name: '건대입구', lat: 37.5403, lng: 127.0695, dwellSec: 30, travelNextSec: 120, transferLines: ['1007']),
    StationInfo(id: '1002-212', name: '구의', lat: 37.5369, lng: 127.085, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-213', name: '강변', lat: 37.5350, lng: 127.0940, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1002-214', name: '잠실나루', lat: 37.5213, lng: 127.1039, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-215', name: '잠실', lat: 37.5133, lng: 127.1001, dwellSec: 30, travelNextSec: 90, transferLines: ['1008']),
    StationInfo(id: '1002-216', name: '잠실새내', lat: 37.5117, lng: 127.0867, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-217', name: '종합운동장', lat: 37.5108, lng: 127.0737, dwellSec: 30, travelNextSec: 90, transferLines: ['1009']),
    StationInfo(id: '1002-218', name: '삼성', lat: 37.5090, lng: 127.0637, dwellSec: 30, travelNextSec: 90, transferLines: ['1032']),
    StationInfo(id: '1002-219', name: '선릉', lat: 37.5046, lng: 127.0490, dwellSec: 60, travelNextSec: 90, transferLines: ['1075']),
    StationInfo(id: '1002-220', name: '역삼', lat: 37.5006, lng: 127.0368, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-221', name: '강남', lat: 37.4979, lng: 127.0276, dwellSec: 30, travelNextSec: 90, transferLines: ['1077']),
    StationInfo(id: '1002-222', name: '교대', lat: 37.4934, lng: 127.0146, dwellSec: 60, travelNextSec: 60, transferLines: ['1003']),
    StationInfo(id: '1002-223', name: '서초', lat: 37.4917, lng: 127.0072, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1002-224', name: '방배', lat: 37.4815, lng: 126.9977, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1002-225', name: '사당', lat: 37.4765, lng: 126.9816, dwellSec: 60, travelNextSec: 120, transferLines: ['1004']),
    StationInfo(id: '1002-226', name: '낙성대', lat: 37.4768, lng: 126.9637, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-227', name: '서울대입구', lat: 37.4812, lng: 126.9528, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-228', name: '봉천', lat: 37.4825, lng: 126.9419, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-229', name: '신림', lat: 37.4843, lng: 126.9296, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1002-230', name: '신대방', lat: 37.4878, lng: 126.9131, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-231', name: '구로디지털단지', lat: 37.4851, lng: 126.9015, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-232', name: '대림', lat: 37.4934, lng: 126.8968, dwellSec: 30, travelNextSec: 150, transferLines: ['1007']),
    StationInfo(id: '1002-233', name: '신도림', lat: 37.5088, lng: 126.8912, transferLines: ['1001']),
    StationInfo(id: '1002-234', name: '문래', lat: 37.5183, lng: 126.8949, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-235', name: '영등포구청', lat: 37.5248, lng: 126.8964, dwellSec: 30, travelNextSec: 90, transferLines: ['1005']),
    StationInfo(id: '1002-236', name: '당산', lat: 37.5340, lng: 126.9027, dwellSec: 30, travelNextSec: 150, transferLines: ['1009']),
    StationInfo(id: '1002-237', name: '합정', lat: 37.5494, lng: 126.9137, dwellSec: 30, travelNextSec: 90, transferLines: ['1006']),
    StationInfo(id: '1002-238', name: '홍대입구', lat: 37.5567, lng: 126.9236, dwellSec: 60, travelNextSec: 120, transferLines: ['1065']),
    StationInfo(id: '1002-239', name: '신촌', lat: 37.5554, lng: 126.9369, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-240', name: '이대', lat: 37.5569, lng: 126.9462, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1002-241', name: '아현', lat: 37.5575, lng: 126.9558, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1002-242', name: '충정로', lat: 37.5600, lng: 126.9635, dwellSec: 30, travelNextSec: 90, transferLines: ['1005']),
  ];

  // ──────────────────────────────────────────
  // 3호선 (대화 ~ 오금)
  // ──────────────────────────────────────────
  static const List<StationInfo> line3Stations = [
    StationInfo(id: '1003-300', name: '대화', lat: 37.6763, lng: 126.7475),
    StationInfo(id: '1003-301', name: '주엽', lat: 37.670072, lng: 126.761334),
    StationInfo(id: '1003-302', name: '정발산', lat: 37.659477, lng: 126.773359),
    StationInfo(id: '1003-303', name: '마두', lat: 37.652206, lng: 126.77762),
    StationInfo(id: '1003-304', name: '백석', lat: 37.643114, lng: 126.78787),
    StationInfo(id: '1003-305', name: '대곡', lat: 37.631626, lng: 126.811024, transferLines: ['1063']),
    StationInfo(id: '1003-306', name: '화정', lat: 37.634592, lng: 126.83265),
    StationInfo(id: '1003-307', name: '원당', lat: 37.653324, lng: 126.843041),
    StationInfo(id: '1003-308', name: '원흥', lat: 37.650658, lng: 126.872642),
    StationInfo(id: '1003-309', name: '삼송', lat: 37.653083, lng: 126.895558),
    StationInfo(id: '1003-310', name: '지축', lat: 37.6484, lng: 126.9133, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1003-311', name: '구파발', lat: 37.6369, lng: 126.9186, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-312', name: '연신내', lat: 37.6191, lng: 126.9210, dwellSec: 30, travelNextSec: 90, transferLines: ['1006']),
    StationInfo(id: '1003-313', name: '불광', lat: 37.6102, lng: 126.9296, dwellSec: 30, travelNextSec: 90, transferLines: ['1006']),
    StationInfo(id: '1003-314', name: '녹번', lat: 37.6007, lng: 126.9363, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-315', name: '홍제', lat: 37.5888, lng: 126.9436, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-316', name: '무악재', lat: 37.5831, lng: 126.9503, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-317', name: '독립문', lat: 37.574571, lng: 126.957748, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-318', name: '경복궁', lat: 37.5759, lng: 126.9736, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-319', name: '안국', lat: 37.5760, lng: 126.9855, dwellSec: 30, travelNextSec: 90, transferLines: ['1003']),
    StationInfo(id: '1003-320', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1001', '1005']),
    StationInfo(id: '1003-321', name: '을지로3가', lat: 37.5663, lng: 126.9920, transferLines: ['1002']),
    StationInfo(id: '1003-322', name: '충무로', lat: 37.5612, lng: 126.9944, dwellSec: 30, travelNextSec: 90, transferLines: ['1004']),
    StationInfo(id: '1003-323', name: '동대입구', lat: 37.559052, lng: 127.005602, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1003-324', name: '약수', lat: 37.5544, lng: 127.0108, dwellSec: 30, travelNextSec: 60, transferLines: ['1006']),
    StationInfo(id: '1003-325', name: '금호', lat: 37.5475, lng: 127.0175, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1003-326', name: '옥수', lat: 37.5402, lng: 127.0175, dwellSec: 30, travelNextSec: 120, transferLines: ['1063']),
    StationInfo(id: '1003-327', name: '압구정', lat: 37.5271, lng: 127.0285, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-328', name: '신사', lat: 37.5165, lng: 127.0217, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-329', name: '잠원', lat: 37.5136, lng: 127.0128, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-330', name: '고속터미널', lat: 37.5047, lng: 127.0049, dwellSec: 30, travelNextSec: 120, transferLines: ['1007', '1009']),
    StationInfo(id: '1003-331', name: '교대', lat: 37.4934, lng: 127.0146, transferLines: ['1002']),
    StationInfo(id: '1003-332', name: '남부터미널', lat: 37.4856, lng: 127.0163, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-333', name: '양재', lat: 37.4846, lng: 127.0355, dwellSec: 30, travelNextSec: 120, transferLines: ['1077']),
    StationInfo(id: '1003-334', name: '매봉', lat: 37.4872, lng: 127.0463, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-335', name: '도곡', lat: 37.4910, lng: 127.0556, dwellSec: 30, travelNextSec: 60, transferLines: ['1075']),
    StationInfo(id: '1003-336', name: '대치', lat: 37.4945, lng: 127.0632, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1003-337', name: '학여울', lat: 37.4970, lng: 127.0711, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-338', name: '대청', lat: 37.4927, lng: 127.0800, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1003-339', name: '일원', lat: 37.483681, lng: 127.08439, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1003-340', name: '수서', lat: 37.4874, lng: 127.1017, dwellSec: 30, travelNextSec: 120, transferLines: ['1075']),
    StationInfo(id: '1003-341', name: '가락시장', lat: 37.4926, lng: 127.1183, dwellSec: 30, travelNextSec: 60, transferLines: ['1008']),
    StationInfo(id: '1003-342', name: '경찰병원', lat: 37.4947, lng: 127.1249, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1003-343', name: '오금', lat: 37.5002, lng: 127.1280, dwellSec: 30, transferLines: ['1005']),
  ];

  // ──────────────────────────────────────────
  // 4호선 (당고개 ~ 오이도, 서울 구간)
  // ──────────────────────────────────────────
  static const List<StationInfo> line4Stations = [
    StationInfo(id: '1004-399', name: '불암산', lat: 37.6703, lng: 127.0791, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-400', name: '당고개', lat: 37.6701, lng: 127.0800, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-401', name: '상계', lat: 37.6610, lng: 127.0740, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-402', name: '노원', lat: 37.6553, lng: 127.0616, dwellSec: 30, travelNextSec: 90, transferLines: ['1007']),
    StationInfo(id: '1004-403', name: '창동', lat: 37.6530, lng: 127.0477, transferLines: ['1001']),
    StationInfo(id: '1004-404', name: '쌍문', lat: 37.6484, lng: 127.0349, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-405', name: '수유', lat: 37.6381, lng: 127.0253, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-406', name: '미아', lat: 37.6265, lng: 127.0265, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-407', name: '미아사거리', lat: 37.6133, lng: 127.0297, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-408', name: '길음', lat: 37.6031, lng: 127.0252, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-409', name: '성신여대입구', lat: 37.5924, lng: 127.0164, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-410', name: '한성대입구', lat: 37.5884, lng: 127.0065, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-411', name: '혜화', lat: 37.5821, lng: 127.0015, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-412', name: '동대문', lat: 37.5711, lng: 127.0093, transferLines: ['1001']),
    StationInfo(id: '1004-413', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, transferLines: ['1002', '1005']),
    StationInfo(id: '1004-414', name: '충무로', lat: 37.5612, lng: 126.9944, transferLines: ['1003']),
    StationInfo(id: '1004-415', name: '명동', lat: 37.5610, lng: 126.9858, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1004-416', name: '회현', lat: 37.5583, lng: 126.9784, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-417', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1001', '1065', '1032']),
    StationInfo(id: '1004-418', name: '숙대입구', lat: 37.5446, lng: 126.9720, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-419', name: '삼각지', lat: 37.5345, lng: 126.9737, dwellSec: 30, travelNextSec: 60, transferLines: ['1006']),
    StationInfo(id: '1004-420', name: '신용산', lat: 37.5307, lng: 126.9693, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-421', name: '이촌', lat: 37.522295, lng: 126.974733, dwellSec: 30, travelNextSec: 180, transferLines: ['1063']),
    StationInfo(id: '1004-422', name: '동작', lat: 37.5028, lng: 126.9803, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-423', name: '총신대입구(이수)', lat: 37.4868, lng: 126.9818, dwellSec: 30, travelNextSec: 90, transferLines: ['1007']),
    StationInfo(id: '1004-424', name: '사당', lat: 37.4765, lng: 126.9816, transferLines: ['1002']),
    StationInfo(id: '1004-425', name: '남태령', lat: 37.4644, lng: 126.9878, dwellSec: 30, travelNextSec: 150),
    // ── 과천선 (선바위 ~ 금정) ──
    StationInfo(id: '1004-426', name: '선바위', lat: 37.4519, lng: 127.0021, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-427', name: '경마공원', lat: 37.4442, lng: 127.0078, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-428', name: '대공원', lat: 37.4356, lng: 127.0064, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-429', name: '과천', lat: 37.433021, lng: 126.996568, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-430', name: '정부과천청사', lat: 37.426513, lng: 126.98978, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1004-431', name: '인덕원', lat: 37.401553, lng: 126.976715, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-432', name: '평촌', lat: 37.3943, lng: 126.9638, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-433', name: '범계', lat: 37.3902, lng: 126.9535, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1004-434', name: '금정', lat: 37.3717, lng: 126.9430, transferLines: ['1001']),
    // ── 안산선 (산본 ~ 오이도) ──
    StationInfo(id: '1004-435', name: '산본', lat: 37.3577, lng: 126.9325, dwellSec: 30, travelNextSec: 300),
    StationInfo(id: '1004-436', name: '수리산', lat: 37.3490, lng: 126.9251, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-437', name: '대야미', lat: 37.3283, lng: 126.9172, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1004-438', name: '반월', lat: 37.3122, lng: 126.9036, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-439', name: '상록수', lat: 37.3028, lng: 126.8664, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-440', name: '한대앞', lat: 37.3089, lng: 126.8542, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1004-441', name: '중앙', lat: 37.3161, lng: 126.8377, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-442', name: '고잔', lat: 37.3168, lng: 126.8231, dwellSec: 60, travelNextSec: 120),
    StationInfo(id: '1004-443', name: '초지', lat: 37.3206, lng: 126.8062, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-444', name: '안산', lat: 37.327082, lng: 126.788532, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-445', name: '신길온천', lat: 37.3375, lng: 126.7673, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1004-446', name: '정왕', lat: 37.3517, lng: 126.7428, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1004-447', name: '오이도', lat: 37.3619, lng: 126.7383, dwellSec: 30),
  ];

  // ──────────────────────────────────────────
  // 5호선 (방화 ~ 하남검단산/마천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line5Stations = [
    StationInfo(id: '1005-500', name: '방화', lat: 37.577446, lng: 126.812741, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-501', name: '개화산', lat: 37.5726, lng: 126.8048, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-502', name: '김포공항', lat: 37.5623, lng: 126.8010, dwellSec: 30, travelNextSec: 130, transferLines: ['1009', '1065']),
    StationInfo(id: '1005-503', name: '송정', lat: 37.561184, lng: 126.811973, dwellSec: 20, travelNextSec: 90),
    StationInfo(id: '1005-504', name: '마곡', lat: 37.5601, lng: 126.8264, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-505', name: '발산', lat: 37.558598, lng: 126.837668, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-506', name: '우장산', lat: 37.548768, lng: 126.836318, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-507', name: '화곡', lat: 37.5413, lng: 126.8395, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-508', name: '까치산', lat: 37.531768, lng: 126.846683, dwellSec: 20, travelNextSec: 110),
    StationInfo(id: '1005-509', name: '신정', lat: 37.5248, lng: 126.8541, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-510', name: '목동', lat: 37.526065, lng: 126.864931, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1005-511', name: '오목교', lat: 37.5239, lng: 126.8779, dwellSec: 20, travelNextSec: 80),
    StationInfo(id: '1005-512', name: '양평', lat: 37.5256, lng: 126.8861, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-513', name: '영등포구청', lat: 37.5248, lng: 126.8964, transferLines: ['1002']),
    StationInfo(id: '1005-514', name: '영등포시장', lat: 37.5229, lng: 126.9046, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-515', name: '신길', lat: 37.516862, lng: 126.917865, transferLines: ['1001']),
    StationInfo(id: '1005-516', name: '여의도', lat: 37.5215, lng: 126.9245, dwellSec: 20, travelNextSec: 80, transferLines: ['1009']),
    StationInfo(id: '1005-517', name: '여의나루', lat: 37.5271, lng: 126.9328, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1005-518', name: '마포', lat: 37.5392, lng: 126.9462, dwellSec: 40, travelNextSec: 70),
    StationInfo(id: '1005-519', name: '공덕', lat: 37.5440, lng: 126.9517, dwellSec: 20, travelNextSec: 80, transferLines: ['1006', '1063', '1065']),
    StationInfo(id: '1005-520', name: '애오개', lat: 37.5535, lng: 126.9571, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1005-521', name: '충정로', lat: 37.5600, lng: 126.9635, transferLines: ['1002']),
    StationInfo(id: '1005-522', name: '서대문', lat: 37.5653, lng: 126.9664, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-523', name: '광화문', lat: 37.5712, lng: 126.9763, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-524', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1001', '1003']),
    StationInfo(id: '1005-525', name: '을지로4가', lat: 37.5669, lng: 126.9980, transferLines: ['1002']),
    StationInfo(id: '1005-526', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, transferLines: ['1002', '1004']),
    StationInfo(id: '1005-527', name: '청구', lat: 37.5601, lng: 127.0141, dwellSec: 20, travelNextSec: 90, transferLines: ['1006']),
    StationInfo(id: '1005-528', name: '신금호', lat: 37.5549, lng: 127.0187, dwellSec: 20, travelNextSec: 80),
    StationInfo(id: '1005-529', name: '행당', lat: 37.5574, lng: 127.0299, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-530', name: '왕십리', lat: 37.5614, lng: 127.0378, transferLines: ['1002', '1063', '1075']),
    StationInfo(id: '1005-531', name: '마장', lat: 37.5658, lng: 127.0456, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-532', name: '답십리', lat: 37.5673, lng: 127.0529, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-533', name: '장한평', lat: 37.5611, lng: 127.0649, dwellSec: 40, travelNextSec: 100),
    StationInfo(id: '1005-534', name: '군자', lat: 37.5572, lng: 127.0795, dwellSec: 20, travelNextSec: 90, transferLines: ['1007']),
    StationInfo(id: '1005-535', name: '아차산', lat: 37.5518, lng: 127.0899, dwellSec: 20, travelNextSec: 110),
    StationInfo(id: '1005-536', name: '광나루', lat: 37.5459, lng: 127.1036, dwellSec: 30, travelNextSec: 130),
    StationInfo(id: '1005-537', name: '천호', lat: 37.5385, lng: 127.1231, dwellSec: 40, travelNextSec: 70, transferLines: ['1008']),
    StationInfo(id: '1005-538', name: '강동', lat: 37.5352, lng: 127.1323, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1005-539', name: '길동', lat: 37.5372, lng: 127.1410, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-540', name: '굽은다리', lat: 37.5455, lng: 127.1429, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-541', name: '명일', lat: 37.5514, lng: 127.1440, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-542', name: '고덕', lat: 37.5548, lng: 127.1547, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-543', name: '상일동', lat: 37.5575, lng: 127.1670, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-544', name: '강일', lat: 37.5573, lng: 127.1763, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1005-545', name: '미사', lat: 37.560927, lng: 127.193877, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1005-546', name: '하남풍산', lat: 37.552034, lng: 127.203864, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1005-547', name: '하남시청', lat: 37.54205, lng: 127.20612, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1005-548', name: '하남검단산', lat: 37.5398, lng: 127.2232, dwellSec: 30),
  ];

  // ──────────────────────────────────────────
  // 6호선 (응암순환 ~ 신내)
  // ──────────────────────────────────────────
  static const List<StationInfo> line6Stations = [
    StationInfo(id: '1006-600', name: '응암', lat: 37.598605, lng: 126.915577, dwellSec: 20, travelNextSec: 100),
    StationInfo(id: '1006-601', name: '역촌', lat: 37.6055, lng: 126.9222, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1006-602', name: '불광', lat: 37.6102, lng: 126.9296, transferLines: ['1003']),
    StationInfo(id: '1006-603', name: '독바위', lat: 37.618456, lng: 126.933031, dwellSec: 40, travelNextSec: 130),
    StationInfo(id: '1006-604', name: '연신내', lat: 37.6191, lng: 126.9210, transferLines: ['1003']),
    StationInfo(id: '1006-605', name: '구산', lat: 37.6133, lng: 126.9176, dwellSec: 30, travelNextSec: 230),
    StationInfo(id: '1006-606', name: '새절', lat: 37.591148, lng: 126.913629, dwellSec: 20, travelNextSec: 80),
    StationInfo(id: '1006-607', name: '증산', lat: 37.5842, lng: 126.9098, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1006-608', name: '디지털미디어시티', lat: 37.5772, lng: 126.8996, dwellSec: 30, travelNextSec: 80, transferLines: ['1063', '1065']),
    StationInfo(id: '1006-609', name: '월드컵경기장', lat: 37.5683, lng: 126.8973, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-610', name: '마포구청', lat: 37.5630, lng: 126.9015, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1006-611', name: '망원', lat: 37.5563, lng: 126.9103, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1006-612', name: '합정', lat: 37.5494, lng: 126.9137, transferLines: ['1002']),
    StationInfo(id: '1006-613', name: '상수', lat: 37.5478, lng: 126.9236, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-614', name: '광흥창', lat: 37.5478, lng: 126.9317, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1006-615', name: '대흥', lat: 37.5478, lng: 126.9405, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1006-616', name: '공덕', lat: 37.5440, lng: 126.9517, transferLines: ['1005', '1063', '1065']),
    StationInfo(id: '1006-617', name: '효창공원앞', lat: 37.5394, lng: 126.9610, dwellSec: 40, travelNextSec: 90, transferLines: ['1063']),
    StationInfo(id: '1006-618', name: '삼각지', lat: 37.5345, lng: 126.9737, transferLines: ['1004']),
    StationInfo(id: '1006-619', name: '녹사평', lat: 37.5344, lng: 126.9873, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-620', name: '이태원', lat: 37.5343, lng: 126.9945, dwellSec: 20, travelNextSec: 90),
    StationInfo(id: '1006-621', name: '한강진', lat: 37.5395, lng: 127.0020, dwellSec: 20, travelNextSec: 90),
    StationInfo(id: '1006-622', name: '버티고개', lat: 37.5479, lng: 127.0073, dwellSec: 40, travelNextSec: 70),
    StationInfo(id: '1006-623', name: '약수', lat: 37.5544, lng: 127.0108, transferLines: ['1003']),
    StationInfo(id: '1006-624', name: '청구', lat: 37.5601, lng: 127.0141, transferLines: ['1005']),
    StationInfo(id: '1006-625', name: '신당', lat: 37.5659, lng: 127.0175, transferLines: ['1002']),
    StationInfo(id: '1006-626', name: '동묘앞', lat: 37.5719, lng: 127.0165, transferLines: ['1001']),
    StationInfo(id: '1006-627', name: '창신', lat: 37.5795, lng: 127.0153, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-628', name: '보문', lat: 37.5863, lng: 127.0197, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-629', name: '안암', lat: 37.5862, lng: 127.0295, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-630', name: '고려대', lat: 37.5898, lng: 127.0359, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1006-631', name: '월곡', lat: 37.6003, lng: 127.0394, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1006-632', name: '상월곡', lat: 37.6060, lng: 127.0499, dwellSec: 20, travelNextSec: 70),
    StationInfo(id: '1006-633', name: '돌곶이', lat: 37.6107, lng: 127.0564, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1006-634', name: '석계', lat: 37.6158, lng: 127.0654, transferLines: ['1001']),
    StationInfo(id: '1006-635', name: '태릉입구', lat: 37.6173, lng: 127.0756, dwellSec: 30, travelNextSec: 80, transferLines: ['1007']),
    StationInfo(id: '1006-636', name: '화랑대', lat: 37.6200, lng: 127.0847, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1006-637', name: '봉화산', lat: 37.6177, lng: 127.0915, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1006-638', name: '신내', lat: 37.6133, lng: 127.1041, dwellSec: 30, transferLines: ['1063']),
  ];

  // ──────────────────────────────────────────
  // 7호선 (장암 ~ 석남)
  // ──────────────────────────────────────────
  static const List<StationInfo> line7Stations = [
    StationInfo(id: '1007-700', name: '장암', lat: 37.6980, lng: 127.0534, dwellSec: 30, travelNextSec: 270),
    StationInfo(id: '1007-701', name: '도봉산', lat: 37.6896, lng: 127.0447, transferLines: ['1001']),
    StationInfo(id: '1007-702', name: '수락산', lat: 37.6767, lng: 127.0553, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1007-703', name: '마들', lat: 37.6653, lng: 127.0578, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1007-704', name: '노원', lat: 37.6553, lng: 127.0616, transferLines: ['1004']),
    StationInfo(id: '1007-705', name: '중계', lat: 37.6445, lng: 127.0646, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1007-706', name: '하계', lat: 37.6387, lng: 127.0669, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1007-707', name: '공릉', lat: 37.6258, lng: 127.0731, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1007-708', name: '태릉입구', lat: 37.6173, lng: 127.0756, transferLines: ['1006']),
    StationInfo(id: '1007-709', name: '먹골', lat: 37.6102, lng: 127.0776, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1007-710', name: '중화', lat: 37.6023, lng: 127.0811, dwellSec: 30, travelNextSec: 110),
    StationInfo(id: '1007-711', name: '상봉', lat: 37.5962, lng: 127.0855, dwellSec: 30, travelNextSec: 70, transferLines: ['1063']),
    StationInfo(id: '1007-712', name: '면목', lat: 37.588, lng: 127.0876, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1007-713', name: '사가정', lat: 37.5786, lng: 127.0878, dwellSec: 20, travelNextSec: 70),
    StationInfo(id: '1007-714', name: '용마산', lat: 37.5730, lng: 127.0868, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1007-715', name: '중곡', lat: 37.5657, lng: 127.0851, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1007-716', name: '군자', lat: 37.5572, lng: 127.0795, transferLines: ['1005']),
    StationInfo(id: '1007-717', name: '어린이대공원(세종대)', lat: 37.5482, lng: 127.0761, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1007-718', name: '건대입구', lat: 37.5403, lng: 127.0695, transferLines: ['1002']),
    StationInfo(id: '1007-719', name: '뚝섬유원지', lat: 37.5313, lng: 127.0671, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1007-720', name: '청담', lat: 37.5197, lng: 127.0540, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1007-721', name: '강남구청', lat: 37.5172, lng: 127.0410, dwellSec: 30, travelNextSec: 70, transferLines: ['1075']),
    StationInfo(id: '1007-722', name: '학동', lat: 37.5148, lng: 127.0316, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1007-723', name: '논현', lat: 37.5113, lng: 127.0219, dwellSec: 20, travelNextSec: 70),
    StationInfo(id: '1007-724', name: '반포', lat: 37.5081, lng: 127.0118, dwellSec: 40, travelNextSec: 90),
    StationInfo(id: '1007-725', name: '고속터미널', lat: 37.5047, lng: 127.0049, transferLines: ['1003', '1009']),
    StationInfo(id: '1007-726', name: '내방', lat: 37.487618, lng: 126.993513, dwellSec: 40, travelNextSec: 90),
    StationInfo(id: '1007-727', name: '총신대입구(이수)', lat: 37.4868, lng: 126.9818, transferLines: ['1004']),
    StationInfo(id: '1007-728', name: '남성', lat: 37.4844, lng: 126.9725, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1007-729', name: '숭실대입구', lat: 37.4966, lng: 126.9535, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1007-730', name: '상도', lat: 37.5037, lng: 126.9473, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1007-731', name: '장승배기', lat: 37.5051, lng: 126.9394, dwellSec: 30, travelNextSec: 110),
    StationInfo(id: '1007-732', name: '신대방삼거리', lat: 37.5012, lng: 126.9290, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1007-733', name: '보라매', lat: 37.4985, lng: 126.9202, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1007-734', name: '신풍', lat: 37.5001, lng: 126.9096, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1007-735', name: '대림', lat: 37.4934, lng: 126.8968, transferLines: ['1002']),
    StationInfo(id: '1007-736', name: '남구로', lat: 37.4859, lng: 126.8877, dwellSec: 30, travelNextSec: 80),
    StationInfo(id: '1007-737', name: '가산디지털단지', lat: 37.4820, lng: 126.8826, transferLines: ['1001']),
    StationInfo(id: '1007-738', name: '철산', lat: 37.4756, lng: 126.8695, dwellSec: 30, travelNextSec: 110),
    StationInfo(id: '1007-739', name: '광명사거리', lat: 37.4787, lng: 126.8570, dwellSec: 20, travelNextSec: 120),
    StationInfo(id: '1007-740', name: '천왕', lat: 37.486637, lng: 126.838713, dwellSec: 30, travelNextSec: 140),
    StationInfo(id: '1007-741', name: '온수', lat: 37.4919, lng: 126.8248, transferLines: ['1001']),
    // ── 부천 연장 (까치울 ~ 석남) ──
    StationInfo(id: '1007-742', name: '까치울', lat: 37.506207, lng: 126.810939),
    StationInfo(id: '1007-743', name: '부천종합운동장', lat: 37.5055, lng: 126.7975),
    StationInfo(id: '1007-744', name: '춘의', lat: 37.5047, lng: 126.7850),
    StationInfo(id: '1007-745', name: '신중동', lat: 37.503048, lng: 126.77596),
    StationInfo(id: '1007-746', name: '부천시청', lat: 37.5050, lng: 126.7619),
    StationInfo(id: '1007-747', name: '상동', lat: 37.5059, lng: 126.7525),
    StationInfo(id: '1007-748', name: '삼산체육관', lat: 37.506411, lng: 126.742153),
    StationInfo(id: '1007-749', name: '석남', lat: 37.5062, lng: 126.6762),
  ];

  // ──────────────────────────────────────────
  // 8호선 (암사 ~ 모란)
  // ──────────────────────────────────────────
  static const List<StationInfo> line8Stations = [
    StationInfo(id: '1008-790', name: '별내', lat: 37.6423, lng: 127.1276, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1008-791', name: '다산', lat: 37.6243, lng: 127.1497, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1008-792', name: '동구릉', lat: 37.6111, lng: 127.1379, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1008-793', name: '구리', lat: 37.6026, lng: 127.1407, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1008-794', name: '장자호수공원', lat: 37.5874, lng: 127.1379, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1008-795', name: '암사역사공원', lat: 37.5570, lng: 127.1370, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1008-800', name: '암사', lat: 37.5499, lng: 127.1275, dwellSec: 30, travelNextSec: 180),
    StationInfo(id: '1008-801', name: '천호', lat: 37.5385, lng: 127.1231, transferLines: ['1005']),
    StationInfo(id: '1008-802', name: '강동구청', lat: 37.5302, lng: 127.1221, dwellSec: 40, travelNextSec: 80),
    StationInfo(id: '1008-803', name: '몽촌토성', lat: 37.5175, lng: 127.1126, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1008-804', name: '잠실', lat: 37.5133, lng: 127.1001, transferLines: ['1002']),
    StationInfo(id: '1008-805', name: '석촌', lat: 37.5050, lng: 127.1049, dwellSec: 40, travelNextSec: 110, transferLines: ['1009']),
    StationInfo(id: '1008-806', name: '송파', lat: 37.5002, lng: 127.1098, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1008-807', name: '가락시장', lat: 37.4926, lng: 127.1183, transferLines: ['1003']),
    StationInfo(id: '1008-808', name: '문정', lat: 37.4843, lng: 127.1233, dwellSec: 40, travelNextSec: 70),
    StationInfo(id: '1008-809', name: '장지', lat: 37.4782, lng: 127.1260, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1008-810', name: '복정', lat: 37.4713, lng: 127.1265, dwellSec: 40, travelNextSec: 70, transferLines: ['1075']),
    StationInfo(id: '1008-811', name: '남위례', lat: 37.4624, lng: 127.1398, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1008-811', name: '산성', lat: 37.457122, lng: 127.149908, dwellSec: 30, travelNextSec: 240),
    StationInfo(id: '1008-812', name: '남한산성입구', lat: 37.4492, lng: 127.1588, dwellSec: 30, travelNextSec: 130),
    StationInfo(id: '1008-813', name: '단대오거리', lat: 37.4445, lng: 127.1577, dwellSec: 30, travelNextSec: 70),
    StationInfo(id: '1008-814', name: '신흥', lat: 37.4415, lng: 127.1489, dwellSec: 20, travelNextSec: 70),
    StationInfo(id: '1008-815', name: '수진', lat: 37.4362, lng: 127.1401, dwellSec: 20, travelNextSec: 70),
    StationInfo(id: '1008-816', name: '모란', lat: 37.434, lng: 127.1303, dwellSec: 20, transferLines: ['1075']),
  ];

  // ──────────────────────────────────────────
  // 9호선 (개화 ~ 중앙보훈병원)
  // ──────────────────────────────────────────
  static const List<StationInfo> line9Stations = [
    StationInfo(id: '1009-900', name: '개화', lat: 37.578608, lng: 126.798153, dwellSec: 30, travelNextSec: 280),
    StationInfo(id: '1009-901', name: '김포공항', lat: 37.5623, lng: 126.8010, transferLines: ['1005', '1065']),
    StationInfo(id: '1009-902', name: '공항시장', lat: 37.5624, lng: 126.809, dwellSec: 25, travelNextSec: 75),
    StationInfo(id: '1009-903', name: '신방화', lat: 37.567532, lng: 126.816601, dwellSec: 30, travelNextSec: 110),
    StationInfo(id: '1009-904', name: '마곡나루', lat: 37.566778, lng: 126.82731, dwellSec: 25, travelNextSec: 140, transferLines: ['1065']),
    StationInfo(id: '1009-905', name: '양천향교', lat: 37.568381, lng: 126.841333, dwellSec: 30, travelNextSec: 125),
    StationInfo(id: '1009-906', name: '가양', lat: 37.5616, lng: 126.8569, dwellSec: 25, travelNextSec: 95),
    StationInfo(id: '1009-907', name: '증미', lat: 37.5566, lng: 126.863, dwellSec: 25, travelNextSec: 95),
    StationInfo(id: '1009-908', name: '등촌', lat: 37.5495, lng: 126.8676, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1009-909', name: '염창', lat: 37.5471, lng: 126.8738, dwellSec: 25, travelNextSec: 95),
    StationInfo(id: '1009-910', name: '신목동', lat: 37.5449, lng: 126.8810, dwellSec: 25, travelNextSec: 115),
    StationInfo(id: '1009-911', name: '선유도', lat: 37.5392, lng: 126.8913, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1009-912', name: '당산', lat: 37.5340, lng: 126.9027, transferLines: ['1002']),
    StationInfo(id: '1009-913', name: '국회의사당', lat: 37.5283, lng: 126.9178, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1009-914', name: '여의도', lat: 37.5215, lng: 126.9245, transferLines: ['1005']),
    StationInfo(id: '1009-915', name: '샛강', lat: 37.5170, lng: 126.9310, dwellSec: 30, travelNextSec: 110),
    StationInfo(id: '1009-916', name: '노량진', lat: 37.5132, lng: 126.9424, transferLines: ['1001']),
    StationInfo(id: '1009-917', name: '노들', lat: 37.5127, lng: 126.9506, dwellSec: 25, travelNextSec: 100),
    StationInfo(id: '1009-918', name: '흑석', lat: 37.5082, lng: 126.9634, dwellSec: 30, travelNextSec: 135),
    StationInfo(id: '1009-919', name: '동작', lat: 37.502852, lng: 126.980347, transferLines: ['1004']),
    StationInfo(id: '1009-920', name: '구반포', lat: 37.5018, lng: 126.9891, dwellSec: 25, travelNextSec: 85),
    StationInfo(id: '1009-921', name: '신반포', lat: 37.5038, lng: 126.9973, dwellSec: 30, travelNextSec: 95),
    StationInfo(id: '1009-922', name: '고속터미널', lat: 37.5047, lng: 127.0049, transferLines: ['1003', '1007']),
    StationInfo(id: '1009-923', name: '사평', lat: 37.5040, lng: 127.0135, dwellSec: 30, travelNextSec: 100),
    StationInfo(id: '1009-924', name: '신논현', lat: 37.5044, lng: 127.0247, dwellSec: 25, travelNextSec: 90, transferLines: ['1077']),
    StationInfo(id: '1009-925', name: '언주', lat: 37.5073, lng: 127.0343, dwellSec: 30, travelNextSec: 85),
    StationInfo(id: '1009-926', name: '선정릉', lat: 37.5104, lng: 127.0432, dwellSec: 25, travelNextSec: 100),
    StationInfo(id: '1009-927', name: '삼성중앙', lat: 37.5132, lng: 127.0543, dwellSec: 30, travelNextSec: 95),
    StationInfo(id: '1009-928', name: '봉은사', lat: 37.5139, lng: 127.0631, dwellSec: 30, travelNextSec: 125),
    StationInfo(id: '1009-929', name: '종합운동장', lat: 37.5108, lng: 127.0737, transferLines: ['1002']),
    StationInfo(id: '1009-930', name: '삼전', lat: 37.504738, lng: 127.088025, dwellSec: 25, travelNextSec: 90),
    StationInfo(id: '1009-931', name: '석촌고분', lat: 37.5041, lng: 127.0966, dwellSec: 30, travelNextSec: 85),
    StationInfo(id: '1009-932', name: '석촌', lat: 37.5050, lng: 127.1049, transferLines: ['1008']),
    StationInfo(id: '1009-933', name: '송파나루', lat: 37.5084, lng: 127.1110, dwellSec: 25, travelNextSec: 85),
    StationInfo(id: '1009-934', name: '한성백제', lat: 37.516404, lng: 127.116503, dwellSec: 30, travelNextSec: 125),
    StationInfo(id: '1009-935', name: '올림픽공원', lat: 37.5161, lng: 127.1310, dwellSec: 25, travelNextSec: 100, transferLines: ['1005']),
    StationInfo(id: '1009-936', name: '둔촌오륜', lat: 37.5204, lng: 127.1400, dwellSec: 30, travelNextSec: 140),
    StationInfo(id: '1009-937', name: '중앙보훈병원', lat: 37.529191, lng: 127.148739, dwellSec: 30),
  ];

  // ──────────────────────────────────────────
  // 1호선 경인선 지선 (구로 → 인천)
  // ──────────────────────────────────────────
  // 경인선 시간표 데이터: 서울 열린데이터광장 API 기반
  static const List<StationInfo> line1GyeonginStations = [
    StationInfo(id: '1001-141', name: '구로', lat: 37.5033, lng: 126.8824, dwellSec: 60, travelNextSec: 120),
    StationInfo(id: '1001-200', name: '구일', lat: 37.4964, lng: 126.8702, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-201', name: '개봉', lat: 37.494594, lng: 126.85968, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-202', name: '오류동', lat: 37.4943, lng: 126.8447, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-203', name: '온수', lat: 37.492433, lng: 126.824086, transferLines: ['1007'], dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-204', name: '역곡', lat: 37.4853, lng: 126.8124, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-205', name: '소사', lat: 37.482753, lng: 126.79544, dwellSec: 30, travelNextSec: 60),
    StationInfo(id: '1001-206', name: '부천', lat: 37.48405, lng: 126.782686, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-207', name: '중동', lat: 37.486562, lng: 126.764843, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-208', name: '송내', lat: 37.4876, lng: 126.753664, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-209', name: '부개', lat: 37.488418, lng: 126.74109, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-210', name: '부평', lat: 37.489445, lng: 126.724506, dwellSec: 30, travelNextSec: 150),
    StationInfo(id: '1001-211', name: '백운', lat: 37.483664, lng: 126.707704, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-212', name: '동암', lat: 37.471408, lng: 126.702896, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-213', name: '간석', lat: 37.464737, lng: 126.694181, dwellSec: 30, travelNextSec: 120),
    StationInfo(id: '1001-214', name: '주안', lat: 37.4648, lng: 126.6823, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-215', name: '도화', lat: 37.4662, lng: 126.6665, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-216', name: '제물포', lat: 37.466769, lng: 126.656666, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-217', name: '도원', lat: 37.468446, lng: 126.642706, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-218', name: '동인천', lat: 37.4752, lng: 126.6329, dwellSec: 30, travelNextSec: 90),
    StationInfo(id: '1001-219', name: '인천', lat: 37.4764, lng: 126.6170, dwellSec: 30),
  ];

  // ──────────────────────────────────────────
  // 2호선 성수지선 (성수 → 신설동)
  // ──────────────────────────────────────────
  static const List<StationInfo> line2SeongsuStations = [
    StationInfo(id: '1002-210', name: '성수', lat: 37.5445, lng: 127.0558),
    StationInfo(id: '1002-300', name: '용답', lat: 37.5642, lng: 127.0498),
    StationInfo(id: '1002-301', name: '신답', lat: 37.5702, lng: 127.0467),
    StationInfo(id: '1002-302', name: '용두', lat: 37.5740, lng: 127.0382),
    StationInfo(id: '1002-303', name: '신설동', lat: 37.5752, lng: 127.0247, transferLines: ['1001', '1092']),
  ];

  // ──────────────────────────────────────────
  // 2호선 신정지선 (신도림 → 까치산)
  // ──────────────────────────────────────────
  static const List<StationInfo> line2SinjeongStations = [
    StationInfo(id: '1002-233', name: '신도림', lat: 37.5088, lng: 126.8912, transferLines: ['1001']),
    StationInfo(id: '1002-400', name: '도림천', lat: 37.5159, lng: 126.8831),
    StationInfo(id: '1002-401', name: '양천구청', lat: 37.512398, lng: 126.865819),
    StationInfo(id: '1002-402', name: '신정네거리', lat: 37.520074, lng: 126.852912),
    StationInfo(id: '1002-403', name: '까치산', lat: 37.5314, lng: 126.8467, transferLines: ['1005']),
  ];

  // ──────────────────────────────────────────
  // 5호선 마천지선 (강동 → 마천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line5MacheonStations = [
    StationInfo(id: '1005-538', name: '강동', lat: 37.5352, lng: 127.1323),
    StationInfo(id: '1005-600', name: '둔촌동', lat: 37.5265, lng: 127.1355),
    StationInfo(id: '1005-601', name: '올림픽공원', lat: 37.5161, lng: 127.1310, transferLines: ['1009']),
    StationInfo(id: '1005-602', name: '방이', lat: 37.5083, lng: 127.1264),
    StationInfo(id: '1005-603', name: '오금', lat: 37.5002, lng: 127.1280, transferLines: ['1003']),
    StationInfo(id: '1005-604', name: '개롱', lat: 37.498079, lng: 127.13482),
    StationInfo(id: '1005-605', name: '거여', lat: 37.493105, lng: 127.14415),
    StationInfo(id: '1005-606', name: '마천', lat: 37.4945, lng: 127.1524),
  ];

  // ──────────────────────────────────────────
  // 경의중앙선 (문산 ~ 지평)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1063Stations = [
    StationInfo(id: '1063-000', name: '문산', lat: 37.854619, lng: 126.788047),
    StationInfo(id: '1063-001', name: '파주', lat: 37.815298, lng: 126.792783),
    StationInfo(id: '1063-002', name: '월롱', lat: 37.796188, lng: 126.792587),
    StationInfo(id: '1063-003', name: '금촌', lat: 37.766217, lng: 126.774644),
    StationInfo(id: '1063-004', name: '금릉', lat: 37.7536, lng: 126.7636),
    StationInfo(id: '1063-005', name: '운정', lat: 37.725826, lng: 126.767257),
    StationInfo(id: '1063-006', name: '야당', lat: 37.712327, lng: 126.761356),
    StationInfo(id: '1063-007', name: '탄현', lat: 37.694023, lng: 126.761086),
    StationInfo(id: '1063-008', name: '일산', lat: 37.682077, lng: 126.769846, transferLines: ['1003']),
    StationInfo(id: '1063-009', name: '풍산', lat: 37.672346, lng: 126.786243),
    StationInfo(id: '1063-010', name: '백마', lat: 37.6604, lng: 126.7928),
    StationInfo(id: '1063-011', name: '곡산', lat: 37.645676, lng: 126.801762),
    StationInfo(id: '1063-012', name: '대곡', lat: 37.631626, lng: 126.811024, transferLines: ['1003', '1032']),
    StationInfo(id: '1063-013', name: '능곡', lat: 37.618808, lng: 126.820783),
    StationInfo(id: '1063-014', name: '행신', lat: 37.612102, lng: 126.834146),
    StationInfo(id: '1063-015', name: '강매', lat: 37.612314, lng: 126.843223),
    StationInfo(id: '1063-016', name: '한국항공대', lat: 37.6028, lng: 126.8684),
    StationInfo(id: '1063-017', name: '수색', lat: 37.580842, lng: 126.895611),
    StationInfo(id: '1063-018', name: '디지털미디어시티', lat: 37.5786, lng: 126.8995, transferLines: ['1006', '1065']),
    StationInfo(id: '1063-019', name: '가좌', lat: 37.568491, lng: 126.915487),
    StationInfo(id: '1063-020', name: '홍대입구', lat: 37.55679, lng: 126.923708, transferLines: ['1002', '1065']),
    StationInfo(id: '1063-021', name: '서강대', lat: 37.551881, lng: 126.935711),
    StationInfo(id: '1063-022', name: '공덕', lat: 37.542596, lng: 126.952099, transferLines: ['1005', '1006', '1065']),
    StationInfo(id: '1063-023', name: '효창공원앞', lat: 37.538579, lng: 126.96221, transferLines: ['1006']),
    StationInfo(id: '1063-024', name: '용산', lat: 37.529849, lng: 126.964561, transferLines: ['1001']),
    StationInfo(id: '1063-025', name: '이촌', lat: 37.522295, lng: 126.974733, transferLines: ['1004']),
    StationInfo(id: '1063-026', name: '서빙고', lat: 37.519594, lng: 126.988537),
    StationInfo(id: '1063-027', name: '한남', lat: 37.52943, lng: 127.009169),
    StationInfo(id: '1063-028', name: '옥수', lat: 37.5437, lng: 127.0160, transferLines: ['1003']),
    StationInfo(id: '1063-029', name: '응봉', lat: 37.549946, lng: 127.034538),
    StationInfo(id: '1063-030', name: '왕십리', lat: 37.561238, lng: 127.036954, transferLines: ['1002', '1005', '1075']),
    StationInfo(id: '1063-031', name: '청량리', lat: 37.5824, lng: 127.0439, transferLines: ['1001', '1075', '1067']),
    StationInfo(id: '1063-032', name: '회기', lat: 37.58946, lng: 127.057583, transferLines: ['1001', '1067']),
    StationInfo(id: '1063-033', name: '중랑', lat: 37.594917, lng: 127.076116, transferLines: ['1067']),
    StationInfo(id: '1063-034', name: '상봉', lat: 37.5985, lng: 127.0836, transferLines: ['1007', '1067']),
    StationInfo(id: '1063-035', name: '망우', lat: 37.59955, lng: 127.091909, transferLines: ['1067']),
    StationInfo(id: '1063-036', name: '양원', lat: 37.606596, lng: 127.107906),
    StationInfo(id: '1063-037', name: '구리', lat: 37.603392, lng: 127.143869),
    StationInfo(id: '1063-038', name: '도농', lat: 37.608806, lng: 127.161153),
    StationInfo(id: '1063-039', name: '양정', lat: 37.6067, lng: 127.1925),
    StationInfo(id: '1063-040', name: '덕소', lat: 37.586781, lng: 127.208832),
    StationInfo(id: '1063-041', name: '도심', lat: 37.579622, lng: 127.222672),
    StationInfo(id: '1063-042', name: '팔당', lat: 37.547371, lng: 127.243939),
    StationInfo(id: '1063-043', name: '운길산', lat: 37.554669, lng: 127.310115),
    StationInfo(id: '1063-044', name: '양수', lat: 37.545981, lng: 127.329098),
    StationInfo(id: '1063-045', name: '신원', lat: 37.525545, lng: 127.372921),
    StationInfo(id: '1063-046', name: '국수', lat: 37.516169, lng: 127.399367),
    StationInfo(id: '1063-047', name: '아신', lat: 37.51382, lng: 127.443173),
    StationInfo(id: '1063-048', name: '오빈', lat: 37.506062, lng: 127.473868),
    StationInfo(id: '1063-049', name: '양평', lat: 37.492773, lng: 127.491837),
    StationInfo(id: '1063-050', name: '원덕', lat: 37.468672, lng: 127.547076),
    StationInfo(id: '1063-051', name: '용문', lat: 37.48223, lng: 127.594647),
    StationInfo(id: '1063-052', name: '지평', lat: 37.476393, lng: 127.629874),
  ];

  // ──────────────────────────────────────────
  // 공항철도 (서울역 ~ 인천공항2터미널)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1065Stations = [
    StationInfo(id: '1065-000', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1001', '1004', '1032']),
    StationInfo(id: '1065-001', name: '공덕', lat: 37.542596, lng: 126.952099, transferLines: ['1005', '1006', '1063']),
    StationInfo(id: '1065-002', name: '홍대입구', lat: 37.55679, lng: 126.923708, transferLines: ['1002', '1063']),
    StationInfo(id: '1065-003', name: '디지털미디어시티', lat: 37.5786, lng: 126.8995, transferLines: ['1006', '1063']),
    StationInfo(id: '1065-004', name: '마곡나루', lat: 37.566778, lng: 126.82731, transferLines: ['1009']),
    StationInfo(id: '1065-005', name: '김포공항', lat: 37.5617, lng: 126.8041, transferLines: ['1005', '1009']),
    StationInfo(id: '1065-006', name: '계양', lat: 37.571449, lng: 126.73578),
    StationInfo(id: '1065-007', name: '검암', lat: 37.56866, lng: 126.675687),
    StationInfo(id: '1065-008', name: '청라국제도시', lat: 37.5577, lng: 126.6232),
    StationInfo(id: '1065-009', name: '영종', lat: 37.51202, lng: 126.524254),
    StationInfo(id: '1065-010', name: '운서', lat: 37.492904, lng: 126.49379),
    StationInfo(id: '1065-011', name: '공항화물청사', lat: 37.4601, lng: 126.4762),
    StationInfo(id: '1065-012', name: '인천공항1터미널', lat: 37.447464, lng: 126.452508),
    StationInfo(id: '1065-013', name: '인천공항2터미널', lat: 37.460699, lng: 126.441442),
  ];

  // ──────────────────────────────────────────
  // 경춘선 (청량리 ~ 춘천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1067Stations = [
    StationInfo(id: '1067-000', name: '청량리', lat: 37.5824, lng: 127.0439, transferLines: ['1001', '1063', '1075']),
    StationInfo(id: '1067-001', name: '회기', lat: 37.58946, lng: 127.057583, transferLines: ['1001', '1063']),
    StationInfo(id: '1067-002', name: '중랑', lat: 37.594917, lng: 127.076116, transferLines: ['1063']),
    StationInfo(id: '1067-003', name: '상봉', lat: 37.5985, lng: 127.0836, transferLines: ['1007', '1063']),
    StationInfo(id: '1067-004', name: '망우', lat: 37.59955, lng: 127.091909, transferLines: ['1063']),
    StationInfo(id: '1067-005', name: '신내', lat: 37.6152, lng: 127.1029, transferLines: ['1006']),
    StationInfo(id: '1067-006', name: '갈매', lat: 37.634118, lng: 127.114757),
    StationInfo(id: '1067-007', name: '별내', lat: 37.64202, lng: 127.12684, transferLines: ['1008']),
    StationInfo(id: '1067-008', name: '퇴계원', lat: 37.648311, lng: 127.143952),
    StationInfo(id: '1067-009', name: '사릉', lat: 37.65108, lng: 127.176933),
    StationInfo(id: '1067-010', name: '금곡', lat: 37.637382, lng: 127.207853),
    StationInfo(id: '1067-011', name: '평내호평', lat: 37.653225, lng: 127.244493),
    StationInfo(id: '1067-012', name: '천마산', lat: 37.658978, lng: 127.285379),
    StationInfo(id: '1067-013', name: '마석', lat: 37.652782, lng: 127.311767),
    StationInfo(id: '1067-014', name: '대성리', lat: 37.684071, lng: 127.379319),
    StationInfo(id: '1067-015', name: '청평', lat: 37.735488, lng: 127.42661),
    StationInfo(id: '1067-016', name: '상천', lat: 37.770246, lng: 127.454821),
    StationInfo(id: '1067-017', name: '가평', lat: 37.814536, lng: 127.510739),
    StationInfo(id: '1067-018', name: '굴봉산', lat: 37.832067, lng: 127.557695),
    StationInfo(id: '1067-019', name: '백양리', lat: 37.830779, lng: 127.58933),
    StationInfo(id: '1067-020', name: '강촌', lat: 37.805723, lng: 127.634146),
    StationInfo(id: '1067-021', name: '김유정', lat: 37.818466, lng: 127.71434),
    StationInfo(id: '1067-022', name: '남춘천', lat: 37.864007, lng: 127.723792),
    StationInfo(id: '1067-023', name: '춘천', lat: 37.885054, lng: 127.717023),
  ];

  // ──────────────────────────────────────────
  // 수인분당선 (청량리 ~ 인천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1075Stations = [
    StationInfo(id: '1075-000', name: '청량리', lat: 37.5824, lng: 127.0439, transferLines: ['1001', '1063', '1067']),
    StationInfo(id: '1075-001', name: '왕십리', lat: 37.561238, lng: 127.036954, transferLines: ['1002', '1005', '1063']),
    StationInfo(id: '1075-002', name: '서울숲', lat: 37.543617, lng: 127.044707),
    StationInfo(id: '1075-003', name: '압구정로데오', lat: 37.527381, lng: 127.040534),
    StationInfo(id: '1075-004', name: '강남구청', lat: 37.517469, lng: 127.041151, transferLines: ['1007']),
    StationInfo(id: '1075-005', name: '선정릉', lat: 37.510735, lng: 127.043677, transferLines: ['1009']),
    StationInfo(id: '1075-006', name: '선릉', lat: 37.504286, lng: 127.048203, transferLines: ['1002']),
    StationInfo(id: '1075-007', name: '한티', lat: 37.496237, lng: 127.052873),
    StationInfo(id: '1075-008', name: '도곡', lat: 37.490922, lng: 127.055452, transferLines: ['1003']),
    StationInfo(id: '1075-009', name: '구룡', lat: 37.486839, lng: 127.058856),
    StationInfo(id: '1075-010', name: '개포동', lat: 37.489116, lng: 127.06614),
    StationInfo(id: '1075-011', name: '대모산입구', lat: 37.491373, lng: 127.07272),
    StationInfo(id: '1075-012', name: '수서', lat: 37.487378, lng: 127.101907, transferLines: ['1003', '1032']),
    StationInfo(id: '1075-013', name: '복정', lat: 37.4731, lng: 127.1246, transferLines: ['1008']),
    StationInfo(id: '1075-014', name: '가천대', lat: 37.448605, lng: 127.126697),
    StationInfo(id: '1075-015', name: '태평', lat: 37.440019, lng: 127.127709),
    StationInfo(id: '1075-016', name: '모란', lat: 37.432052, lng: 127.129104, transferLines: ['1008']),
    StationInfo(id: '1075-017', name: '야탑', lat: 37.411185, lng: 127.128715),
    StationInfo(id: '1075-018', name: '이매', lat: 37.394655, lng: 127.127819),
    StationInfo(id: '1075-019', name: '서현', lat: 37.385126, lng: 127.123592),
    StationInfo(id: '1075-020', name: '수내', lat: 37.378455, lng: 127.114322),
    StationInfo(id: '1075-021', name: '정자', lat: 37.365994, lng: 127.10807, transferLines: ['1077']),
    StationInfo(id: '1075-022', name: '미금', lat: 37.350077, lng: 127.10891, transferLines: ['1077']),
    StationInfo(id: '1075-023', name: '오리', lat: 37.339824, lng: 127.108942),
    StationInfo(id: '1075-024', name: '죽전', lat: 37.324753, lng: 127.107395),
    StationInfo(id: '1075-025', name: '보정', lat: 37.312752, lng: 127.108196),
    StationInfo(id: '1075-026', name: '구성', lat: 37.298969, lng: 127.105664, transferLines: ['1032']),
    StationInfo(id: '1075-027', name: '신갈', lat: 37.286102, lng: 127.111313),
    StationInfo(id: '1075-028', name: '기흥', lat: 37.275061, lng: 127.11591),
    StationInfo(id: '1075-029', name: '상갈', lat: 37.26181, lng: 127.108847),
    StationInfo(id: '1075-030', name: '청명', lat: 37.259489, lng: 127.078934),
    StationInfo(id: '1075-031', name: '영통', lat: 37.251568, lng: 127.071394),
    StationInfo(id: '1075-032', name: '망포', lat: 37.245795, lng: 127.057353),
    StationInfo(id: '1075-033', name: '매탄권선', lat: 37.252759, lng: 127.040566),
    StationInfo(id: '1075-034', name: '수원시청', lat: 37.261911, lng: 127.030736),
    StationInfo(id: '1075-035', name: '매교', lat: 37.265481, lng: 127.015678),
    StationInfo(id: '1075-036', name: '수원', lat: 37.2685, lng: 126.9980, transferLines: ['1001']),
    StationInfo(id: '1075-037', name: '고색', lat: 37.24963, lng: 126.980248),
    StationInfo(id: '1075-038', name: '오목천', lat: 37.24304, lng: 126.963676),
    StationInfo(id: '1075-039', name: '어천', lat: 37.250102, lng: 126.90879),
    StationInfo(id: '1075-040', name: '야목', lat: 37.2640, lng: 126.8820),
    StationInfo(id: '1075-041', name: '사리', lat: 37.28998, lng: 126.85685),
    StationInfo(id: '1075-042', name: '한대앞', lat: 37.309689, lng: 126.85344, transferLines: ['1004']),
    StationInfo(id: '1075-043', name: '중앙', lat: 37.315941, lng: 126.838573),
    StationInfo(id: '1075-044', name: '고잔', lat: 37.316784, lng: 126.823144),
    StationInfo(id: '1075-045', name: '초지', lat: 37.320646, lng: 126.805913),
    StationInfo(id: '1075-046', name: '안산', lat: 37.327082, lng: 126.788532),
    StationInfo(id: '1075-047', name: '신길온천', lat: 37.3402, lng: 126.7651),
    StationInfo(id: '1075-048', name: '정왕', lat: 37.351735, lng: 126.742989),
    StationInfo(id: '1075-049', name: '오이도', lat: 37.362357, lng: 126.738714, transferLines: ['1004']),
    StationInfo(id: '1075-050', name: '달월', lat: 37.379681, lng: 126.745177),
    StationInfo(id: '1075-051', name: '월곶', lat: 37.391769, lng: 126.742699),
    StationInfo(id: '1075-052', name: '소래포구', lat: 37.40095, lng: 126.733522),
    StationInfo(id: '1075-053', name: '인천논현', lat: 37.400614, lng: 126.722478),
    StationInfo(id: '1075-054', name: '호구포', lat: 37.401637, lng: 126.708627),
    StationInfo(id: '1075-055', name: '남동인더스파크', lat: 37.407722, lng: 126.695216),
    StationInfo(id: '1075-056', name: '원인재', lat: 37.4149, lng: 126.6856),
    StationInfo(id: '1075-057', name: '연수', lat: 37.417804, lng: 126.67894),
    StationInfo(id: '1075-058', name: '송도', lat: 37.428514, lng: 126.657772),
    StationInfo(id: '1075-059', name: '인하대', lat: 37.448493, lng: 126.649619),
    StationInfo(id: '1075-060', name: '숭의', lat: 37.460789, lng: 126.638297),
    StationInfo(id: '1075-061', name: '신포', lat: 37.46874, lng: 126.623853),
    StationInfo(id: '1075-062', name: '인천', lat: 37.476079, lng: 126.616801, transferLines: ['1001']),
  ];

  // ──────────────────────────────────────────
  // 신분당선 (신사 ~ 광교)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1077Stations = [
    StationInfo(id: '1077-000', name: '신사', lat: 37.516334, lng: 127.020114, transferLines: ['1003']),
    StationInfo(id: '1077-001', name: '논현', lat: 37.511093, lng: 127.021415, transferLines: ['1007']),
    StationInfo(id: '1077-002', name: '신논현', lat: 37.504598, lng: 127.02506, transferLines: ['1009']),
    StationInfo(id: '1077-003', name: '강남', lat: 37.49799, lng: 127.027912, transferLines: ['1002']),
    StationInfo(id: '1077-004', name: '양재', lat: 37.484477, lng: 127.033902, transferLines: ['1003']),
    StationInfo(id: '1077-005', name: '양재시민의숲', lat: 37.470023, lng: 127.03842),
    StationInfo(id: '1077-006', name: '청계산입구', lat: 37.447211, lng: 127.055664),
    StationInfo(id: '1077-007', name: '판교', lat: 37.394761, lng: 127.111217),
    StationInfo(id: '1077-008', name: '정자', lat: 37.365994, lng: 127.10807, transferLines: ['1075']),
    StationInfo(id: '1077-009', name: '미금', lat: 37.350077, lng: 127.10891, transferLines: ['1075']),
    StationInfo(id: '1077-010', name: '동천', lat: 37.337928, lng: 127.102976),
    StationInfo(id: '1077-011', name: '수지구청', lat: 37.322702, lng: 127.095026),
    StationInfo(id: '1077-012', name: '성복', lat: 37.313335, lng: 127.0801),
    StationInfo(id: '1077-013', name: '상현', lat: 37.297664, lng: 127.069342),
    StationInfo(id: '1077-014', name: '광교중앙', lat: 37.288617, lng: 127.051478),
    StationInfo(id: '1077-015', name: '광교', lat: 37.30211, lng: 127.044483),
  ];

  // ──────────────────────────────────────────
  // 우이신설선 (북한산우이 ~ 신설동)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1092Stations = [
    StationInfo(id: '1092-000', name: '북한산우이', lat: 37.662909, lng: 127.012706),
    StationInfo(id: '1092-001', name: '솔밭공원', lat: 37.65603, lng: 127.013273),
    StationInfo(id: '1092-002', name: '4·19민주묘지', lat: 37.649502, lng: 127.013684),
    StationInfo(id: '1092-003', name: '가오리', lat: 37.641537, lng: 127.016789),
    StationInfo(id: '1092-004', name: '화계', lat: 37.634133, lng: 127.017511),
    StationInfo(id: '1092-005', name: '삼양', lat: 37.626914, lng: 127.018106),
    StationInfo(id: '1092-006', name: '삼양사거리', lat: 37.621337, lng: 127.020473),
    StationInfo(id: '1092-007', name: '솔샘', lat: 37.620238, lng: 127.013626),
    StationInfo(id: '1092-008', name: '북한산보국문', lat: 37.612072, lng: 127.008251),
    StationInfo(id: '1092-009', name: '정릉', lat: 37.603133, lng: 127.013396),
    StationInfo(id: '1092-010', name: '성신여대입구', lat: 37.592612, lng: 127.016441, transferLines: ['1004']),
    StationInfo(id: '1092-011', name: '보문', lat: 37.585274, lng: 127.019351, transferLines: ['1006']),
    StationInfo(id: '1092-012', name: '신설동', lat: 37.576048, lng: 127.024634, transferLines: ['1001', '1002']),
  ];

  // ──────────────────────────────────────────
  // GTX-A (서울역 ~ 동탄)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1032Stations = [
    StationInfo(id: '1032-000', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1001', '1004', '1065']),
    StationInfo(id: '1032-001', name: '삼성', lat: 37.5090, lng: 127.0637, transferLines: ['1002']),
    StationInfo(id: '1032-002', name: '수서', lat: 37.4869, lng: 127.1019, transferLines: ['1003', '1075']),
    StationInfo(id: '1032-003', name: '성남', lat: 37.3947, lng: 127.1194),
    StationInfo(id: '1032-004', name: '구성', lat: 37.2986, lng: 127.1056, transferLines: ['1075']),
    StationInfo(id: '1032-005', name: '동탄', lat: 37.2012, lng: 127.0951),
  ];

  // ──────────────────────────────────────────
  // 서해선 (일산 ~ 원시)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1093Stations = [
    StationInfo(id: '1093-000', name: '일산', lat: 37.6820, lng: 126.7699),
    StationInfo(id: '1093-001', name: '풍산', lat: 37.6729, lng: 126.7859),
    StationInfo(id: '1093-002', name: '곡산', lat: 37.6464, lng: 126.8014),
    StationInfo(id: '1093-003', name: '대곡', lat: 37.6313, lng: 126.8103, transferLines: ['1063', '1003']),
    StationInfo(id: '1093-004', name: '능곡', lat: 37.6184, lng: 126.8212),
    StationInfo(id: '1093-005', name: '김포공항', lat: 37.5623, lng: 126.8010, transferLines: ['1005', '1009', '1065']),
    StationInfo(id: '1093-006', name: '원종', lat: 37.5222, lng: 126.8049),
    StationInfo(id: '1093-007', name: '부천종합운동장', lat: 37.5056, lng: 126.7975, transferLines: ['1007']),
    StationInfo(id: '1093-008', name: '소사', lat: 37.4824, lng: 126.7952, transferLines: ['1001']),
    StationInfo(id: '1093-009', name: '소새울', lat: 37.4687, lng: 126.7972),
    StationInfo(id: '1093-010', name: '시흥대야', lat: 37.4501, lng: 126.7931),
    StationInfo(id: '1093-011', name: '신천', lat: 37.4393, lng: 126.7869),
    StationInfo(id: '1093-012', name: '신현', lat: 37.4097, lng: 126.7879),
    StationInfo(id: '1093-013', name: '시흥시청', lat: 37.3820, lng: 126.8059),
    StationInfo(id: '1093-014', name: '시흥능곡', lat: 37.3702, lng: 126.8088),
    StationInfo(id: '1093-015', name: '달미', lat: 37.3490, lng: 126.8091),
    StationInfo(id: '1093-016', name: '선부', lat: 37.3344, lng: 126.8100),
    StationInfo(id: '1093-017', name: '초지', lat: 37.3198, lng: 126.8080, transferLines: ['1004', '1075']),
    StationInfo(id: '1093-018', name: '시우', lat: 37.3131, lng: 126.7957),
    StationInfo(id: '1093-019', name: '원시', lat: 37.3025, lng: 126.7868),
  ];

  // ──────────────────────────────────────────
  // 신림선 (샛강 ~ 관악산, 전구간 지하)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1094Stations = [
    StationInfo(id: '1094-000', name: '샛강', lat: 37.5173, lng: 126.9294, transferLines: ['1009']),
    StationInfo(id: '1094-001', name: '대방', lat: 37.5125, lng: 126.9252, transferLines: ['1001']),
    StationInfo(id: '1094-002', name: '서울지방병무청', lat: 37.5059, lng: 126.9228),
    StationInfo(id: '1094-003', name: '보라매', lat: 37.5004, lng: 126.9206, transferLines: ['1007']),
    StationInfo(id: '1094-004', name: '보라매공원', lat: 37.4953, lng: 126.9183),
    StationInfo(id: '1094-005', name: '보라매병원', lat: 37.4930, lng: 126.9243),
    StationInfo(id: '1094-006', name: '당곡', lat: 37.4897, lng: 126.9278),
    StationInfo(id: '1094-007', name: '신림', lat: 37.4849, lng: 126.9297, transferLines: ['1002']),
    StationInfo(id: '1094-008', name: '서원', lat: 37.4782, lng: 126.9331),
    StationInfo(id: '1094-009', name: '서울대벤처타운', lat: 37.4720, lng: 126.9337),
    StationInfo(id: '1094-010', name: '관악산', lat: 37.4688, lng: 126.9453),
  ];

  // ──────────────────────────────────────────
  // 경강선 (판교 ~ 여주)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1081Stations = [
    StationInfo(id: '1081-000', name: '판교', lat: 37.3947, lng: 127.1115, transferLines: ['1077']),
    StationInfo(id: '1081-001', name: '이매', lat: 37.394655, lng: 127.127819, transferLines: ['1075']),
    StationInfo(id: '1081-002', name: '삼동', lat: 37.409522, lng: 127.20336),
    StationInfo(id: '1081-003', name: '경기광주', lat: 37.399907, lng: 127.25263),
    StationInfo(id: '1081-004', name: '초월', lat: 37.374419, lng: 127.299),
    StationInfo(id: '1081-005', name: '곤지암', lat: 37.351315, lng: 127.34674),
    StationInfo(id: '1081-006', name: '신둔도예촌', lat: 37.317185, lng: 127.40476),
    StationInfo(id: '1081-007', name: '이천', lat: 37.265579, lng: 127.44226),
    StationInfo(id: '1081-008', name: '부발', lat: 37.260192, lng: 127.490277),
    StationInfo(id: '1081-009', name: '세종대왕릉', lat: 37.295309, lng: 127.570938),
    StationInfo(id: '1081-010', name: '여주', lat: 37.282308, lng: 127.628816),
  ];
}