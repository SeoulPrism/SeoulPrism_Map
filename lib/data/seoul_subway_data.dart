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
  };

  /// 해당 역이 지상인지 확인
  static bool isSurfaceStation(String stationId) {
    return surfaceStationIds.contains(stationId);
  }

  /// 역명으로 역 좌표 검색
  static StationInfo? findStation(String name) {
    for (final line in allLines) {
      for (final station in line) {
        if (station.name == name) return station;
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

  static List<List<StationInfo>> get allLines => [
    line1Stations, line2Stations, line3Stations, line4Stations,
    line5Stations, line6Stations, line7Stations, line8Stations, line9Stations,
    line1GyeonginStations, line2SeongsuStations, line2SinjeongStations,
    line5MacheonStations,
  ];

  // ──────────────────────────────────────────
  // 1호선 (소요산 ~ 인천/신창 방면, 서울 구간 주요역)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1Stations = [
    StationInfo(id: '1001-100', name: '소요산', lat: 37.9472, lng: 127.0607),
    StationInfo(id: '1001-101', name: '동두천', lat: 37.9278, lng: 127.0547),
    StationInfo(id: '1001-102', name: '보산', lat: 37.9136, lng: 127.0572),
    StationInfo(id: '1001-103', name: '동두천중앙', lat: 37.9022, lng: 127.0564),
    StationInfo(id: '1001-104', name: '지행', lat: 37.8922, lng: 127.0556),
    StationInfo(id: '1001-105', name: '덕정', lat: 37.8444, lng: 127.0614),
    StationInfo(id: '1001-106', name: '덕계', lat: 37.8189, lng: 127.0564),
    StationInfo(id: '1001-107', name: '양주', lat: 37.7744, lng: 127.0447),
    StationInfo(id: '1001-108', name: '녹양', lat: 37.7589, lng: 127.0419),
    StationInfo(id: '1001-109', name: '가능', lat: 37.7483, lng: 127.0442),
    StationInfo(id: '1001-110', name: '의정부', lat: 37.7381, lng: 127.0459, transferLines: ['1092']),
    StationInfo(id: '1001-111', name: '회룡', lat: 37.7192, lng: 127.0474),
    StationInfo(id: '1001-112', name: '망월사', lat: 37.7106, lng: 127.0474),
    StationInfo(id: '1001-113', name: '도봉산', lat: 37.6896, lng: 127.0447, transferLines: ['1007']),
    StationInfo(id: '1001-114', name: '도봉', lat: 37.6790, lng: 127.0468),
    StationInfo(id: '1001-115', name: '방학', lat: 37.6690, lng: 127.0442),
    StationInfo(id: '1001-116', name: '창동', lat: 37.6530, lng: 127.0477, transferLines: ['1004']),
    StationInfo(id: '1001-117', name: '녹천', lat: 37.6443, lng: 127.0516),
    StationInfo(id: '1001-118', name: '월계', lat: 37.6345, lng: 127.0583),
    StationInfo(id: '1001-119', name: '광운대', lat: 37.6249, lng: 127.0617),
    StationInfo(id: '1001-120', name: '석계', lat: 37.6158, lng: 127.0654, transferLines: ['1006']),
    StationInfo(id: '1001-121', name: '신이문', lat: 37.5950, lng: 127.0630),
    StationInfo(id: '1001-122', name: '외대앞', lat: 37.5928, lng: 127.0614),
    StationInfo(id: '1001-123', name: '회기', lat: 37.5895, lng: 127.0585, transferLines: ['1063']),
    StationInfo(id: '1001-124', name: '청량리', lat: 37.5804, lng: 127.0467, transferLines: ['1063', '1075']),
    StationInfo(id: '1001-125', name: '제기동', lat: 37.5787, lng: 127.0375),
    StationInfo(id: '1001-126', name: '신설동', lat: 37.5752, lng: 127.0247, transferLines: ['1002', '1092']),
    StationInfo(id: '1001-127', name: '동묘앞', lat: 37.5719, lng: 127.0165, transferLines: ['1006']),
    StationInfo(id: '1001-128', name: '동대문', lat: 37.5711, lng: 127.0093, transferLines: ['1004']),
    StationInfo(id: '1001-129', name: '종로5가', lat: 37.5706, lng: 127.0020),
    StationInfo(id: '1001-130', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1003', '1005']),
    StationInfo(id: '1001-131', name: '종각', lat: 37.5702, lng: 126.9827),
    StationInfo(id: '1001-132', name: '시청', lat: 37.5647, lng: 126.9772, transferLines: ['1002']),
    StationInfo(id: '1001-133', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1004', '1065']),
    StationInfo(id: '1001-134', name: '남영', lat: 37.5415, lng: 126.9717),
    StationInfo(id: '1001-135', name: '용산', lat: 37.5299, lng: 126.9648, transferLines: ['1063']),
    StationInfo(id: '1001-136', name: '노량진', lat: 37.5132, lng: 126.9424, transferLines: ['1009']),
    StationInfo(id: '1001-137', name: '대방', lat: 37.5134, lng: 126.9262),
    StationInfo(id: '1001-138', name: '신길', lat: 37.5177, lng: 126.9142, transferLines: ['1005']),
    StationInfo(id: '1001-139', name: '영등포', lat: 37.5159, lng: 126.9075),
    StationInfo(id: '1001-140', name: '신도림', lat: 37.5088, lng: 126.8912, transferLines: ['1002']),
    // ── 경부선 (구로 ~ 신창) ──
    StationInfo(id: '1001-141', name: '구로', lat: 37.5033, lng: 126.8824),
    StationInfo(id: '1001-142', name: '가산디지털단지', lat: 37.4816, lng: 126.8826, transferLines: ['1007']),
    StationInfo(id: '1001-143', name: '독산', lat: 37.4669, lng: 126.8892),
    StationInfo(id: '1001-144', name: '금천구청', lat: 37.4568, lng: 126.8953),
    StationInfo(id: '1001-145', name: '석수', lat: 37.4341, lng: 126.9025),
    StationInfo(id: '1001-146', name: '관악', lat: 37.4192, lng: 126.9087),
    StationInfo(id: '1001-147', name: '안양', lat: 37.4006, lng: 126.9224),
    StationInfo(id: '1001-148', name: '명학', lat: 37.3846, lng: 126.9355),
    StationInfo(id: '1001-149', name: '금정', lat: 37.3717, lng: 126.9430, transferLines: ['1004']),
    StationInfo(id: '1001-150', name: '군포', lat: 37.3536, lng: 126.9485),
    StationInfo(id: '1001-151', name: '당정', lat: 37.3434, lng: 126.9484),
    StationInfo(id: '1001-152', name: '의왕', lat: 37.3211, lng: 126.9481),
    StationInfo(id: '1001-153', name: '성균관대', lat: 37.3003, lng: 126.9711),
    StationInfo(id: '1001-154', name: '화서', lat: 37.2800, lng: 126.9920),
    StationInfo(id: '1001-155', name: '수원', lat: 37.2664, lng: 127.0002),
    StationInfo(id: '1001-156', name: '세류', lat: 37.2441, lng: 127.0137),
    StationInfo(id: '1001-157', name: '병점', lat: 37.2068, lng: 127.0331),
    StationInfo(id: '1001-158', name: '세마', lat: 37.1875, lng: 127.0433),
    StationInfo(id: '1001-159', name: '오산대', lat: 37.1694, lng: 127.0631),
    StationInfo(id: '1001-160', name: '오산', lat: 37.1492, lng: 127.0673),
    StationInfo(id: '1001-161', name: '진위', lat: 37.1094, lng: 127.0622),
    StationInfo(id: '1001-162', name: '송탄', lat: 37.0757, lng: 127.0543),
    StationInfo(id: '1001-163', name: '서정리', lat: 37.0575, lng: 127.0531),
    StationInfo(id: '1001-164', name: '평택', lat: 36.9907, lng: 127.0849),
    StationInfo(id: '1001-165', name: '성환', lat: 36.9156, lng: 127.1278),
    StationInfo(id: '1001-166', name: '직산', lat: 36.8708, lng: 127.1439),
    StationInfo(id: '1001-167', name: '두정', lat: 36.834, lng: 127.1492),
    StationInfo(id: '1001-168', name: '천안', lat: 36.8112, lng: 127.1468),
    StationInfo(id: '1001-169', name: '봉명', lat: 36.8011, lng: 127.1356),
    StationInfo(id: '1001-170', name: '쌍용', lat: 36.7926, lng: 127.1179),
    StationInfo(id: '1001-171', name: '아산', lat: 36.792, lng: 127.1051),
    StationInfo(id: '1001-172', name: '배방', lat: 36.7778, lng: 127.0531),
    StationInfo(id: '1001-173', name: '온양온천', lat: 36.7806, lng: 127.0033),
    StationInfo(id: '1001-174', name: '신창', lat: 36.7694, lng: 126.9508),
  ];

  // ──────────────────────────────────────────
  // 2호선 (순환선 - 시청 기점 시계방향)
  // ──────────────────────────────────────────
  static const List<StationInfo> line2Stations = [
    StationInfo(id: '1002-200', name: '시청', lat: 37.5647, lng: 126.9772, transferLines: ['1001']),
    StationInfo(id: '1002-201', name: '을지로입구', lat: 37.5660, lng: 126.9825),
    StationInfo(id: '1002-202', name: '을지로3가', lat: 37.5663, lng: 126.9920, transferLines: ['1003']),
    StationInfo(id: '1002-203', name: '을지로4가', lat: 37.5669, lng: 126.9980, transferLines: ['1005']),
    StationInfo(id: '1002-204', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, transferLines: ['1004', '1005']),
    StationInfo(id: '1002-205', name: '신당', lat: 37.5659, lng: 127.0175, transferLines: ['1006']),
    StationInfo(id: '1002-206', name: '상왕십리', lat: 37.5651, lng: 127.0290),
    StationInfo(id: '1002-207', name: '왕십리', lat: 37.5614, lng: 127.0378, transferLines: ['1005', '1063', '1075']),
    StationInfo(id: '1002-208', name: '한양대', lat: 37.5558, lng: 127.0438),
    StationInfo(id: '1002-209', name: '뚝섬', lat: 37.5473, lng: 127.0474),
    StationInfo(id: '1002-210', name: '성수', lat: 37.5445, lng: 127.0558),
    StationInfo(id: '1002-211', name: '건대입구', lat: 37.5403, lng: 127.0695, transferLines: ['1007']),
    StationInfo(id: '1002-212', name: '구의', lat: 37.5369, lng: 127.085),
    StationInfo(id: '1002-213', name: '강변', lat: 37.5350, lng: 127.0940),
    StationInfo(id: '1002-214', name: '잠실나루', lat: 37.5213, lng: 127.1039),
    StationInfo(id: '1002-215', name: '잠실', lat: 37.5133, lng: 127.1001, transferLines: ['1008']),
    StationInfo(id: '1002-216', name: '잠실새내', lat: 37.5117, lng: 127.0867),
    StationInfo(id: '1002-217', name: '종합운동장', lat: 37.5108, lng: 127.0737, transferLines: ['1009']),
    StationInfo(id: '1002-218', name: '삼성', lat: 37.5090, lng: 127.0637),
    StationInfo(id: '1002-219', name: '선릉', lat: 37.5046, lng: 127.0490, transferLines: ['1075']),
    StationInfo(id: '1002-220', name: '역삼', lat: 37.5006, lng: 127.0368),
    StationInfo(id: '1002-221', name: '강남', lat: 37.4979, lng: 127.0276, transferLines: ['1077']),
    StationInfo(id: '1002-222', name: '교대', lat: 37.4934, lng: 127.0146, transferLines: ['1003']),
    StationInfo(id: '1002-223', name: '서초', lat: 37.4917, lng: 127.0072),
    StationInfo(id: '1002-224', name: '방배', lat: 37.4815, lng: 126.9977),
    StationInfo(id: '1002-225', name: '사당', lat: 37.4765, lng: 126.9816, transferLines: ['1004']),
    StationInfo(id: '1002-226', name: '낙성대', lat: 37.4768, lng: 126.9637),
    StationInfo(id: '1002-227', name: '서울대입구', lat: 37.4812, lng: 126.9528),
    StationInfo(id: '1002-228', name: '봉천', lat: 37.4825, lng: 126.9419),
    StationInfo(id: '1002-229', name: '신림', lat: 37.4843, lng: 126.9296),
    StationInfo(id: '1002-230', name: '신대방', lat: 37.4878, lng: 126.9131),
    StationInfo(id: '1002-231', name: '구로디지털단지', lat: 37.4851, lng: 126.9015),
    StationInfo(id: '1002-232', name: '대림', lat: 37.4934, lng: 126.8968, transferLines: ['1007']),
    StationInfo(id: '1002-233', name: '신도림', lat: 37.5088, lng: 126.8912, transferLines: ['1001']),
    StationInfo(id: '1002-234', name: '문래', lat: 37.5183, lng: 126.8949),
    StationInfo(id: '1002-235', name: '영등포구청', lat: 37.5248, lng: 126.8964, transferLines: ['1005']),
    StationInfo(id: '1002-236', name: '당산', lat: 37.5340, lng: 126.9027, transferLines: ['1009']),
    StationInfo(id: '1002-237', name: '합정', lat: 37.5494, lng: 126.9137, transferLines: ['1006']),
    StationInfo(id: '1002-238', name: '홍대입구', lat: 37.5567, lng: 126.9236, transferLines: ['1065']),
    StationInfo(id: '1002-239', name: '신촌', lat: 37.5554, lng: 126.9369),
    StationInfo(id: '1002-240', name: '이대', lat: 37.5569, lng: 126.9462),
    StationInfo(id: '1002-241', name: '아현', lat: 37.5575, lng: 126.9558),
    StationInfo(id: '1002-242', name: '충정로', lat: 37.5600, lng: 126.9635, transferLines: ['1005']),
  ];

  // ──────────────────────────────────────────
  // 3호선 (대화 ~ 오금)
  // ──────────────────────────────────────────
  static const List<StationInfo> line3Stations = [
    StationInfo(id: '1003-300', name: '대화', lat: 37.6763, lng: 126.7475),
    StationInfo(id: '1003-301', name: '주엽', lat: 37.6726, lng: 126.7556),
    StationInfo(id: '1003-302', name: '정발산', lat: 37.6663, lng: 126.7673),
    StationInfo(id: '1003-303', name: '마두', lat: 37.6563, lng: 126.7752),
    StationInfo(id: '1003-304', name: '백석', lat: 37.6455, lng: 126.7848),
    StationInfo(id: '1003-305', name: '대곡', lat: 37.6344, lng: 126.7977, transferLines: ['1063']),
    StationInfo(id: '1003-306', name: '화정', lat: 37.6320, lng: 126.8168),
    StationInfo(id: '1003-307', name: '원당', lat: 37.6341, lng: 126.8328),
    StationInfo(id: '1003-308', name: '원흥', lat: 37.6417, lng: 126.8403),
    StationInfo(id: '1003-309', name: '삼송', lat: 37.6535, lng: 126.8614),
    StationInfo(id: '1003-310', name: '지축', lat: 37.6484, lng: 126.9133),
    StationInfo(id: '1003-311', name: '구파발', lat: 37.6369, lng: 126.9186),
    StationInfo(id: '1003-312', name: '연신내', lat: 37.6191, lng: 126.9210, transferLines: ['1006']),
    StationInfo(id: '1003-313', name: '불광', lat: 37.6102, lng: 126.9296, transferLines: ['1006']),
    StationInfo(id: '1003-314', name: '녹번', lat: 37.6007, lng: 126.9363),
    StationInfo(id: '1003-315', name: '홍제', lat: 37.5888, lng: 126.9436),
    StationInfo(id: '1003-316', name: '무악재', lat: 37.5831, lng: 126.9503),
    StationInfo(id: '1003-317', name: '독립문', lat: 37.5722, lng: 126.9601),
    StationInfo(id: '1003-318', name: '경복궁', lat: 37.5759, lng: 126.9736),
    StationInfo(id: '1003-319', name: '안국', lat: 37.5760, lng: 126.9855, transferLines: ['1003']),
    StationInfo(id: '1003-320', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1001', '1005']),
    StationInfo(id: '1003-321', name: '을지로3가', lat: 37.5663, lng: 126.9920, transferLines: ['1002']),
    StationInfo(id: '1003-322', name: '충무로', lat: 37.5612, lng: 126.9944, transferLines: ['1004']),
    StationInfo(id: '1003-323', name: '동대입구', lat: 37.5598, lng: 126.9983),
    StationInfo(id: '1003-324', name: '약수', lat: 37.5544, lng: 127.0108, transferLines: ['1006']),
    StationInfo(id: '1003-325', name: '금호', lat: 37.5475, lng: 127.0175),
    StationInfo(id: '1003-326', name: '옥수', lat: 37.5402, lng: 127.0175, transferLines: ['1063']),
    StationInfo(id: '1003-327', name: '압구정', lat: 37.5271, lng: 127.0285),
    StationInfo(id: '1003-328', name: '신사', lat: 37.5165, lng: 127.0217),
    StationInfo(id: '1003-329', name: '잠원', lat: 37.5136, lng: 127.0128),
    StationInfo(id: '1003-330', name: '고속터미널', lat: 37.5047, lng: 127.0049, transferLines: ['1007', '1009']),
    StationInfo(id: '1003-331', name: '교대', lat: 37.4934, lng: 127.0146, transferLines: ['1002']),
    StationInfo(id: '1003-332', name: '남부터미널', lat: 37.4856, lng: 127.0163),
    StationInfo(id: '1003-333', name: '양재', lat: 37.4846, lng: 127.0355, transferLines: ['1077']),
    StationInfo(id: '1003-334', name: '매봉', lat: 37.4872, lng: 127.0463),
    StationInfo(id: '1003-335', name: '도곡', lat: 37.4910, lng: 127.0556, transferLines: ['1075']),
    StationInfo(id: '1003-336', name: '대치', lat: 37.4945, lng: 127.0632),
    StationInfo(id: '1003-337', name: '학여울', lat: 37.4970, lng: 127.0711),
    StationInfo(id: '1003-338', name: '대청', lat: 37.4927, lng: 127.0800),
    StationInfo(id: '1003-339', name: '일원', lat: 37.4861, lng: 127.0828),
    StationInfo(id: '1003-340', name: '수서', lat: 37.4874, lng: 127.1017, transferLines: ['1075']),
    StationInfo(id: '1003-341', name: '가락시장', lat: 37.4926, lng: 127.1183, transferLines: ['1008']),
    StationInfo(id: '1003-342', name: '경찰병원', lat: 37.4947, lng: 127.1249),
    StationInfo(id: '1003-343', name: '오금', lat: 37.5002, lng: 127.1280, transferLines: ['1005']),
  ];

  // ──────────────────────────────────────────
  // 4호선 (당고개 ~ 오이도, 서울 구간)
  // ──────────────────────────────────────────
  static const List<StationInfo> line4Stations = [
    StationInfo(id: '1004-400', name: '당고개', lat: 37.6701, lng: 127.0800),
    StationInfo(id: '1004-401', name: '상계', lat: 37.6610, lng: 127.0740),
    StationInfo(id: '1004-402', name: '노원', lat: 37.6553, lng: 127.0616, transferLines: ['1007']),
    StationInfo(id: '1004-403', name: '창동', lat: 37.6530, lng: 127.0477, transferLines: ['1001']),
    StationInfo(id: '1004-404', name: '쌍문', lat: 37.6484, lng: 127.0349),
    StationInfo(id: '1004-405', name: '수유', lat: 37.6381, lng: 127.0253),
    StationInfo(id: '1004-406', name: '미아', lat: 37.6265, lng: 127.0265),
    StationInfo(id: '1004-407', name: '미아사거리', lat: 37.6133, lng: 127.0297),
    StationInfo(id: '1004-408', name: '길음', lat: 37.6031, lng: 127.0252),
    StationInfo(id: '1004-409', name: '성신여대입구', lat: 37.5924, lng: 127.0164),
    StationInfo(id: '1004-410', name: '한성대입구', lat: 37.5884, lng: 127.0065),
    StationInfo(id: '1004-411', name: '혜화', lat: 37.5821, lng: 127.0015),
    StationInfo(id: '1004-412', name: '동대문', lat: 37.5711, lng: 127.0093, transferLines: ['1001']),
    StationInfo(id: '1004-413', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, transferLines: ['1002', '1005']),
    StationInfo(id: '1004-414', name: '충무로', lat: 37.5612, lng: 126.9944, transferLines: ['1003']),
    StationInfo(id: '1004-415', name: '명동', lat: 37.5610, lng: 126.9858),
    StationInfo(id: '1004-416', name: '회현', lat: 37.5583, lng: 126.9784),
    StationInfo(id: '1004-417', name: '서울역', lat: 37.5547, lng: 126.9723, transferLines: ['1001', '1065']),
    StationInfo(id: '1004-418', name: '숙대입구', lat: 37.5446, lng: 126.9720),
    StationInfo(id: '1004-419', name: '삼각지', lat: 37.5345, lng: 126.9737, transferLines: ['1006']),
    StationInfo(id: '1004-420', name: '신용산', lat: 37.5307, lng: 126.9693),
    StationInfo(id: '1004-421', name: '이촌', lat: 37.5218, lng: 126.9695, transferLines: ['1063']),
    StationInfo(id: '1004-422', name: '동작', lat: 37.5028, lng: 126.9803),
    StationInfo(id: '1004-423', name: '총신대입구', lat: 37.4868, lng: 126.9818, transferLines: ['1007']),
    StationInfo(id: '1004-424', name: '사당', lat: 37.4765, lng: 126.9816, transferLines: ['1002']),
    StationInfo(id: '1004-425', name: '남태령', lat: 37.4644, lng: 126.9878),
    // ── 과천선 (선바위 ~ 금정) ──
    StationInfo(id: '1004-426', name: '선바위', lat: 37.4519, lng: 127.0021),
    StationInfo(id: '1004-427', name: '경마공원', lat: 37.4442, lng: 127.0078),
    StationInfo(id: '1004-428', name: '대공원', lat: 37.4356, lng: 127.0064),
    StationInfo(id: '1004-429', name: '과천', lat: 37.4282, lng: 126.991),
    StationInfo(id: '1004-430', name: '정부과천청사', lat: 37.424, lng: 126.9872),
    StationInfo(id: '1004-431', name: '인덕원', lat: 37.3989, lng: 126.9761),
    StationInfo(id: '1004-432', name: '평촌', lat: 37.3943, lng: 126.9638),
    StationInfo(id: '1004-433', name: '범계', lat: 37.3902, lng: 126.9535),
    StationInfo(id: '1004-434', name: '금정', lat: 37.3717, lng: 126.9430, transferLines: ['1001']),
    // ── 안산선 (산본 ~ 오이도) ──
    StationInfo(id: '1004-435', name: '산본', lat: 37.3577, lng: 126.9325),
    StationInfo(id: '1004-436', name: '수리산', lat: 37.3490, lng: 126.9251),
    StationInfo(id: '1004-437', name: '대야미', lat: 37.3283, lng: 126.9172),
    StationInfo(id: '1004-438', name: '반월', lat: 37.3122, lng: 126.9036),
    StationInfo(id: '1004-439', name: '상록수', lat: 37.3028, lng: 126.8664),
    StationInfo(id: '1004-440', name: '한대앞', lat: 37.3089, lng: 126.8542),
    StationInfo(id: '1004-441', name: '중앙', lat: 37.3161, lng: 126.8377),
    StationInfo(id: '1004-442', name: '고잔', lat: 37.3168, lng: 126.8231),
    StationInfo(id: '1004-443', name: '초지', lat: 37.3206, lng: 126.8062),
    StationInfo(id: '1004-444', name: '안산', lat: 37.3254, lng: 126.7925),
    StationInfo(id: '1004-445', name: '신길온천', lat: 37.3375, lng: 126.7673),
    StationInfo(id: '1004-446', name: '정왕', lat: 37.3517, lng: 126.7428),
    StationInfo(id: '1004-447', name: '오이도', lat: 37.3619, lng: 126.7383),
  ];

  // ──────────────────────────────────────────
  // 5호선 (방화 ~ 하남검단산/마천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line5Stations = [
    StationInfo(id: '1005-500', name: '방화', lat: 37.5743, lng: 126.8114),
    StationInfo(id: '1005-501', name: '개화산', lat: 37.5726, lng: 126.8048),
    StationInfo(id: '1005-502', name: '김포공항', lat: 37.5623, lng: 126.8010, transferLines: ['1009', '1065']),
    StationInfo(id: '1005-503', name: '송정', lat: 37.5599, lng: 126.8034),
    StationInfo(id: '1005-504', name: '마곡', lat: 37.5601, lng: 126.8264),
    StationInfo(id: '1005-505', name: '발산', lat: 37.5508, lng: 126.8382),
    StationInfo(id: '1005-506', name: '우장산', lat: 37.5427, lng: 126.8394),
    StationInfo(id: '1005-507', name: '화곡', lat: 37.5413, lng: 126.8395),
    StationInfo(id: '1005-508', name: '까치산', lat: 37.5342, lng: 126.8452),
    StationInfo(id: '1005-509', name: '신정', lat: 37.5248, lng: 126.8541),
    StationInfo(id: '1005-510', name: '목동', lat: 37.5245, lng: 126.8682),
    StationInfo(id: '1005-511', name: '오목교', lat: 37.5239, lng: 126.8779),
    StationInfo(id: '1005-512', name: '양평', lat: 37.5262, lng: 126.8865),
    StationInfo(id: '1005-513', name: '영등포구청', lat: 37.5248, lng: 126.8964, transferLines: ['1002']),
    StationInfo(id: '1005-514', name: '영등포시장', lat: 37.5229, lng: 126.9046),
    StationInfo(id: '1005-515', name: '신길', lat: 37.5157, lng: 126.9137, transferLines: ['1001']),
    StationInfo(id: '1005-516', name: '여의도', lat: 37.5215, lng: 126.9245, transferLines: ['1009']),
    StationInfo(id: '1005-517', name: '여의나루', lat: 37.5271, lng: 126.9328),
    StationInfo(id: '1005-518', name: '마포', lat: 37.5392, lng: 126.9462),
    StationInfo(id: '1005-519', name: '공덕', lat: 37.5440, lng: 126.9517, transferLines: ['1006', '1063', '1065']),
    StationInfo(id: '1005-520', name: '애오개', lat: 37.5535, lng: 126.9571),
    StationInfo(id: '1005-521', name: '충정로', lat: 37.5600, lng: 126.9635, transferLines: ['1002']),
    StationInfo(id: '1005-522', name: '서대문', lat: 37.5653, lng: 126.9664),
    StationInfo(id: '1005-523', name: '광화문', lat: 37.5712, lng: 126.9763),
    StationInfo(id: '1005-524', name: '종로3가', lat: 37.5714, lng: 126.9916, transferLines: ['1001', '1003']),
    StationInfo(id: '1005-525', name: '을지로4가', lat: 37.5669, lng: 126.9980, transferLines: ['1002']),
    StationInfo(id: '1005-526', name: '동대문역사문화공원', lat: 37.5651, lng: 127.0073, transferLines: ['1002', '1004']),
    StationInfo(id: '1005-527', name: '청구', lat: 37.5601, lng: 127.0141, transferLines: ['1006']),
    StationInfo(id: '1005-528', name: '신금호', lat: 37.5549, lng: 127.0187),
    StationInfo(id: '1005-529', name: '행당', lat: 37.5574, lng: 127.0299),
    StationInfo(id: '1005-530', name: '왕십리', lat: 37.5614, lng: 127.0378, transferLines: ['1002', '1063', '1075']),
    StationInfo(id: '1005-531', name: '마장', lat: 37.5658, lng: 127.0456),
    StationInfo(id: '1005-532', name: '답십리', lat: 37.5673, lng: 127.0529),
    StationInfo(id: '1005-533', name: '장한평', lat: 37.5611, lng: 127.0649),
    StationInfo(id: '1005-534', name: '군자', lat: 37.5572, lng: 127.0795, transferLines: ['1007']),
    StationInfo(id: '1005-535', name: '아차산', lat: 37.5518, lng: 127.0899),
    StationInfo(id: '1005-536', name: '광나루', lat: 37.5459, lng: 127.1036),
    StationInfo(id: '1005-537', name: '천호', lat: 37.5385, lng: 127.1231, transferLines: ['1008']),
    StationInfo(id: '1005-538', name: '강동', lat: 37.5352, lng: 127.1323),
    StationInfo(id: '1005-539', name: '길동', lat: 37.5372, lng: 127.1410),
    StationInfo(id: '1005-540', name: '굽은다리', lat: 37.5413, lng: 127.1413),
    StationInfo(id: '1005-541', name: '명일', lat: 37.5457, lng: 127.1429),
    StationInfo(id: '1005-542', name: '고덕', lat: 37.5548, lng: 127.1547),
    StationInfo(id: '1005-543', name: '상일동', lat: 37.5575, lng: 127.1670),
    StationInfo(id: '1005-544', name: '강일', lat: 37.5573, lng: 127.1763),
    StationInfo(id: '1005-545', name: '미사', lat: 37.5604, lng: 127.1900),
    StationInfo(id: '1005-546', name: '하남풍산', lat: 37.5505, lng: 127.2006),
    StationInfo(id: '1005-547', name: '하남시청', lat: 37.5390, lng: 127.2107),
    StationInfo(id: '1005-548', name: '하남검단산', lat: 37.5398, lng: 127.2232),
  ];

  // ──────────────────────────────────────────
  // 6호선 (응암순환 ~ 신내)
  // ──────────────────────────────────────────
  static const List<StationInfo> line6Stations = [
    StationInfo(id: '1006-600', name: '응암', lat: 37.5985, lng: 126.9193),
    StationInfo(id: '1006-601', name: '역촌', lat: 37.6055, lng: 126.9222),
    StationInfo(id: '1006-602', name: '불광', lat: 37.6102, lng: 126.9296, transferLines: ['1003']),
    StationInfo(id: '1006-603', name: '독바위', lat: 37.6151, lng: 126.9328),
    StationInfo(id: '1006-604', name: '연신내', lat: 37.6191, lng: 126.9210, transferLines: ['1003']),
    StationInfo(id: '1006-605', name: '구산', lat: 37.6133, lng: 126.9176),
    StationInfo(id: '1006-606', name: '새절', lat: 37.6033, lng: 126.9158),
    StationInfo(id: '1006-607', name: '증산', lat: 37.5842, lng: 126.9098),
    StationInfo(id: '1006-608', name: '디지털미디어시티', lat: 37.5772, lng: 126.8996, transferLines: ['1063', '1065']),
    StationInfo(id: '1006-609', name: '월드컵경기장', lat: 37.5683, lng: 126.8973),
    StationInfo(id: '1006-610', name: '마포구청', lat: 37.5630, lng: 126.9015),
    StationInfo(id: '1006-611', name: '망원', lat: 37.5563, lng: 126.9103),
    StationInfo(id: '1006-612', name: '합정', lat: 37.5494, lng: 126.9137, transferLines: ['1002']),
    StationInfo(id: '1006-613', name: '상수', lat: 37.5478, lng: 126.9236),
    StationInfo(id: '1006-614', name: '광흥창', lat: 37.5478, lng: 126.9317),
    StationInfo(id: '1006-615', name: '대흥', lat: 37.5478, lng: 126.9405),
    StationInfo(id: '1006-616', name: '공덕', lat: 37.5440, lng: 126.9517, transferLines: ['1005', '1063', '1065']),
    StationInfo(id: '1006-617', name: '효창공원앞', lat: 37.5394, lng: 126.9610, transferLines: ['1063']),
    StationInfo(id: '1006-618', name: '삼각지', lat: 37.5345, lng: 126.9737, transferLines: ['1004']),
    StationInfo(id: '1006-619', name: '녹사평', lat: 37.5344, lng: 126.9873),
    StationInfo(id: '1006-620', name: '이태원', lat: 37.5343, lng: 126.9945),
    StationInfo(id: '1006-621', name: '한강진', lat: 37.5395, lng: 127.0020),
    StationInfo(id: '1006-622', name: '버티고개', lat: 37.5479, lng: 127.0073),
    StationInfo(id: '1006-623', name: '약수', lat: 37.5544, lng: 127.0108, transferLines: ['1003']),
    StationInfo(id: '1006-624', name: '청구', lat: 37.5601, lng: 127.0141, transferLines: ['1005']),
    StationInfo(id: '1006-625', name: '신당', lat: 37.5659, lng: 127.0175, transferLines: ['1002']),
    StationInfo(id: '1006-626', name: '동묘앞', lat: 37.5719, lng: 127.0165, transferLines: ['1001']),
    StationInfo(id: '1006-627', name: '창신', lat: 37.5795, lng: 127.0153),
    StationInfo(id: '1006-628', name: '보문', lat: 37.5863, lng: 127.0197),
    StationInfo(id: '1006-629', name: '안암', lat: 37.5862, lng: 127.0295),
    StationInfo(id: '1006-630', name: '고려대', lat: 37.5898, lng: 127.0359),
    StationInfo(id: '1006-631', name: '월곡', lat: 37.6003, lng: 127.0394),
    StationInfo(id: '1006-632', name: '상월곡', lat: 37.6060, lng: 127.0499),
    StationInfo(id: '1006-633', name: '돌곶이', lat: 37.6107, lng: 127.0564),
    StationInfo(id: '1006-634', name: '석계', lat: 37.6158, lng: 127.0654, transferLines: ['1001']),
    StationInfo(id: '1006-635', name: '태릉입구', lat: 37.6173, lng: 127.0756, transferLines: ['1007']),
    StationInfo(id: '1006-636', name: '화랑대', lat: 37.6200, lng: 127.0847),
    StationInfo(id: '1006-637', name: '봉화산', lat: 37.6177, lng: 127.0915),
    StationInfo(id: '1006-638', name: '신내', lat: 37.6133, lng: 127.1041, transferLines: ['1063']),
  ];

  // ──────────────────────────────────────────
  // 7호선 (장암 ~ 석남)
  // ──────────────────────────────────────────
  static const List<StationInfo> line7Stations = [
    StationInfo(id: '1007-700', name: '장암', lat: 37.6980, lng: 127.0534),
    StationInfo(id: '1007-701', name: '도봉산', lat: 37.6896, lng: 127.0447, transferLines: ['1001']),
    StationInfo(id: '1007-702', name: '수락산', lat: 37.6767, lng: 127.0553),
    StationInfo(id: '1007-703', name: '마들', lat: 37.6653, lng: 127.0578),
    StationInfo(id: '1007-704', name: '노원', lat: 37.6553, lng: 127.0616, transferLines: ['1004']),
    StationInfo(id: '1007-705', name: '중계', lat: 37.6445, lng: 127.0646),
    StationInfo(id: '1007-706', name: '하계', lat: 37.6387, lng: 127.0669),
    StationInfo(id: '1007-707', name: '공릉', lat: 37.6258, lng: 127.0731),
    StationInfo(id: '1007-708', name: '태릉입구', lat: 37.6173, lng: 127.0756, transferLines: ['1006']),
    StationInfo(id: '1007-709', name: '먹골', lat: 37.6102, lng: 127.0776),
    StationInfo(id: '1007-710', name: '중화', lat: 37.6023, lng: 127.0811),
    StationInfo(id: '1007-711', name: '상봉', lat: 37.5962, lng: 127.0855, transferLines: ['1063']),
    StationInfo(id: '1007-712', name: '면목', lat: 37.588, lng: 127.0876),
    StationInfo(id: '1007-713', name: '사가정', lat: 37.5786, lng: 127.0878),
    StationInfo(id: '1007-714', name: '용마산', lat: 37.5730, lng: 127.0868),
    StationInfo(id: '1007-715', name: '중곡', lat: 37.5657, lng: 127.0851),
    StationInfo(id: '1007-716', name: '군자', lat: 37.5572, lng: 127.0795, transferLines: ['1005']),
    StationInfo(id: '1007-717', name: '어린이대공원', lat: 37.5482, lng: 127.0761),
    StationInfo(id: '1007-718', name: '건대입구', lat: 37.5403, lng: 127.0695, transferLines: ['1002']),
    StationInfo(id: '1007-719', name: '뚝섬유원지', lat: 37.5313, lng: 127.0671),
    StationInfo(id: '1007-720', name: '청담', lat: 37.5197, lng: 127.0540),
    StationInfo(id: '1007-721', name: '강남구청', lat: 37.5172, lng: 127.0410, transferLines: ['1075']),
    StationInfo(id: '1007-722', name: '학동', lat: 37.5148, lng: 127.0316),
    StationInfo(id: '1007-723', name: '논현', lat: 37.5113, lng: 127.0219),
    StationInfo(id: '1007-724', name: '반포', lat: 37.5081, lng: 127.0118),
    StationInfo(id: '1007-725', name: '고속터미널', lat: 37.5047, lng: 127.0049, transferLines: ['1003', '1009']),
    StationInfo(id: '1007-726', name: '내방', lat: 37.4897, lng: 126.9974),
    StationInfo(id: '1007-727', name: '총신대입구', lat: 37.4868, lng: 126.9818, transferLines: ['1004']),
    StationInfo(id: '1007-728', name: '남성', lat: 37.4844, lng: 126.9725),
    StationInfo(id: '1007-729', name: '숭실대입구', lat: 37.4966, lng: 126.9535),
    StationInfo(id: '1007-730', name: '상도', lat: 37.5037, lng: 126.9473),
    StationInfo(id: '1007-731', name: '장승배기', lat: 37.5051, lng: 126.9394),
    StationInfo(id: '1007-732', name: '신대방삼거리', lat: 37.5012, lng: 126.9290),
    StationInfo(id: '1007-733', name: '보라매', lat: 37.4985, lng: 126.9202),
    StationInfo(id: '1007-734', name: '신풍', lat: 37.5001, lng: 126.9096),
    StationInfo(id: '1007-735', name: '대림', lat: 37.4934, lng: 126.8968, transferLines: ['1002']),
    StationInfo(id: '1007-736', name: '남구로', lat: 37.4859, lng: 126.8877),
    StationInfo(id: '1007-737', name: '가산디지털단지', lat: 37.4820, lng: 126.8826, transferLines: ['1001']),
    StationInfo(id: '1007-738', name: '철산', lat: 37.4756, lng: 126.8695),
    StationInfo(id: '1007-739', name: '광명사거리', lat: 37.4787, lng: 126.8570),
    StationInfo(id: '1007-740', name: '천왕', lat: 37.4827, lng: 126.8429),
    StationInfo(id: '1007-741', name: '온수', lat: 37.4919, lng: 126.8248, transferLines: ['1001']),
    // ── 부천 연장 (까치울 ~ 석남) ──
    StationInfo(id: '1007-742', name: '까치울', lat: 37.4953, lng: 126.8170),
    StationInfo(id: '1007-743', name: '부천종합운동장', lat: 37.5055, lng: 126.7975),
    StationInfo(id: '1007-744', name: '춘의', lat: 37.5047, lng: 126.7850),
    StationInfo(id: '1007-745', name: '신중동', lat: 37.5037, lng: 126.7714),
    StationInfo(id: '1007-746', name: '부천시청', lat: 37.5050, lng: 126.7619),
    StationInfo(id: '1007-747', name: '상동', lat: 37.5059, lng: 126.7525),
    StationInfo(id: '1007-748', name: '삼산체육관', lat: 37.5068, lng: 126.7368),
    StationInfo(id: '1007-749', name: '석남', lat: 37.5077, lng: 126.7176),
  ];

  // ──────────────────────────────────────────
  // 8호선 (암사 ~ 모란)
  // ──────────────────────────────────────────
  static const List<StationInfo> line8Stations = [
    StationInfo(id: '1008-800', name: '암사', lat: 37.5499, lng: 127.1275),
    StationInfo(id: '1008-801', name: '천호', lat: 37.5385, lng: 127.1231, transferLines: ['1005']),
    StationInfo(id: '1008-802', name: '강동구청', lat: 37.5302, lng: 127.1221),
    StationInfo(id: '1008-803', name: '몽촌토성', lat: 37.5175, lng: 127.1126),
    StationInfo(id: '1008-804', name: '잠실', lat: 37.5133, lng: 127.1001, transferLines: ['1002']),
    StationInfo(id: '1008-805', name: '석촌', lat: 37.5050, lng: 127.1049, transferLines: ['1009']),
    StationInfo(id: '1008-806', name: '송파', lat: 37.5002, lng: 127.1098),
    StationInfo(id: '1008-807', name: '가락시장', lat: 37.4926, lng: 127.1183, transferLines: ['1003']),
    StationInfo(id: '1008-808', name: '문정', lat: 37.4843, lng: 127.1233),
    StationInfo(id: '1008-809', name: '장지', lat: 37.4782, lng: 127.1260),
    StationInfo(id: '1008-810', name: '복정', lat: 37.4713, lng: 127.1265, transferLines: ['1075']),
    StationInfo(id: '1008-811', name: '산성', lat: 37.4611, lng: 127.1422),
    StationInfo(id: '1008-812', name: '남한산성입구', lat: 37.4492, lng: 127.1588),
    StationInfo(id: '1008-813', name: '단대오거리', lat: 37.4445, lng: 127.1577),
    StationInfo(id: '1008-814', name: '신흥', lat: 37.4415, lng: 127.1489),
    StationInfo(id: '1008-815', name: '수진', lat: 37.4362, lng: 127.1401),
    StationInfo(id: '1008-816', name: '모란', lat: 37.434, lng: 127.1303, transferLines: ['1075']),
  ];

  // ──────────────────────────────────────────
  // 9호선 (개화 ~ 중앙보훈병원)
  // ──────────────────────────────────────────
  static const List<StationInfo> line9Stations = [
    StationInfo(id: '1009-900', name: '개화', lat: 37.5776, lng: 126.7940),
    StationInfo(id: '1009-901', name: '김포공항', lat: 37.5623, lng: 126.8010, transferLines: ['1005', '1065']),
    StationInfo(id: '1009-902', name: '공항시장', lat: 37.5624, lng: 126.809),
    StationInfo(id: '1009-903', name: '신방화', lat: 37.5670, lng: 126.8230),
    StationInfo(id: '1009-904', name: '마곡나루', lat: 37.5665, lng: 126.8332, transferLines: ['1065']),
    StationInfo(id: '1009-905', name: '양천향교', lat: 37.5628, lng: 126.8479),
    StationInfo(id: '1009-906', name: '가양', lat: 37.5616, lng: 126.8569),
    StationInfo(id: '1009-907', name: '증미', lat: 37.5566, lng: 126.863),
    StationInfo(id: '1009-908', name: '등촌', lat: 37.5495, lng: 126.8676),
    StationInfo(id: '1009-909', name: '염창', lat: 37.5471, lng: 126.8738),
    StationInfo(id: '1009-910', name: '신목동', lat: 37.5449, lng: 126.8810),
    StationInfo(id: '1009-911', name: '선유도', lat: 37.5392, lng: 126.8913),
    StationInfo(id: '1009-912', name: '당산', lat: 37.5340, lng: 126.9027, transferLines: ['1002']),
    StationInfo(id: '1009-913', name: '국회의사당', lat: 37.5283, lng: 126.9178),
    StationInfo(id: '1009-914', name: '여의도', lat: 37.5215, lng: 126.9245, transferLines: ['1005']),
    StationInfo(id: '1009-915', name: '샛강', lat: 37.5170, lng: 126.9310),
    StationInfo(id: '1009-916', name: '노량진', lat: 37.5132, lng: 126.9424, transferLines: ['1001']),
    StationInfo(id: '1009-917', name: '노들', lat: 37.5127, lng: 126.9506),
    StationInfo(id: '1009-918', name: '흑석', lat: 37.5082, lng: 126.9634),
    StationInfo(id: '1009-919', name: '동작', lat: 37.5121, lng: 126.959, transferLines: ['1004']),
    StationInfo(id: '1009-920', name: '구반포', lat: 37.5018, lng: 126.9891),
    StationInfo(id: '1009-921', name: '신반포', lat: 37.5038, lng: 126.9973),
    StationInfo(id: '1009-922', name: '고속터미널', lat: 37.5047, lng: 127.0049, transferLines: ['1003', '1007']),
    StationInfo(id: '1009-923', name: '사평', lat: 37.5040, lng: 127.0135),
    StationInfo(id: '1009-924', name: '신논현', lat: 37.5044, lng: 127.0247, transferLines: ['1077']),
    StationInfo(id: '1009-925', name: '언주', lat: 37.5073, lng: 127.0343),
    StationInfo(id: '1009-926', name: '선정릉', lat: 37.5104, lng: 127.0432),
    StationInfo(id: '1009-927', name: '삼성중앙', lat: 37.5132, lng: 127.0543),
    StationInfo(id: '1009-928', name: '봉은사', lat: 37.5139, lng: 127.0631),
    StationInfo(id: '1009-929', name: '종합운동장', lat: 37.5108, lng: 127.0737, transferLines: ['1002']),
    StationInfo(id: '1009-930', name: '삼전', lat: 37.5054, lng: 127.0841),
    StationInfo(id: '1009-931', name: '석촌고분', lat: 37.5041, lng: 127.0966),
    StationInfo(id: '1009-932', name: '석촌', lat: 37.5050, lng: 127.1049, transferLines: ['1008']),
    StationInfo(id: '1009-933', name: '송파나루', lat: 37.5084, lng: 127.1110),
    StationInfo(id: '1009-934', name: '한성백제', lat: 37.5070, lng: 127.1097),
    StationInfo(id: '1009-935', name: '올림픽공원', lat: 37.5161, lng: 127.1310, transferLines: ['1005']),
    StationInfo(id: '1009-936', name: '둔촌오륜', lat: 37.5204, lng: 127.1400),
    StationInfo(id: '1009-937', name: '중앙보훈병원', lat: 37.5243, lng: 127.1470),
  ];

  // ──────────────────────────────────────────
  // 1호선 경인선 지선 (구로 → 인천)
  // ──────────────────────────────────────────
  static const List<StationInfo> line1GyeonginStations = [
    StationInfo(id: '1001-141', name: '구로', lat: 37.5033, lng: 126.8824),
    StationInfo(id: '1001-200', name: '구일', lat: 37.4964, lng: 126.8702),
    StationInfo(id: '1001-201', name: '개봉', lat: 37.4953, lng: 126.8553),
    StationInfo(id: '1001-202', name: '오류동', lat: 37.4943, lng: 126.8447),
    StationInfo(id: '1001-203', name: '온수', lat: 37.4929, lng: 126.8280, transferLines: ['1007']),
    StationInfo(id: '1001-204', name: '역곡', lat: 37.4853, lng: 126.8124),
    StationInfo(id: '1001-205', name: '소사', lat: 37.4825, lng: 126.8011),
    StationInfo(id: '1001-206', name: '부천', lat: 37.4829, lng: 126.7902),
    StationInfo(id: '1001-207', name: '중동', lat: 37.4849, lng: 126.7765),
    StationInfo(id: '1001-208', name: '송내', lat: 37.4869, lng: 126.7618),
    StationInfo(id: '1001-209', name: '부개', lat: 37.4879, lng: 126.7489),
    StationInfo(id: '1001-210', name: '부평', lat: 37.4892, lng: 126.7281),
    StationInfo(id: '1001-211', name: '백운', lat: 37.4881, lng: 126.7148),
    StationInfo(id: '1001-212', name: '동암', lat: 37.4778, lng: 126.7034),
    StationInfo(id: '1001-213', name: '간석', lat: 37.4656, lng: 126.7009),
    StationInfo(id: '1001-214', name: '주안', lat: 37.4648, lng: 126.6823),
    StationInfo(id: '1001-215', name: '도화', lat: 37.4662, lng: 126.6665),
    StationInfo(id: '1001-216', name: '제물포', lat: 37.4667, lng: 126.6496),
    StationInfo(id: '1001-217', name: '도원', lat: 37.4700, lng: 126.6397),
    StationInfo(id: '1001-218', name: '동인천', lat: 37.4804, lng: 126.6261),
    StationInfo(id: '1001-219', name: '인천', lat: 37.4764, lng: 126.6170),
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
    StationInfo(id: '1002-401', name: '양천구청', lat: 37.5148, lng: 126.8718),
    StationInfo(id: '1002-402', name: '신정네거리', lat: 37.5276, lng: 126.8489),
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
    StationInfo(id: '1005-604', name: '개롱', lat: 37.4956, lng: 127.1397),
    StationInfo(id: '1005-605', name: '거여', lat: 37.4929, lng: 127.1480),
    StationInfo(id: '1005-606', name: '마천', lat: 37.4945, lng: 127.1524),
  ];
}