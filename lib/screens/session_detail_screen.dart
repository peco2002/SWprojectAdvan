// lib/screens/session_detail_screen.dart
// 러닝 세션 세부 화면 — 지도 플레이스홀더 + 구간별 페이스

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';

class SessionDetailScreen extends StatelessWidget {
  final RunningSession session;
  const SessionDetailScreen({super.key, required this.session});

  // PaceRecord 목록에서 km별 평균 페이스 계산
  Map<int, int> _buildKmPaces(List<PaceRecord> history) {
    final groups = <int, List<int>>{};
    for (final r in history) {
      if (r.paceSec <= 0) continue;
      final km = r.distanceKm.floor() + 1;
      groups.putIfAbsent(km, () => []).add(r.paceSec);
    }
    final result = <int, int>{};
    for (final entry in groups.entries) {
      result[entry.key] =
          entry.value.reduce((a, b) => a + b) ~/ entry.value.length;
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmPaces = _buildKmPaces(session.paceHistory);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          session.formattedDate,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 지도 플레이스홀더 (상단 고정) ──────────────────
            Container(
              width: double.infinity,
              height: 220,
              color: AppColors.surface,
              child: const Center(
                child: Text(
                  '지도 위치',
                  style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 통계 그리드 ──────────────────────────────
                  Row(children: [
                    _StatCard('거리',
                        session.totalDistanceKm.toStringAsFixed(2),
                        'km', AppColors.primary),
                    const SizedBox(width: 12),
                    _StatCard('시간', session.formattedDuration,
                        '', Colors.blueAccent),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _StatCard('평균 페이스', session.formattedPace,
                        '/km', Colors.orangeAccent),
                    const SizedBox(width: 12),
                    _StatCard('칼로리',
                        session.caloriesBurned.toStringAsFixed(0),
                        'kcal', Colors.pinkAccent),
                  ]),

                  // ── 구간별 페이스 ─────────────────────────────
                  if (kmPaces.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('구간별 페이스',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 4),
                    ...kmPaces.entries
                        .map((e) => _KmPaceRow(km: e.key, paceSec: e.value)),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 통계 카드 ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatCard(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            border: Border.all(color: color.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (unit.isNotEmpty)
              Text(unit,
                  style: TextStyle(
                      color: color.withOpacity(0.6), fontSize: 11)),
          ]),
        ),
      );
}

// ── km별 페이스 행 ────────────────────────────────────────

class _KmPaceRow extends StatelessWidget {
  final int km, paceSec;
  const _KmPaceRow({required this.km, required this.paceSec});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$km',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('km',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          const Spacer(),
          Text(
            PaceCalculator.formatPace(paceSec),
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Text('/km',
              style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ]),
      );
}
