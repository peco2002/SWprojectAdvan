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
  });

  // ── 계산 결과 (게터) ─────────────────────────────────────────

  /// VO2max 추정값 (ml/kg/min)
  double get vo2max => PaceCalculator.estimateVO2max(
        age:             age,
        gender:          gender,
        fitnessLevel:    fitnessLevel,
        bodyFatPercent:  bodyFatPercent,
        muscleMassKg:    muscleMassKg,
        weightKg:        weightKg,
      );

  /// 권장 페이스 범위 [빠른 한계(sec/km), 느린 한계(sec/km)]
  List<int> get paceRange =>
      PaceCalculator.recommendedPaceRange(vo2max: vo2max);

  int get fastLimitSec => paceRange[0];
  int get slowLimitSec => paceRange[1];

  /// 권장 운동 거리 {'tempo': X.X, 'long': X.X} (km)
  Map<String, double> get recommendedDistances =>
      PaceCalculator.recommendedDistances(
        vo2max:        vo2max,
        fitnessLevel:  fitnessLevel,
        weightKg:      weightKg,
        heightCm:      heightCm,
        gender:        gender,
        bodyFatPercent: bodyFatPercent,
      );

  /// 인바디 데이터 입력 여부
  bool get hasInbodyData =>
      bodyFatPercent != null && muscleMassKg != null;

  // ── 직렬화 ──────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'uid':            uid,
        'name':           name,
        'heightCm':       heightCm,
        'weightKg':       weightKg,
        'age':            age,
        'gender':         gender,
        'fitnessLevel':   fitnessLevel,
        'bodyFatPercent': bodyFatPercent,
        'muscleMassKg':   muscleMassKg,
      };

  factory BodyProfile.fromMap(Map<String, dynamic> m) => BodyProfile(
        uid:            m['uid']            as String? ?? '',
        name:           m['name']           as String? ?? '',
        heightCm:       (m['heightCm']      as num?)?.toDouble() ?? 170,
        weightKg:       (m['weightKg']      as num?)?.toDouble() ?? 65,
        age:            m['age']            as int?    ?? 25,
        gender:         m['gender']         as String? ?? 'male',
        fitnessLevel:   m['fitnessLevel']   as String? ?? 'none',
        bodyFatPercent: (m['bodyFatPercent'] as num?)?.toDouble(),
        muscleMassKg:   (m['muscleMassKg']  as num?)?.toDouble(),
      );

  BodyProfile copyWith({
    double? bodyFatPercent,
    double? muscleMassKg,
    String? fitnessLevel,
  }) =>
      BodyProfile(
        uid:            uid,
        name:           name,
        heightCm:       heightCm,
        weightKg:       weightKg,
        age:            age,
        gender:         gender,
        fitnessLevel:   fitnessLevel ?? this.fitnessLevel,
        bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
        muscleMassKg:   muscleMassKg  ?? this.muscleMassKg,
      );
}
