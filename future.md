# RunRight — 미구현 항목 목록

---

## 🔴 우선순위 높음 (앱 정상 동작에 필요)

### 1. 로그인 후 기존 프로필 자동 불러오기
- **현재**: 로그인하면 항상 신체 데이터 입력 화면(BodySetupScreen)으로 이동
- **문제**: 기존 사용자가 매번 신체 데이터를 다시 입력해야 함
- **필요한 작업**:
  - `main.dart`의 로그인 분기에서 Firebase DB에 저장된 프로필 조회
  - 프로필 있음 → HomeScreen으로 이동
  - 프로필 없음 → BodySetupScreen으로 이동
- **관련 파일**: `lib/main.dart`, `lib/services/database_service.dart`

### 2. 앱 재실행 시 프로필 상태 유지
- **현재**: 앱을 완전히 종료 후 재실행하면 `RunningProvider.profile`이 null로 초기화됨
- **문제**: 홈 화면에서 맞춤 페이스 카드가 표시되지 않음
- **필요한 작업**:
  - 앱 시작 시 Firebase DB에서 프로필 불러와 Provider에 주입
  - `DatabaseService.getProfile(uid)` 호출 후 `setProfile()` 연결
- **관련 파일**: `lib/services/running_provider.dart`, `lib/main.dart`

---

## 🟠 우선순위 중간 (주요 UX 개선)

### 3. 비밀번호 찾기 / 재설정
- **현재**: 비밀번호를 잊어버리면 방법 없음
- **필요한 작업**:
  - `AuthService`에 `sendPasswordResetEmail()` 메서드 추가
  - 로그인 화면에 "비밀번호를 잊으셨나요?" 버튼 추가
- **관련 파일**: `lib/services/auth_service.dart`, `lib/screens/login_screen.dart`

### 4. 신체 데이터 수정 기능
- **현재**: 최초 입력 후 수정 불가
- **필요한 작업**:
  - 홈 화면에 "프로필 수정" 버튼 추가
  - 기존 값이 채워진 BodySetupScreen 재활용 또는 별도 수정 화면 구현
  - 수정 후 Firebase DB 프로필 업데이트
- **관련 파일**: `lib/screens/home_screen.dart`, `lib/screens/body_setup_screen.dart`

### 5. 러닝 기록 삭제 기능
- **현재**: `DatabaseService.deleteSession()`이 구현되어 있지만 UI 없음
- **필요한 작업**:
  - 홈 화면 기록 카드에 스와이프 삭제 또는 길게 누르기 삭제 UI 추가
- **관련 파일**: `lib/screens/home_screen.dart`, `lib/services/database_service.dart`

### 6. 러닝 기록 상세 보기
- **현재**: 홈 화면에서 기록 카드를 탭해도 아무 반응 없음
- **필요한 작업**:
  - 기록 카드 탭 시 상세 화면으로 이동
  - 상세 화면에서 페이스 변화 그래프, 러닝 경로 지도 등 표시
  - `ResultScreen` 재활용 가능
- **관련 파일**: `lib/screens/home_screen.dart`

### 7. 러닝 중 화면 켜짐 유지 (WakeLock)
- **현재**: `AndroidManifest.xml`에 `WAKE_LOCK` 권한은 선언했지만 실제 사용 코드 없음
- **문제**: 러닝 중 화면이 꺼지면 GPS 측정이 불안정해질 수 있음
- **필요한 작업**:
  - `wakelock_plus` 패키지 추가
  - 러닝 시작 시 WakeLock 활성화, 종료 시 해제
- **관련 파일**: `lib/services/running_provider.dart`

---

## 🟡 우선순위 낮음 (추가 기능)

### 8. 백그라운드 GPS 추적
- **현재**: 앱이 백그라운드로 가면 GPS 추적 중단됨
- **필요한 작업**:
  - Android Foreground Service 구현
  - 러닝 중 알림 표시 (현재 페이스, 거리)
  - `permission_handler`에서 백그라운드 위치 권한 요청 (`ACCESS_BACKGROUND_LOCATION`)

### 9. 러닝 경로 지도 표시
- **현재**: `PaceRecord`에 위도/경도가 저장되지만 지도에 표시 안 됨
- **필요한 작업**:
  - `google_maps_flutter` 또는 `flutter_map` 패키지 추가
  - 결과 화면 또는 기록 상세 화면에서 경로 폴리라인으로 표시

### 10. 통계 화면
- **현재**: 개별 기록만 볼 수 있고 누적 통계 없음
- **필요한 작업**:
  - 주간 / 월간 총 거리, 평균 페이스 추이 화면 추가
  - Firebase DB 기록 집계 로직 구현

### 11. iOS 지원
- **현재**: Android만 설정 완료 (`google-services.json`)
- **필요한 작업**:
  - Firebase 콘솔에서 iOS 앱 등록
  - `GoogleService-Info.plist` 다운로드 후 `ios/Runner/`에 추가
  - Xcode에서 번들 ID, 서명 설정

### 12. 앱 아이콘 / 스플래시 스크린
- **현재**: 기본 Flutter 아이콘 사용 중
- **필요한 작업**:
  - RunRight 전용 아이콘 디자인 후 `flutter_launcher_icons` 패키지로 적용
  - `flutter_native_splash` 패키지로 스플래시 화면 적용

### 13. 소셜 로그인
- **현재**: 이메일/비밀번호만 지원
- **필요한 작업**:
  - `google_sign_in` 패키지로 구글 로그인 추가
  - Firebase 콘솔에서 Google 로그인 제공업체 활성화

### 14. Firebase 보안 규칙 적용
- **현재**: Realtime Database가 테스트 모드(30일 제한)로 설정되어 있을 가능성 있음
- **필요한 작업**: Firebase 콘솔에서 아래 보안 규칙으로 교체
  ```json
  {
    "rules": {
      "users": {
        "$uid": {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid"
        }
      }
    }
  }
  ```

---

## 요약표

| 항목 | 우선순위 | 난이도 |
|------|----------|--------|
| 로그인 후 기존 프로필 불러오기 | 🔴 높음 | 낮음 |
| 앱 재실행 시 프로필 상태 유지 | 🔴 높음 | 낮음 |
| 비밀번호 찾기 | 🟠 중간 | 낮음 |
| 신체 데이터 수정 | 🟠 중간 | 중간 |
| 러닝 기록 삭제 UI | 🟠 중간 | 낮음 |
| 러닝 기록 상세 보기 | 🟠 중간 | 중간 |
| 러닝 중 화면 켜짐 유지 | 🟠 중간 | 낮음 |
| 백그라운드 GPS 추적 | 🟡 낮음 | 높음 |
| 러닝 경로 지도 표시 | 🟡 낮음 | 중간 |
| 통계 화면 | 🟡 낮음 | 중간 |
| iOS 지원 | 🟡 낮음 | 중간 |
| 앱 아이콘 / 스플래시 | 🟡 낮음 | 낮음 |
| 소셜 로그인 | 🟡 낮음 | 중간 |
| Firebase 보안 규칙 | 🟡 낮음 | 낮음 |
