# SeoulPrism-Map

SeoulPrism 프로젝트의 **3D 지도 엔진 및 서울시 공공데이터 실시간 시각화 모듈**이다. 서울 지하철 네트워크의 실시간 운행 상황을 60fps 보간 엔진으로 3D 지도 위에 재현하며, MiniTokyo3D의 서울 버전을 모바일 환경에서 구현하는 것을 목표로 한다.

## 핵심 가치

| 가치 | 설명 |
|------|------|
| **실시간성** | 서울시 열린데이터 API 5분 주기 수신 + 60fps 프레임 보간으로 끊김 없는 열차 이동 |
| **정밀성** | OSM 실제 노선 지오메트리 기반 경로 추종 — 직선이 아닌 실제 선로 곡선을 따라 이동 |
| **확장성** | 멀티 지도 엔진 추상화 계층을 통해 Mapbox, Google Maps, Naver Map 간 자유 전환 |
| **개방성** | 서울시 공공데이터(5종) 기반, 별도 수집 인프라 없이 운영 가능 |

---

## 기술 스택

- **Framework**: Flutter 3.x (Dart)
- **Map Engines**: Mapbox Maps Flutter SDK 2.x / Google Maps Flutter 2.x / Flutter Naver Map 1.x
- **Data**: 서울시 열린데이터 광장 REST API (5종)
- **Geo**: OpenStreetMap GeoJSON (서울 지하철 노선 경로)
- **Rendering**: Material 3 Dark Theme, 60fps 애니메이션 타이머

