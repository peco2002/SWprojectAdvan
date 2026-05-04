// test/adaptive_test.dart
// 적응형 알고리즘 단위 테스트
// PaceCalculator.adaptFromSessions() 의 동일한 수식을 인라인으로 검증합니다.
// tflite_flutter 네이티브 바이너리 없이 Dart VM 에서 실행 가능합니다.

import 'package:flutter_test/flutter_test.dart';

// ── 테스트용 최소 RunningSession 모델 ─────────────────────────────
class _Session {
  final int    durationSeconds;
  final int    averagePaceSec;
  final double totalDistanceKm;
  const _Session({
    required this.durationSeconds,
    required this.averagePaceSec,
    required this.totalDistanceKm,
  });
}

// ── PaceCalculator.adaptFromSessions() 동일 수식 ─────────────────
({int paceAdjustSec, double tempoDistKm, double longDistKm}) _adaptFromSessions({
  required List<_Session> sessions,
  required int    currentFastLimitSec,
  required int    currentSlowLimitSec,
  required int    currentPaceAdjustSec,
  required double currentTempoDistKm,
  required double currentLongDistKm,
  required double baseTempoDistKm,
  required double baseLongDistKm,
}) {
  // 페이스 보정
  final midTarget = (currentFastLimitSec + currentSlowLimitSec) / 2;
  final recentAvg = sessions.map((s) => s.averagePaceSec).reduce((a, b) => a + b) /
      sessions.length;
  final delta      = recentAvg - midTarget;
  final maxAdjust  = (midTarget * 0.2).round();
  final newPaceAdj = (currentPaceAdjustSec + (delta * 0.3).round())
      .clamp(-maxAdjust, maxAdjust);

  // 거리 보정 (최신 세션 기준) — 권장 거리 중간값으로 템포/롱런 판별
  final latest    = sessions.first;
  final midDistKm = (currentTempoDistKm + currentLongDistKm) / 2;
  final isLongRun = latest.totalDistanceKm >= midDistKm;

  double newTempo = currentTempoDistKm;
  double newLong  = currentLongDistKm;

  if (isLongRun) {
    final ratio = latest.totalDistanceKm / currentLongDistKm;
    newLong = (currentLongDistKm * (1 + 0.25 * (ratio - 1)))
        .clamp(baseLongDistKm * 0.5, baseLongDistKm * 2.0);
  } else {
    final ratio = latest.totalDistanceKm / currentTempoDistKm;
    newTempo = (currentTempoDistKm * (1 + 0.25 * (ratio - 1)))
        .clamp(baseTempoDistKm * 0.5, baseTempoDistKm * 2.0);
  }

  return (paceAdjustSec: newPaceAdj, tempoDistKm: newTempo, longDistKm: newLong);
}

// ── helpers ──────────────────────────────────────────────────────
_Session _tempo({required int avgPaceSec, required double distKm}) => _Session(
      durationSeconds: 20 * 60, // 20분 → 템포런으로 판별
      averagePaceSec:  avgPaceSec,
      totalDistanceKm: distKm,
    );

_Session _long({required int avgPaceSec, required double distKm}) => _Session(
      durationSeconds: 40 * 60, // 40분 → 롱런으로 판별
      averagePaceSec:  avgPaceSec,
      totalDistanceKm: distKm,
    );

