# 🏃 RunRight
> 러닝 입문자를 위한 신체 맞춤형 실시간 페이스 코칭 앱

<br>

## 📌 프로젝트 소개

RunRight는 러닝을 처음 시작하는 입문자가 **자신의 신체 데이터를 기반으로 최적의 페이스를 유지**하며 안전하게 달릴 수 있도록 돕는 모바일 앱입니다.

기존 러닝 앱(나이키 러닝 클럽, 삼성 헬스 등)은 숙련된 러너 중심으로 설계되어 초보자가 오버페이스로 인한 부상이나 포기로 이어지는 문제가 있습니다. RunRight는 **입문자 특화** 앱으로, 신체 데이터 분석을 통한 개인 맞춤 페이스 추천과 실시간 음성 코칭을 제공합니다.

<br>

## 👥 팀 정보

| 구분 | 이름 | 담당 기술 | 핵심 업무 |
|------|------|-----------|-----------|
| 팀원 1 (대표) | 원성민 | Flutter | 앱 전체 UI 디자인 및 화면 전환 구현 |
| 팀원 2 | 반준우 | GPS, TTS | 실시간 속도 측정 및 음성 코칭 엔진 개발 |
| 팀원 3 | 이준규 | Firebase Auth | 회원가입/로그인 및 서버 로직 관리 |
| 팀원 4 | 오중헌 | Realtime DB | 운동 데이터 저장 설계 및 앱 안정성 테스트 |

- **팀명**: 언더독
- **교과목**: AIX 프로젝트 심화 (C.D.) — 2026학년도 1학기
- **소속**: 선문대학교 AI소프트웨어학과

<br>

## ✨ 핵심 기능

### 🎯 신체 데이터 기반 맞춤 페이스 산출 (메인 기능)
- 키·몸무게·나이·성별·운동경험 입력
- 인바디 데이터(체지방률·골격근량) 선택 입력으로 더 정밀한 계산
- VO₂max 추정 → 유산소 효율 구간(50~65%) → 개인 맞춤 권장 페이스 산출

### 📡 실시간 GPS 페이스 측정
- 1~2초 간격 위치 수집
- Haversine 공식으로 정확한 거리 계산
- 5~10초 이동 평균 필터로 GPS 노이즈 제거

### 🔊 TTS 음성 코칭
- 권장 페이스 이탈 시 즉각적인 음성 피드백
- 15초 쿨다운으로 과도한 알림 방지
- 1km 통과 알림 / 시작·종료 안내

### 📊 러닝 기록 저장
- km당 페이스·이동 경로·소모 칼로리 기록
- 페이스 변화 그래프 시각화
- Firebase Realtime DB 연동 (개발 중)

<br>

## 🛠 기술 스택

| 분류 | 기술 |
|------|------|
| Framework | Flutter (Dart) |
| 상태관리 | Provider |
| GPS | geolocator |
| 음성 코칭 | flutter_tts |
| 인증 | Firebase Auth |
| 데이터베이스 | Firebase Realtime Database |
| 로컬 저장 | shared_preferences |

<br>

## 📁 프로젝트 구조

```
lib/
├── main.dart                    # 앱 시작점
├── core/
│   ├── constants.dart           # 색상·스타일 공통 상수
│   └── pace_calculator.dart     # ★ 핵심: 페이스 계산 알고리즘
├── models/
│   ├── body_profile.dart        # 신체 데이터 모델
│   └── running_session.dart     # 러닝 세션·기록 모델
├── services/
│   ├── gps_service.dart         # GPS 실시간 측정
│   ├── tts_service.dart         # TTS 음성 코칭
│   └── running_provider.dart    # 통합 상태관리 (Provider)
└── screens/
    ├── body_setup_screen.dart   # 신체 데이터 입력 (3단계)
    ├── pace_result_screen.dart  # 맞춤 페이스 결과
    ├── home_screen.dart         # 홈 화면
    ├── running_screen.dart      # 실시간 러닝
    └── result_screen.dart       # 러닝 결과
```

<br>

## 🚀 실행 방법

### 사전 요구사항
- Flutter SDK 3.0.0 이상
- Android Studio (에뮬레이터 또는 실기기)
- Firebase 프로젝트 설정 (아래 참고)

### 설치 및 실행

```bash
# 1. 저장소 클론
git clone https://github.com/[깃허브아이디]/runright_app.git
cd runright_app

# 2. 패키지 설치
flutter pub get

# 3. 앱 실행
flutter run
```

### Firebase 설정
1. [Firebase Console](https://console.firebase.google.com)에서 프로젝트 생성
2. `flutterfire configure` 실행
3. `lib/firebase_options.dart` 자동 생성 확인
4. `android/app/google-services.json` 배치
5. `lib/main.dart` 의 Firebase 관련 주석 해제

> ⚠️ `google-services.json` 과 `firebase_options.dart` 는 보안상 깃허브에 올리지 않습니다. 팀원 간 직접 공유하세요.

<br>

## 📱 앱 화면 흐름

```
신체 정보 입력 (3단계)
    ↓
맞춤 페이스 결과 확인   ← ★ 핵심 화면
    ↓
홈 화면 (내 페이스 항상 표시)
    ↓
실시간 러닝 (GPS + TTS 코칭)
    ↓
러닝 결과 확인
```

<br>

## ⚙️ 페이스 계산 알고리즘

```
1. VO₂max 추정
   - 나이·성별 기반 ACSM 간이공식
   - 체지방률 보정: 평균(남20%/여28%) 대비 차이만큼 조정
   - 골격근량 보정: 체중 대비 근육 비율로 조정
   - 운동경험 보정: 없음(0) / 간헐적(+3) / 꾸준히(+7)

2. 유산소 효율 구간 적용
   - VO₂max의 50% → 느린 한계 (여유 있는 페이스)
   - VO₂max의 65% → 빠른 한계 (가벼운 대화 가능)

3. 속도 → 페이스 변환
   - ml/kg/min → m/min → sec/km
```

<br>

## 🔗 관련 문서

- [개발환경 설치 가이드](docs/개발환경_설치가이드.docx)
- [앱 사용 가이드](docs/앱사용가이드.docx)
- [캡스톤디자인 계획서](docs/계획서.pdf)

<br>

## 📄 라이선스

본 프로젝트는 선문대학교 2026학년도 1학기 캡스톤디자인 과제로 제작되었습니다.

---

*RunRight — 당신의 첫 번째 러닝 코치* 🏃