## 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                     │
│     SubwayOverlay · SubwayPanel · DebugDashboard    │
├─────────────────────────────────────────────────────┤
│                      Services                       │
│    TrainSimulator · TrainInterpolator               │
│    SeoulSubwayService · SeoulApiService             │
├─────────────────────────────────────────────────────┤
│                    Data / Models                    │
│    RouteGeometry · SubwayModels · SubwayData        │
│    SubwayGeoJsonLoader                              │
├─────────────────────────────────────────────────────┤
│                 Map Abstraction Layer               │
│          IMapController (Common Interface)          │
│    MapboxEngine · GoogleMapEngine · NaverEngine     │
└─────────────────────────────────────────────────────┘
```

`IMapController` 인터페이스가 카메라 제어, 마커/폴리라인 관리, 3D 레이어 렌더링, 지하철 전용 확장을 통일된 API로 제공한다. `MapType` enum으로 런타임에 엔진을 전환하며, 동일 명령이 각 엔진의 네이티브 SDK로 변환된다.

---

## 핵심 기능

### 실시간 열차 위치 시각화

서울 지하철 16개 노선(1~9호선, 경의중앙, 수인분당, 신분당 등)의 실시간 열차 위치를 지도에 표시한다.

1. 서울시 API(OA-12601)에서 5분 주기로 전체 열차 위치 스냅샷 수신
2. `TrainSimulator`가 시간표 기반 속도(역간 100초, 정차 20초)로 외삽
3. `TrainInterpolator`가 OSM GeoJSON 지오메트리를 따라 프레임 단위 좌표 계산
4. 60fps 타이머로 매 프레임 마커 위치 갱신
5. API 갱신 시 이전/신규 위치 간 블렌딩으로 시각적 점프 방지

열차 상태: arriving, stopped, departing, mid-station 4단계 구분.

### 노선 경로 시각화

OSM 실제 선로 지오메트리를 폴리라인으로 렌더링. 서울교통공사 지정 RGB 색상 적용, 노선별 필터링 토글 지원. `RouteGeometry`가 누적 거리 사전 계산 및 역 좌표 스냅으로 보간 정확도 확보.

### 역 도착정보 패널

특정 역 선택 시 실시간 도착 예정 열차 목록 표시. 카운트다운, 행선지, 급행/막차 여부 제공.

### 운영 모드

| 모드 | 설명 |
|------|------|
| **Live** | 서울시 API 실시간 데이터. 일일 쿼터(1,000회) 자동 관리, 예산 소진 시 호출 간격 자동 확장 |
| **Demo** | 가상 열차 생성. 출퇴근 시간대 빈도 조정. 네트워크 없이 시연 가능 |

### 3D 렌더링 (Mapbox)

- **3D 건물**: Mapbox Standard Style 기반 서울 도심 빌딩 모델
- **3D 지형**: DEM 데이터 활용 산지 표현
- **조명 프리셋**: Day / Night / Dusk / Dawn
- **카메라**: Pitch(최대 75도), Zoom, Bearing 실시간 조절

### 디버그 대시보드

- 카메라 좌표, Zoom, Pitch, Bearing 실시간 표시
- 파라미터 슬라이더를 통한 3D 렌더링 튜닝
- 대량 마커 렌더링 스트레스 테스트

---

## 데이터 소스

| API 코드 | 명칭 | 용도 |
|-----------|------|------|
| OA-12601 | 지하철 실시간 열차 위치정보 | 열차 현재 위치 (5분 주기) |
| OA-12764 | 지하철 실시간 도착정보 | 특정 역 도착 예정 열차 |
| OA-15799 | 지하철 실시간 도착정보 (일괄) | 전체 역 일괄 조회 |
| OA-21213 | 지하철역 연계 지하도 공간정보 | 역 지하공간 WKT 좌표 |
| OA-21211 | 지하철 출입구 리프트 위치정보 | 엘리베이터/에스컬레이터 좌표 |

OSM GeoJSON: `south-korea-latest.osm.pbf`에서 지하철 relation 필터링, 노선별 좌표 시퀀스 분리.

---

## 설정 방법

### API 키 설정

`lib/core/api_keys.dart` 생성 (`.gitignore` 처리됨):
```dart
class ApiKeys {
  static const String mapboxAccessToken = 'YOUR_MAPBOX_TOKEN';
  static const String naverClientId = 'YOUR_NAVER_ID';
}
```

### 플랫폼 설정

- **Android**: `build.gradle.kts`에서 `minSdk 24`, `gradle.properties`에 `MAPBOX_DOWNLOADS_TOKEN`
- **iOS**: `Info.plist` 위치 권한, `Podfile` 배포 타겟 14.0

---

## 폴더 구조

```
lib/
├── core/               # 공통 인터페이스, API 키, 데이터 모델
├── map_engines/        # Mapbox, Google, Naver 엔진 구현체
├── models/             # 지하철 도메인 모델 (14+ 클래스)
├── data/               # 노선 지오메트리, 역 데이터, GeoJSON 로더
├── services/           # API 연동, 열차 시뮬레이터, 보간 엔진
└── widgets/            # 오버레이, 패널, 디버그 UI 컴포넌트
```

## 로드맵

- [x] 멀티 지도 엔진 래퍼 아키텍처
- [x] 디버그 대시보드 및 파라미터 튜닝
- [x] Mapbox 3D 건물/지형/조명
- [x] 서울시 공공 API 5종 연동
- [x] MiniTokyo3D 스타일 보간 엔진 (OSM 기반)
- [x] 노선 경로 시각화 (16개 노선)
- [x] 실시간 열차 위치 오버레이 (60fps)
- [x] 역 도착정보 패널
- [x] Demo/Live 이중 운영 모드
- [ ] 건물 하이라이트 및 클릭 이벤트
- [ ] AI Fly-To 시네마틱 카메라 애니메이션
- [ ] 따릉이 실시간 대여소 현황
- [ ] 도로 교통량 히트맵 오버레이
- [ ] 지하공간 3D 모델링

## 참고

- MiniTokyo3D: https://minitokyo3d.com
- 서울시 열린데이터 광장: https://data.seoul.go.kr
- OpenStreetMap: https://www.openstreetmap.org