void main() {
  // 기준값 (5'00"/km 템포, 6'00"/km 롱런, 페이스 조정 없음)
  const fastLimit = 300;  // 5'00"/km
  const slowLimit = 360;  // 6'00"/km
  const midTarget = (fastLimit + slowLimit) / 2; // 330 sec

  group('페이스 보정', () {
    test('권장 범위 내에서 달렸으면 보정 없음', () {
      // 평균 페이스 = midTarget(330) → delta = 0 → paceAdjust = 0
      final sessions = [
        _tempo(avgPaceSec: 330, distKm: 3.0),
        _tempo(avgPaceSec: 330, distKm: 3.0),
        _tempo(avgPaceSec: 330, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.paceAdjustSec, 0);
    });

    test('너무 빠르게 달렸으면 paceAdjust 감소 (페이스 범위를 빠른 방향으로 당김)', () {
      // 평균 페이스 240 sec/km (목표보다 90초 빠름) → delta = -90
      // newAdj = 0 + (-90 * 0.3).round() = -27
      final sessions = [
        _tempo(avgPaceSec: 240, distKm: 3.0),
        _tempo(avgPaceSec: 240, distKm: 3.0),
        _tempo(avgPaceSec: 240, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.paceAdjustSec, -27);
    });

    test('너무 느리게 달렸으면 paceAdjust 증가 (페이스 범위를 느린 방향으로 당김)', () {
      // 평균 페이스 450 sec/km (목표보다 120초 느림) → delta = 120
      // newAdj = 0 + (120 * 0.3).round() = 36
      final sessions = [
        _tempo(avgPaceSec: 450, distKm: 3.0),
        _tempo(avgPaceSec: 450, distKm: 3.0),
        _tempo(avgPaceSec: 450, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.paceAdjustSec, 36);
    });

    test('±20% 상한 클램프 적용', () {
      // midTarget=330 → maxAdjust = (330*0.2).round() = 66
      // delta = 500 → (500*0.3).round() = 150 → clamp → 66
      final sessions = [
        _tempo(avgPaceSec: 830, distKm: 3.0),
        _tempo(avgPaceSec: 830, distKm: 3.0),
        _tempo(avgPaceSec: 830, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      final maxAdjust = (midTarget * 0.2).round(); // 66
      expect(r.paceAdjustSec, maxAdjust);
    });

    test('누적 paceAdjust 가 상한을 초과하지 않음', () {
      // 이미 +50 이 쌓인 상태에서 delta +150 → clamp 66
      final sessions = [
        _tempo(avgPaceSec: 800, distKm: 3.0),
        _tempo(avgPaceSec: 800, distKm: 3.0),
        _tempo(avgPaceSec: 800, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 50,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      final maxAdjust = (midTarget * 0.2).round();
      expect(r.paceAdjustSec, maxAdjust);
    });
  });

  group('거리 보정 — 템포런 (midDist = (3.0+7.0)/2 = 5.0 km 미만)', () {
    test('권장 거리와 동일하게 달렸으면 거리 변화 없음', () {
      final sessions = [
        _tempo(avgPaceSec: 330, distKm: 3.0), // ratio = 1.0
        _tempo(avgPaceSec: 330, distKm: 3.0),
        _tempo(avgPaceSec: 330, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.tempoDistKm, closeTo(3.0, 0.01));
    });

    test('권장보다 20% 더 달렸으면 템포 거리 5% 증가 (0.25 학습률)', () {
      // ratio = 3.6/3.0 = 1.2 → new = 3.0 * (1 + 0.25*(1.2-1)) = 3.0 * 1.05 = 3.15
      final sessions = [
        _tempo(avgPaceSec: 330, distKm: 3.6),
        _tempo(avgPaceSec: 330, distKm: 3.0),
        _tempo(avgPaceSec: 330, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.tempoDistKm, closeTo(3.15, 0.01));
      expect(r.longDistKm,  closeTo(7.0,  0.01)); // 롱런 거리 변화 없음
    });

    test('권장보다 짧게 달렸으면 템포 거리 감소', () {
      // ratio = 2.4/3.0 = 0.8 → new = 3.0 * (1 + 0.25*(0.8-1)) = 3.0 * 0.95 = 2.85
      final sessions = [
        _tempo(avgPaceSec: 330, distKm: 2.4),
        _tempo(avgPaceSec: 330, distKm: 3.0),
        _tempo(avgPaceSec: 330, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.tempoDistKm, closeTo(2.85, 0.01));
    });

    test('거리 상한: base * 2.0 초과 클램프', () {
      // currentTempo=1.0, currentLong=20.0 → midDist=10.5
      // distKm=9.0 < 10.5 → 템포런 분류
      // ratio=9.0/1.0=9 → 1.0*(1+0.25*8)=3.0 → clamp(0.5, 2.0) → 2.0
      final sessions = [
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 9.0),
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 1.0),
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 1.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   1.0,
        currentLongDistKm:    20.0,
        baseTempoDistKm:      1.0,
        baseLongDistKm:       20.0,
      );
      expect(r.tempoDistKm, closeTo(1.0 * 2.0, 0.01)); // 상한 2.0 km
    });

    test('거리 하한: base * 0.5 미만 클램프', () {
      // currentTempo=1.0 (이미 감소됨), baseTempo=3.0, currentLong=20.0 → midDist=10.5
      // distKm=0.01 < 10.5 → 템포런 분류
      // ratio=0.01/1.0≈0 → 1.0*(1+0.25*(-1))=0.75 → clamp(3.0*0.5=1.5, 3.0*2.0=6.0) → 1.5
      final sessions = [
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 0.01),
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 1.0),
        _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 1.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   1.0,
        currentLongDistKm:    20.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       20.0,
      );
      expect(r.tempoDistKm, closeTo(3.0 * 0.5, 0.01)); // 하한 1.5 km
    });
  });

  group('거리 보정 — 롱런 (midDist = (3.0+7.0)/2 = 5.0 km 이상)', () {
    test('권장 거리와 동일하게 달렸으면 롱런 거리 변화 없음', () {
      final sessions = [
        _long(avgPaceSec: 360, distKm: 7.0), // ratio = 1.0
        _long(avgPaceSec: 360, distKm: 7.0),
        _long(avgPaceSec: 360, distKm: 7.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.longDistKm,  closeTo(7.0, 0.01));
      expect(r.tempoDistKm, closeTo(3.0, 0.01)); // 템포 거리 변화 없음
    });

    test('권장보다 20% 더 달렸으면 롱런 거리 5% 증가', () {
      // ratio = 8.4/7.0 = 1.2 → new = 7.0 * (1 + 0.25*0.2) = 7.0 * 1.05 = 7.35
      final sessions = [
        _long(avgPaceSec: 360, distKm: 8.4),
        _long(avgPaceSec: 360, distKm: 7.0),
        _long(avgPaceSec: 360, distKm: 7.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.longDistKm, closeTo(7.35, 0.01));
    });
  });

  group('페이스+거리 동시 보정', () {
    test('빠르게 달리고 거리도 더 달렸으면 둘 다 보정됨', () {
      // 세션 3개 모두 평균 페이스 270 (midTarget 330보다 60 빠름)
      // paceAdjust: delta=-60 → (0 + (-60*0.3).round()) = -18
      // 최신 템포런 distKm=3.6 → ratio=1.2 → new=3.15
      final sessions = [
        _tempo(avgPaceSec: 270, distKm: 3.6), // latest
        _tempo(avgPaceSec: 270, distKm: 3.0),
        _tempo(avgPaceSec: 270, distKm: 3.0),
      ];
      final r = _adaptFromSessions(
        sessions: sessions,
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.paceAdjustSec, -18);
      expect(r.tempoDistKm,   closeTo(3.15, 0.01));
      expect(r.longDistKm,    closeTo(7.0,  0.01));
    });
  });

  group('거리 기준 템포/롱런 판별 (midDist = (tempo+long)/2)', () {
    test('midDist 미만이면 템포런으로 판별됨', () {
      // midDist = (3.0+7.0)/2 = 5.0 → 4.9km < 5.0 → 템포런
      final s = _Session(durationSeconds: 1200, averagePaceSec: 330, totalDistanceKm: 4.9);
      final r = _adaptFromSessions(
        sessions: [s, _tempo(avgPaceSec: 330, distKm: 3.0), _tempo(avgPaceSec: 330, distKm: 3.0)],
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.tempoDistKm, greaterThan(3.0)); // 템포 거리 변경됨
      expect(r.longDistKm,  closeTo(7.0, 0.01)); // 롱런 거리 미변경
    });

    test('midDist 이상이면 롱런으로 판별됨', () {
      // midDist = 5.0 → 7.5km ≥ 5.0 → 롱런, 그리고 7.5 > 7.0(현재 권장)이므로 증가
      final s = _Session(durationSeconds: 1200, averagePaceSec: 360, totalDistanceKm: 7.5);
      final r = _adaptFromSessions(
        sessions: [s, _long(avgPaceSec: 360, distKm: 7.0), _long(avgPaceSec: 360, distKm: 7.0)],
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   3.0,
        currentLongDistKm:    7.0,
        baseTempoDistKm:      3.0,
        baseLongDistKm:       7.0,
      );
      expect(r.longDistKm,  greaterThan(7.0)); // 롱런 거리 변경됨
      expect(r.tempoDistKm, closeTo(3.0, 0.01)); // 템포 거리 미변경
    });

    test('버그 재현: 초보자 권장 롱런 3.9km(~28분)이 롱런으로 올바르게 분류됨', () {
      // 이전 35분 고정 기준: 28분 < 35분 → 템포런으로 오분류
      // 새 기준: midDist=(1.8+3.9)/2=2.85, 3.9km ≥ 2.85 → 롱런으로 올바르게 분류
      final s = _Session(durationSeconds: 28 * 60, averagePaceSec: 437, totalDistanceKm: 3.9);
      final r = _adaptFromSessions(
        sessions: [s, _long(avgPaceSec: 437, distKm: 3.9), _long(avgPaceSec: 437, distKm: 3.9)],
        currentFastLimitSec:  fastLimit,
        currentSlowLimitSec:  slowLimit,
        currentPaceAdjustSec: 0,
        currentTempoDistKm:   1.8,
        currentLongDistKm:    3.9,
        baseTempoDistKm:      1.8,
        baseLongDistKm:       3.9,
      );
      // ratio = 3.9/3.9 = 1.0 → longDistKm 변화 없음
      expect(r.longDistKm,  closeTo(3.9, 0.01));
      expect(r.tempoDistKm, closeTo(1.8, 0.01)); // 템포 미변경
    });
  });
}
