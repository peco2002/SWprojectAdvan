// lib/screens/pace_result_screen.dart
//
// ══════════════════════════════════════════════════
//  [메인 기능] 신체 데이터 → 맞춤 페이스 결과 화면
//  계획서 ① 맞춤형 페이스 산출 알고리즘
//    - 입력된 체성분 데이터 기반 최적 권장 페이스 제시
//    - VO2max → 유산소 효율 구간 → 페이스 범위 시각화
// ══════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/body_profile.dart';
import '../services/running_provider.dart';
import 'home_screen.dart';

class PaceResultScreen extends StatelessWidget {
  const PaceResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RunningProvider>();
    final profile  = provider.profile;
    if (profile == null) return const SizedBox.shrink();

    final fastSec   = profile.fastLimitSec;
    final slowSec   = profile.slowLimitSec;
    final vo2max    = profile.vo2max;
    final distances = profile.recommendedDistances;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더 ─────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${profile.name}님의 맞춤 페이스',
                      style: AppTextStyles.subheading),
                  const Text('신체 데이터 분석 완료',
                      style: AppTextStyles.caption),
                ]),
              ]),

              const SizedBox(height: 32),

              // ── 권장 페이스 메인 카드 ─────────────────────────
              _PaceRangeCard(
                fastSec: fastSec,
                slowSec: slowSec,
                tempoKm: distances['tempo']!,
                longKm:  distances['long']!,
              ),

              const SizedBox(height: 20),

              // ── VO2max / 분석 근거 ────────────────────────────
              _AnalysisCard(profile: profile, vo2max: vo2max),

              const SizedBox(height: 20),

              // ── 인바디 보정 뱃지 ──────────────────────────────
              if (profile.hasInbodyData) _InbodyBadge(profile: profile),

              const Spacer(),

              // ── 코칭 안내 ─────────────────────────────────────
              const _CoachingNote(),

              const SizedBox(height: 20),

              // ── 러닝 시작 버튼 ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('홈으로 이동',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 권장 페이스 범위 카드 ──────────────────────────────────────────

class _PaceRangeCard extends StatelessWidget {
  final int fastSec, slowSec;
  final double tempoKm, longKm;
  const _PaceRangeCard({
    required this.fastSec,
    required this.slowSec,
    required this.tempoKm,
    required this.longKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.20),
            AppColors.primaryDark.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 페이스 범위 ──────────────────────────────
          const Text('권장 페이스 범위',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(PaceCalculator.formatPace(fastSec),
                    style: AppTextStyles.paceHero),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
                  child: Text('~', style: TextStyle(
                      color: AppColors.primary.withOpacity(0.6),
                      fontSize: 28, fontWeight: FontWeight.w300)),
                ),
                Text(PaceCalculator.formatPace(slowSec),
                    style: AppTextStyles.paceHero),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('/km', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          const SizedBox(height: 16),
          _PaceBar(fastSec: fastSec, slowSec: slowSec),

          // ── 권장 운동 거리 ────────────────────────────
          const SizedBox(height: 16),
          Divider(color: AppColors.primary.withOpacity(0.2), height: 1),
          const SizedBox(height: 14),
          const Text('권장 운동 거리',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DistanceTile(
              label:    '템포 런',
              distKm:   tempoKm,
              paceSec:  fastSec,
            )),
            const SizedBox(width: 10),
            Expanded(child: _DistanceTile(
              label:    '롱 런',
              distKm:   longKm,
              paceSec:  slowSec,
            )),
          ]),
        ],
      ),
    );
  }
}

class _DistanceTile extends StatelessWidget {
  final String label;
  final double distKm;
  final int    paceSec;
  const _DistanceTile({required this.label, required this.distKm, required this.paceSec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${distKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${PaceCalculator.formatPace(paceSec)} /km',
              style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PaceBar extends StatelessWidget {
  final int fastSec, slowSec;
  const _PaceBar({required this.fastSec, required this.slowSec});

  @override
  Widget build(BuildContext context) {
    // 전체 범위: 4'00" (240) ~ 12'00" (720)
    const totalMin = 240, totalMax = 720;
    final totalRange = (totalMax - totalMin).toDouble();

    final leftPct  = (fastSec - totalMin) / totalRange;
    final widthPct = (slowSec - fastSec)  / totalRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 10, color: AppColors.divider),
              FractionallySizedBox(
                widthFactor: 1,
                child: Row(
                  children: [
                    Flexible(flex: (leftPct * 100).round(), child: const SizedBox()),
                    Flexible(
                      flex: (widthPct * 100).clamp(5, 100).round(),
                      child: Container(height: 10, color: AppColors.primary),
                    ),
                    Flexible(
                      flex: ((1 - leftPct - widthPct) * 100).clamp(0, 100).round(),
                      child: const SizedBox(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("4'00\"", style: TextStyle(color: AppColors.textHint, fontSize: 10)),
          Text('느림 ← 빠름', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
          Text("12'00\"", style: TextStyle(color: AppColors.textHint, fontSize: 10)),
        ]),
      ],
    );
  }
}

// ── 분석 근거 카드 ────────────────────────────────────────────────

class _AnalysisCard extends StatelessWidget {
  final BodyProfile profile;
  final double vo2max;
  const _AnalysisCard({required this.profile, required this.vo2max});

  @override
  Widget build(BuildContext context) {
    final fitnessLabel = {
      'none':       '운동 경험 없음',
      'occasional': '간헐적 운동',
      'regular':    '주 1~2회 운동',
    }[profile.fitnessLevel] ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.analytics_outlined, color: AppColors.accent, size: 16),
            SizedBox(width: 6),
            Text('분석 근거', style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          _row('최대산소섭취량 (VO₂max)',
              '${vo2max.toStringAsFixed(1)} ml/kg/min'),
          const SizedBox(height: 8),
          _row('권장 강도 구간', 'VO₂max의 75~85% (ACSM)'),
          const SizedBox(height: 8),
          _row('기준 정보',
              '${profile.age}세 / ${profile.gender == 'male' ? '남성' : '여성'} / $fitnessLabel'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      );
}

// ── 인바디 보정 뱃지 ──────────────────────────────────────────────

class _InbodyBadge extends StatelessWidget {
  final BodyProfile profile;
  const _InbodyBadge({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.12),
        border: Border.all(color: Colors.teal.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.monitor_heart, color: Colors.teal, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '인바디 보정 적용됨 — 체지방 ${profile.bodyFatPercent!.toStringAsFixed(1)}% / '
          '골격근량 ${profile.muscleMassKg!.toStringAsFixed(1)}kg',
          style: const TextStyle(color: Colors.teal, fontSize: 12),
        )),
      ]),
    );
  }
}

// ── 코칭 안내 ────────────────────────────────────────────────────

class _CoachingNote extends StatelessWidget {
  const _CoachingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(Icons.volume_up_outlined, color: AppColors.textHint, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text(
          '러닝 중 권장 페이스를 벗어나면 음성으로 즉시 알려드려요.',
          style: TextStyle(color: AppColors.textHint, fontSize: 13, height: 1.4),
        )),
      ]),
    );
  }
}
