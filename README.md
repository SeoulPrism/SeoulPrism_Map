# SeoulPrism_Map 📍

SeoulPrism 프로젝트를 위한 **3D 지도 엔진 통합 테스트 및 서울시 공공데이터 시각화 대시보드**입니다. 
심미성보다는 기능 검증, API 성능 테스트, 3D 렌더링 파라미터 튜닝에 중점을 둔 **Debug-First Dashboard** 철학으로 설계되었습니다.

## 🚀 프로젝트 개요
- **목적**: Mapbox, Google Maps, Naver Map 등 다양한 지도 SDK의 3D 성능을 비교 분석하고, 서울시 실시간 공공데이터(따릉이, 교통량 등)와의 통합 가능성을 검증합니다.
- **주요 타겟**: 3D 도시 모델링 시각화 및 실시간 데이터 매핑이 필요한 모바일 서비스 앱.

## 🛠 기술 스택
- **Framework**: Flutter (v3.x+)
- **Map Engines**: 
  - [Mapbox Maps Flutter SDK](https://github.com/mapbox/mapbox-maps-flutter) (v2.x) - 3D 빌딩 및 지형 특화
  - [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter) - 글로벌 표준 지도 테스트
  - [Flutter Naver Map](https://github.com/note11g/flutter_naver_map) - 국내 데이터 및 환경 최적화
- **API**: 서울시 열린데이터 광장 (실시간 따릉이, 도로 소통 정보 등)

## ✨ 핵심 기능
### 1. Multi-Engine Switching
- `IMapController` 인터페이스를 통해 동일한 명령(이동, 줌, 피치 조절)을 각기 다른 지도 엔진에 동일하게 전달.
- 앱 내에서 Mapbox, Google, Naver 엔진을 실시간으로 스위칭하며 렌더링 품질 비교.

### 2. Debug-First Dashboard (UI/UX)
- **Floating Debug Panel**: 현재 카메라의 좌표(Lat/Lng), Zoom, Pitch, Bearing 정보를 실시간 모니터링.
- **Parameter Tuner**: Slider를 이용한 Pitch(최대 75도) 및 Zoom 조절을 통해 3D 입체감 테스트.
- **Stress Test**: 수천 개의 마커(Annotation) 렌더링 시 FPS 드랍 및 성능 측정 기능.

### 3. Advanced 3D Rendering (Mapbox Focus)
- **Standard Style**: 최신 Mapbox 3D 모델 및 조명 시스템 적용.
- **3D Terrain**: 지형 데이터를 활용한 서울 산지 및 지각 변동 시각화.
- **Light Presets**: Day, Night, Dusk, Dawn 프리셋을 통한 시간대별 3D 조명 시뮬레이션.

## 📂 폴더 구조
```
lib/
├── core/               # 공통 인터페이스, API 키 관리 및 데이터 모델
├── map_engines/        # Mapbox, Google, Naver 지도별 구체적인 구현체
├── services/           # 서울시 API 연동 (SeoulApiService)
└── widgets/            # 디버그 패널 및 컨트롤 슬라이더 UI 컴포넌트
```

## ⚙️ 설정 방법 (Getting Started)

### 1. API 키 설정
보안을 위해 `lib/core/api_keys.dart` 파일을 생성하고(자동 `.gitignore` 처리됨) 아래와 같이 키를 입력하세요.
```dart
class ApiKeys {
  static const String mapboxAccessToken = 'YOUR_MAPBOX_TOKEN';
  static const String naverClientId = 'YOUR_NAVER_ID';
}
```

### 2. 플랫폼별 설정
- **Android**: `android/app/build.gradle.kts`에서 `minSdk 24` 확인 및 `gradle.properties`에 `MAPBOX_DOWNLOADS_TOKEN` 입력 필요.
- **iOS**: `ios/Runner/Info.plist`에 위치 권한 설명 추가 및 `Podfile` 배포 타겟 14.0 확인.

## 📝 개발 로드맵 (Checklist)
- [x] 멀티 지도 엔진 래퍼 구조 구현 (#1)
- [x] 디버그용 실시간 파라미터 대시보드 구축 (#1)
- [x] Mapbox 3D 건물 및 지형 엔진 연동 (#1)
- [x] 서울시 지하철 실시간 열차 위치정보 API 연동 (OA-12601)
- [x] 서울시 지하철 실시간 도착정보 API 연동 (OA-12764)
- [x] 서울시 지하철 실시간 도착정보 일괄 API 연동 (OA-15799)
- [x] 서울시 지하철역 연계 지하도 공간정보 API 연동 (OA-21213)
- [x] 서울시 지하철 출입구 리프트 위치정보 API 연동 (OA-21211)
- [x] MiniTokyo3D 스타일 열차 위치 보간 엔진 구현
- [x] 노선 경로 시각화 (1~9호선 + 주요 노선)
- [x] 실시간 열차 위치 지도 오버레이
- [x] 역 도착정보 패널 UI
- [ ] 특정 건물 하이라이트 및 클릭 이벤트 처리
- [ ] AI Fly-To (임의 좌표 부드러운 카메라 애니메이션) 구현

## 데이터 출처
### 서울시 지하철 실시간 열차 위치정보
https://data.seoul.go.kr/dataList/OA-12601/A/1/datasetView.do
### 서울시 지하철 실시간 도착정보
https://data.seoul.go.kr/dataList/OA-12764/F/1/datasetView.do
### 서울시 지하철 실시간 도착정보(일괄)
https://data.seoul.go.kr/dataList/OA-15799/A/1/datasetView.do
### 서울시 지하철역 연계 지하도 공간정보
https://data.seoul.go.kr/dataList/OA-21213/S/1/datasetView.do
### 서울시 지하철 출입구 리프트 위치정보
https://data.seoul.go.kr/dataList/OA-21211/S/1/datasetView.do

## 참고 
https://minitokyo3d.com/#15.2/35.678432/139.766166/0/60