// lib/core/pace_calculator.dart
import '../models/running_session.dart';
import '../services/vo2max_model.dart';

class PaceCalculator {
  PaceCalculator._();

  // ACSM 러닝 방정식 상수 (실외 러닝 등가 grade = 1%)
  static const double _grade = 0.01;
  static const double _k     = 0.209; // 0.2 + 0.9 * 0.01

  // ──────────────────────────────────────────────
  // 1. VO2max 추정 (ml/kg/min) — ML 모델 전용
  // ──────────────────────────────────────────────
  static double? estimateVO2max({
    required int    age,
    required String gender,
    required double weightKg,
    required double heightCm,
    double? bodyFatPercent,
  }) {
    if (!VO2maxModel.instance.isReady) return null;
    return VO2maxModel.instance.predict(
      age:            age.toDouble(),
      genderEncoded:  gender == 'female' ? 1.0 : 0.0,
      heightCm:       heightCm,
      weightKg:       weightKg,
      bodyFatPercent: bodyFatPercent,
    );
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
  // 6. 적응형 보정 — 실제 러닝 결과로 권장값 조정
  // ──────────────────────────────────────────────
  /// 최근 세션(sessions.first)을 기준으로 감소/유지/증가를 결정해
  /// 페이스 보정값과 거리 보정값을 반환한다.
  ///
  /// 반환: (paceAdjustSec, tempoDistKm, longDistKm)
  static ({int paceAdjustSec, double tempoDistKm, double longDistKm})
      adaptFromSessions({
    required List<RunningSession> sessions,
    required int  currentFastLimitSec,
    required int  currentSlowLimitSec,
    required int  currentPaceAdjustSec,
    required double currentTempoDistKm,
    required double currentLongDistKm,
    required double baseTempoDistKm,
    required double baseLongDistKm,
  }) {
    final latest = sessions.first;

    // runType 결정: 세션에 명시된 값 우선, 없으면 거리 기준 추론
    final bool isTempo = latest.runType == 'tempo' ||
        (latest.runType == null &&
            (currentTempoDistKm - latest.totalDistanceKm).abs() <
                (currentLongDistKm - latest.totalDistanceKm).abs());

    final targetDistKm  = isTempo ? currentTempoDistKm : currentLongDistKm;
    final targetPaceSec = isTempo ? currentFastLimitSec : currentSlowLimitSec;

    final decision = _decideAdaptation(
      actualDistKm:  latest.totalDistanceKm,
      actualPaceSec: latest.averagePaceSec,
      actualHr:      latest.averageHeartRate,
      targetDistKm:  targetDistKm,
      targetPaceSec: targetPaceSec,
    );

    // ── 페이스 보정 (+10: 느리게, -10: 빠르게) ──────
    const paceDeltaSec = 10;
    final maxAdjust = ((currentFastLimitSec + currentSlowLimitSec) / 2 * 0.2).round();
    final newPaceAdjust = switch (decision) {
      _AdaptDecision.decrease => (currentPaceAdjustSec + paceDeltaSec).clamp(-maxAdjust, maxAdjust),
      _AdaptDecision.maintain => currentPaceAdjustSec,
      _AdaptDecision.increase => (currentPaceAdjustSec - paceDeltaSec).clamp(-maxAdjust, maxAdjust),
    };

    // ── 거리 보정 (+7%: 증가, -5%: 감소) ────────────
    double newTempoDistKm = currentTempoDistKm;
    double newLongDistKm  = currentLongDistKm;

    if (isTempo) {
      newTempoDistKm = switch (decision) {
        _AdaptDecision.decrease => (currentTempoDistKm * 0.95).clamp(baseTempoDistKm * 0.5, baseTempoDistKm * 2.0),
        _AdaptDecision.maintain => currentTempoDistKm,
        _AdaptDecision.increase => (currentTempoDistKm * 1.07).clamp(baseTempoDistKm * 0.5, baseTempoDistKm * 2.0),
      };
    } else {
      newLongDistKm = switch (decision) {
        _AdaptDecision.decrease => (currentLongDistKm * 0.95).clamp(baseLongDistKm * 0.5, baseLongDistKm * 2.0),
        _AdaptDecision.maintain => currentLongDistKm,
        _AdaptDecision.increase => (currentLongDistKm * 1.07).clamp(baseLongDistKm * 0.5, baseLongDistKm * 2.0),
      };
    }

    return (
      paceAdjustSec: newPaceAdjust,
      tempoDistKm:   newTempoDistKm,
      longDistKm:    newLongDistKm,
    );
  }

  static _AdaptDecision _decideAdaptation({
    required double actualDistKm,
    required int    actualPaceSec,
    required int?   actualHr,
    required double targetDistKm,
    required int    targetPaceSec,
  }) {
    final bool distOk      = actualDistKm >= targetDistKm * 0.9;
    final bool distExceeds = actualDistKm > targetDistKm * 1.1;
    final bool paceOk      = actualPaceSec <= targetPaceSec + 30; // 30초 이내 여유
    final bool paceFast    = actualPaceSec < targetPaceSec - 15;  // 15초 이상 빠름
    final bool hrLow       = actualHr != null && actualHr < 120;

    // 증가
    if (distExceeds) return _AdaptDecision.increase;
    if (distOk && paceFast) return _AdaptDecision.increase;
    if (distOk && paceOk && hrLow) return _AdaptDecision.increase;

    // 유지: 거리 충족 + 페이스 정상
    if (distOk && paceOk) return _AdaptDecision.maintain;
    // 유지: 거리 부족이지만 페이스가 빠름 (능력은 충분, 거리만 못 채운 것)
    if (!distOk && paceFast) return _AdaptDecision.maintain;
    // 유지: 거리/페이스 낮음 + HR < 120 (힘들지 않았으므로 기준 유지)
    if (!distOk && hrLow) return _AdaptDecision.maintain;

    // 감소: 나머지 (거리 부족 + 페이스 정상/느림, 거리 충족 + 페이스 느림)
    return _AdaptDecision.decrease;
  }

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

// 적응형 알고리즘 내부 결정값 (파일 내부 전용)
enum _AdaptDecision { decrease, maintain, increase }
