// lib/core/pace_calculator.dart
//
// ══════════════════════════════════════════════════
//  [메인 기능] 신체 데이터 기반 맞춤 페이스 산출기
// ══════════════════════════════════════════════════
//
// 흐름:
//   신체 데이터 (키·몸무게·나이·성별·운동경험·인바디)
//     ↓
//   VO2max 추정  (ACSM 간이공식)
//     ↓
//   유산소 효율 구간 (50~65% VO2max)
//     ↓
//   권장 페이스 범위 (sec/km)  ← 앱에 표시하는 핵심 값
//
// 참고: 계획서 4번 항목 「③ 신체 데이터 연산 및 페이스 추천 로직」
//       - 키·몸무게·나이·성별로 VO2max 추정
//       - 인바디(체지방률, 근육량) 입력 시 보정 계수 적용
//       - 러닝 세션 누적 시 자동 갱신 (추후 구현)

class PaceCalculator {
  PaceCalculator._();

  // ──────────────────────────────────────────────
  // 1. VO2max 추정 (ml/kg/min)
  // ──────────────────────────────────────────────
  /// 나이·성별 기반 최대산소섭취량 추정 (ACSM 간이식)
  static double estimateVO2max({
    required int    age,
    required String gender,       // 'male' | 'female'
    required String fitnessLevel, // 'none' | 'occasional' | 'regular'
    double? bodyFatPercent,
    double? muscleMassKg,
    double? weightKg,
  }) {
    // 기본 추정값 (성별·나이)
    double vo2 = gender == 'male'
        ? 56.363 - (0.381 * age)
        : 44.022 - (0.353 * age);

    // ── 인바디 보정 ────────────────────────────
    // 체지방률: 평균(남 20 / 여 28%)에서 벗어난 만큼 보정
    if (bodyFatPercent != null) {
      final avgFat = gender == 'male' ? 20.0 : 28.0;
      final delta  = (bodyFatPercent - avgFat) * 0.18;
      vo2 -= delta.clamp(-6.0, 8.0);
    }
    // 근육량: 체중 대비 비율로 보정
    if (muscleMassKg != null && weightKg != null && weightKg > 0) {
      final musclePct = muscleMassKg / weightKg * 100;
      final avgMuscle = gender == 'male' ? 47.0 : 40.0;
      final delta     = (musclePct - avgMuscle) * 0.12;
      vo2 += delta.clamp(-4.0, 6.0);
    }

    // ── 운동 경험 보정 ─────────────────────────
    switch (fitnessLevel) {
      case 'occasional': vo2 += 3; break;
      case 'regular':    vo2 += 7; break;
    }

    return vo2.clamp(15.0, 70.0);
  }

  // ──────────────────────────────────────────────
  // 2. 권장 페이스 범위 산출 (sec/km)
  // ──────────────────────────────────────────────
  /// 반환: [fastLimit, slowLimit]  (둘 다 sec/km, fastLimit < slowLimit)
  /// 예: [360, 480] → 6'00"/km ~ 8'00"/km
  static List<int> recommendedPaceRange({
    required double vo2max,
  }) {
    // VO2max → 속도(m/min) 변환 (Jack Daniels VDOT 근사)
    //   speed(m/min) = (VO2 + 3.5) / 3.5 * 3.5  ≈ VO2 * 0.287 (단순화)
    // 50% VO2max = 느린 한계 (더 여유)
    // 65% VO2max = 빠른 한계 (적당히 힘든 정도)
    final speedSlow = (vo2max * 0.50 * 0.287).clamp(50.0, 200.0); // m/min
    final speedFast = (vo2max * 0.65 * 0.287).clamp(60.0, 230.0); // m/min

    // m/min → sec/km  (1000m / speed_m_per_min * 60)
    final slowPace = (1000 / speedSlow * 60).round(); // 큰 값 = 느림
    final fastPace = (1000 / speedFast * 60).round(); // 작은 값 = 빠름

    return [fastPace, slowPace]; // [빠른 한계, 느린 한계]
  }

  // ──────────────────────────────────────────────
  // 3. 현재 페이스 상태 판정
  // ──────────────────────────────────────────────
  static PaceZone judgeZone({
    required int currentPaceSec,
    required int fastLimit,
    required int slowLimit,
  }) {
    if (currentPaceSec == 0)              return PaceZone.stopped;
    if (currentPaceSec < fastLimit)       return PaceZone.tooFast;
    if (currentPaceSec > slowLimit)       return PaceZone.tooSlow;
    return PaceZone.good;
  }

  // ──────────────────────────────────────────────
  // 4. 포맷 헬퍼
  // ──────────────────────────────────────────────
  /// sec/km → "6'30\"" 형식
  static String formatPace(int paceSec) {
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).toString().padLeft(2, '0');
    return "$m'$s\"";
  }

  /// sec/km → "6분 30초" (TTS용)
  static String formatPaceKorean(int paceSec) {
    final m = paceSec ~/ 60;
    final s = paceSec % 60;
    return '$m분 ${s.toString().padLeft(2, '0')}초';
  }

  /// 칼로리 추정 (MET × 체중 × 시간)
  static double estimateCalories({
    required double weightKg,
    required int durationSeconds,
    double met = 8.0,
  }) =>
      met * weightKg * (durationSeconds / 3600);
}

// ──────────────────────────────────────────────────
// 페이스 구간 열거형
// ──────────────────────────────────────────────────
enum PaceZone {
  tooFast, // 너무 빠름 (부상 위험)
  good,    // 권장 범위
  tooSlow, // 너무 느림
  stopped, // 정지 상태
}
