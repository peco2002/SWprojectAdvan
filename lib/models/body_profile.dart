// lib/models/body_profile.dart
// 신체 데이터 모델 (계획서 ① 신체 데이터 동적 연동)

import '../core/pace_calculator.dart';

class BodyProfile {
  final String uid;
  final String name;

  // ── 기본 입력 (1단계 MVP)
  final double heightCm;
  final double weightKg;
  final int    age;
  final String gender;       // 'male' | 'female'
  final String fitnessLevel; // 'none' | 'occasional' | 'regular'

  // ── 인바디 데이터 (2단계 고도화, 선택)
  final double? bodyFatPercent;  // 체지방률 (%)
  final double? muscleMassKg;    // 골격근량 (kg)

  // ── 적응형 보정값 ─────────────────────────────────────────────
  final int    paceAdjustSec;      // 누적 페이스 보정 (초), 기본 0
  final double? adaptedTempoDistKm; // 보정된 템포런 권장 거리 (null = 계산값 사용)
  final double? adaptedLongDistKm;  // 보정된 롱런 권장 거리
  final int    sessionCount;       // 유효 러닝 누적 횟수 (3회 이상부터 보정 시작)
  final bool?  hasWearable;        // 웨어러블 보유 여부 (null = 미결정, 기존 계정 마이그레이션 대상)

  const BodyProfile({
    required this.uid,
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.gender,
    required this.fitnessLevel,
    this.bodyFatPercent,
    this.muscleMassKg,
    this.paceAdjustSec      = 0,
    this.adaptedTempoDistKm,
    this.adaptedLongDistKm,
    this.sessionCount       = 0,
    this.hasWearable,
  });

  // ── 계산 결과 (게터) ─────────────────────────────────────────

  /// VO2max 추정값 (ml/kg/min) — ML 모델 미로드 시 null
  double? get vo2max => PaceCalculator.estimateVO2max(
        age:            age,
        gender:         gender,
        weightKg:       weightKg,
        heightCm:       heightCm,
        bodyFatPercent: bodyFatPercent,
      );

  /// 권장 페이스 범위 [빠른 한계(sec/km), 느린 한계(sec/km)] — ML 원본값
  List<int>? get paceRange {
    final v = vo2max;
    if (v == null) return null;
    return PaceCalculator.recommendedPaceRange(vo2max: v);
  }

  /// 보정값이 적용된 페이스 한계
  int? get fastLimitSec {
    final r = paceRange;
    if (r == null) return null;
    return (r[0] + paceAdjustSec).clamp(180, 1200);
  }

  int? get slowLimitSec {
    final r = paceRange;
    if (r == null) return null;
    return (r[1] + paceAdjustSec).clamp(180, 1200);
  }

  /// 권장 운동 거리 {'tempo': X.X, 'long': X.X} (km) — 보정값 우선
  Map<String, double>? get recommendedDistances {
    final v = vo2max;
    if (v == null) return null;
    final base = PaceCalculator.recommendedDistances(
      vo2max:         v,
      fitnessLevel:   fitnessLevel,
      weightKg:       weightKg,
      heightCm:       heightCm,
      gender:         gender,
      bodyFatPercent: bodyFatPercent,
    );
    return {
      'tempo': adaptedTempoDistKm ?? base['tempo']!,
      'long':  adaptedLongDistKm  ?? base['long']!,
    };
  }

  /// 인바디 데이터 입력 여부
  bool get hasInbodyData =>
      bodyFatPercent != null && muscleMassKg != null;

  // ── 직렬화 ──────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'uid':               uid,
        'name':              name,
        'heightCm':          heightCm,
        'weightKg':          weightKg,
        'age':               age,
        'gender':            gender,
        'fitnessLevel':      fitnessLevel,
        'bodyFatPercent':    bodyFatPercent,
        'muscleMassKg':      muscleMassKg,
        'paceAdjustSec':     paceAdjustSec,
        if (adaptedTempoDistKm != null) 'adaptedTempoDistKm': adaptedTempoDistKm,
        if (adaptedLongDistKm  != null) 'adaptedLongDistKm':  adaptedLongDistKm,
        'sessionCount':      sessionCount,
        if (hasWearable != null) 'hasWearable': hasWearable,
      };

  factory BodyProfile.fromMap(Map<String, dynamic> m) => BodyProfile(
        uid:                m['uid']             as String? ?? '',
        name:               m['name']            as String? ?? '',
        heightCm:           (m['heightCm']       as num?)?.toDouble() ?? 170,
        weightKg:           (m['weightKg']       as num?)?.toDouble() ?? 65,
        age:                m['age']             as int?    ?? 25,
        gender:             m['gender']          as String? ?? 'male',
        fitnessLevel:       m['fitnessLevel']    as String? ?? 'none',
        bodyFatPercent:     (m['bodyFatPercent'] as num?)?.toDouble(),
        muscleMassKg:       (m['muscleMassKg']   as num?)?.toDouble(),
        paceAdjustSec:      (m['paceAdjustSec']  as num?)?.toInt() ?? 0,
        adaptedTempoDistKm: (m['adaptedTempoDistKm'] as num?)?.toDouble(),
        adaptedLongDistKm:  (m['adaptedLongDistKm']  as num?)?.toDouble(),
        sessionCount:       (m['sessionCount']   as num?)?.toInt() ?? 0,
        hasWearable:        m['hasWearable'] as bool?,
      );

  BodyProfile copyWith({
    double? bodyFatPercent,
    double? muscleMassKg,
    String? fitnessLevel,
    int?    paceAdjustSec,
    double? adaptedTempoDistKm,
    double? adaptedLongDistKm,
    int?    sessionCount,
    bool?   hasWearable,
  }) =>
      BodyProfile(
        uid:               uid,
        name:              name,
        heightCm:          heightCm,
        weightKg:          weightKg,
        age:               age,
        gender:            gender,
        fitnessLevel:      fitnessLevel      ?? this.fitnessLevel,
        bodyFatPercent:    bodyFatPercent    ?? this.bodyFatPercent,
        muscleMassKg:      muscleMassKg      ?? this.muscleMassKg,
        paceAdjustSec:     paceAdjustSec     ?? this.paceAdjustSec,
        adaptedTempoDistKm: adaptedTempoDistKm ?? this.adaptedTempoDistKm,
        adaptedLongDistKm:  adaptedLongDistKm  ?? this.adaptedLongDistKm,
        sessionCount:      sessionCount      ?? this.sessionCount,
        hasWearable:       hasWearable       ?? this.hasWearable,
      );
}
