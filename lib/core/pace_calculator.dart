// lib/core/pace_calculator.dart
import '../services/vo2max_model.dart';

class PaceCalculator {
  PaceCalculator._();

  // ACSM 러닝 방정식 상수 (실외 러닝 등가 grade = 1%)
  static const double _grade = 0.01;
  static const double _k     = 0.209; // 0.2 + 0.9 * 0.01

  // ──────────────────────────────────────────────
  // 1. VO2max 추정 (ml/kg/min)
  //    ML 모델 로드 시 ML 우선, 미로드 시 수식 폴백
  // ──────────────────────────────────────────────
  static double estimateVO2max({
    required int    age,
    required String gender,
    required String fitnessLevel,
    double? bodyFatPercent,
    double? muscleMassKg,
    double? weightKg,
    double? heightCm,
  }) {
    // ML 모델 추론 시도
    if (VO2maxModel.instance.isReady && weightKg != null && heightCm != null) {
      final ml = VO2maxModel.instance.predict(
        age:            age.toDouble(),
        genderEncoded:  gender == 'female' ? 1.0 : 0.0,
        heightCm:       heightCm,
        weightKg:       weightKg,
        bodyFatPercent: bodyFatPercent,
      );
      if (ml != null) return ml;
    }

    // 수식 폴백
    final par = switch (fitnessLevel) {
      'occasional' => 5.0,
      'regular'    => 8.0,
      _            => 2.0,
    };
    final sexFemale = gender == 'female' ? 1.0 : 0.0;

    double vo2;
    if (bodyFatPercent != null && age >= 19 && age <= 35) {
      vo2 = 48.47 - 0.41 * bodyFatPercent + 0.45 * par - 5.12 * sexFemale;
    } else {
      vo2 = gender == 'male'
          ? 56.363 - 0.381 * age
          : 44.022 - 0.353 * age;
      if (bodyFatPercent != null) {
        final avgFat = gender == 'male' ? 20.0 : 28.0;
        vo2 -= ((bodyFatPercent - avgFat) * 0.18).clamp(-6.0, 8.0);
      }
      if (muscleMassKg != null && weightKg != null && weightKg > 0) {
        final musclePct = muscleMassKg / weightKg * 100;
        final avgMuscle = gender == 'male' ? 47.0 : 40.0;
        vo2 += ((musclePct - avgMuscle) * 0.12).clamp(-4.0, 6.0);
      }
      switch (fitnessLevel) {
        case 'occasional': vo2 += 3; break;
        case 'regular':    vo2 += 7; break;
      }
    }
    return vo2.clamp(15.0, 70.0);
  }

  // ──────────────────────────────────────────────
  // 2. 권장 페이스 범위 산출 (sec/km)
  // ──────────────────────────────────────────────
  /// 반환: [fastLimit, slowLimit]  (fastLimit < slowLimit)
  /// · fastLimit = 템포 강도 (0.85 × VO₂max)
  /// · slowLimit = 롱런 강도 (0.75 × VO₂max)
  static List<int> recommendedPaceRange({required double vo2max}) {
    return [
      _vo2ToPaceSec(vo2max * 0.85), // 템포 페이스 (빠른 한계)
      _vo2ToPaceSec(vo2max * 0.75), // 롱런 페이스 (느린 한계)
    ];
  }

  // ──────────────────────────────────────────────
  // 3. 권장 운동 거리 산출 (km)
  // ──────────────────────────────────────────────
  /// 세션 유형별 권장 거리 반환 {'tempo': X.X, 'long': X.X}
  /// 고위험(BMI≥30, 고PBF, 운동경험없음) 사용자는 보수적으로 처방
  static Map<String, double> recommendedDistances({
    required double vo2max,
    required String fitnessLevel,
    required double weightKg,
    required double heightCm,
    required String gender,
    double? bodyFatPercent,
  }) {
    final tempoPaceSec = _vo2ToPaceSec(vo2max * 0.85);
    final longPaceSec  = _vo2ToPaceSec(vo2max * 0.75);

    // 위험 플래그
    final bmi     = weightKg / ((heightCm / 100) * (heightCm / 100));
    final highBmi = bmi >= 30;
    final highPbf = bodyFatPercent != null &&
        ((gender == 'male'   && bodyFatPercent > 25) ||
         (gender == 'female' && bodyFatPercent > 35));
    final isHighRisk = highBmi || highPbf || fitnessLevel == 'none';

    // 세션 권장 시간(분)
    final int tempoDurationMin;
    final int longDurationMin;
    if (isHighRisk) {
      tempoDurationMin = 12;
      longDurationMin  = 30;
    } else if (fitnessLevel == 'regular') {
      tempoDurationMin = 25;
      longDurationMin  = 75;
    } else {
      // occasional
      tempoDurationMin = 20;
      longDurationMin  = 50;
    }

    // 거리(km) = 시간(분) × 60 / 페이스(sec/km)
    return {
      'tempo': tempoDurationMin * 60.0 / tempoPaceSec,
      'long':  longDurationMin  * 60.0 / longPaceSec,
    };
  }

  // ──────────────────────────────────────────────
  // 4. 현재 페이스 상태 판정
  // ──────────────────────────────────────────────
  static PaceZone judgeZone({
    required int currentPaceSec,
    required int fastLimit,
    required int slowLimit,
  }) {
    if (currentPaceSec == 0)        return PaceZone.stopped;
    if (currentPaceSec < fastLimit) return PaceZone.tooFast;
    if (currentPaceSec > slowLimit) return PaceZone.tooSlow;
    return PaceZone.good;
  }

  // ──────────────────────────────────────────────
  // 5. 포맷 헬퍼
  // ──────────────────────────────────────────────
  static String formatPace(int paceSec) {
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).toString().padLeft(2, '0');
    return "$m'$s\"";
  }

  static String formatPaceKorean(int paceSec) {
    final m = paceSec ~/ 60;
    final s = paceSec % 60;
    return '$m분 ${s.toString().padLeft(2, '0')}초';
  }

  static double estimateCalories({
    required double weightKg,
    required double distanceKm,
  }) =>
      weightKg * distanceKm * 1.036;

  // ──────────────────────────────────────────────
  // 내부: ACSM 역산 (VO₂ → sec/km)
  // ──────────────────────────────────────────────
  static int _vo2ToPaceSec(double vo2) {
    if (vo2 <= 3.5) return 1200;
    final vMperMin = (vo2 - 3.5) / _k;
    if (vMperMin <= 0) return 1200;
    return ((1000.0 / vMperMin) * 60).round().clamp(180, 1200);
  }
}

// ──────────────────────────────────────────────────
// 페이스 구간 열거형
// ──────────────────────────────────────────────────
enum PaceZone {
  tooFast, // 너무 빠름 (템포 강도 초과)
  good,    // 권장 범위
  tooSlow, // 너무 느림 (롱런 강도 미달)
  stopped, // 정지 상태
}
