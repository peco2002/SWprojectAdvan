// lib/screens/result_screen.dart

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/running_session.dart';

class ResultScreen extends StatelessWidget {
  final RunningSession session;
  const ResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('러닝 완료! 🎉', style: AppTextStyles.heading),
              const SizedBox(height: 4),
              Text(session.formattedDate, style: AppTextStyles.caption),

              const SizedBox(height: 28),

              // ── 핵심 지표 2×2 그리드 ─────────────────────────
              Row(children: [
                _Card('거리', session.totalDistanceKm.toStringAsFixed(2),
                    'km', AppColors.primary),
                const SizedBox(width: 14),
                _Card('시간', session.formattedDuration, '',
                    Colors.blueAccent),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _Card('평균 페이스', session.formattedPace, '/km',
                    Colors.orangeAccent),
                const SizedBox(width: 14),
                _Card('칼로리',
                    session.caloriesBurned.toStringAsFixed(0), 'kcal',
                    Colors.pinkAccent),
              ]),
              const SizedBox(height: 14),

              // ── 평균 심박수 ───────────────────────────────────
              _Card(
                '평균 심박수',
                session.averageHeartRate != null
                    ? '${session.averageHeartRate}'
                    : '--',
                'BPM',
                Colors.redAccent,
                fullWidth: true,
              ),

              const SizedBox(height: 28),

              // ── 페이스 변화 그래프 ────────────────────────────
              if (session.paceHistory.length >= 2) ...[
                const Text('페이스 변화',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _PaceChart(records: session.paceHistory),
              ],

              const Spacer(),

              // ── 홈으로 ────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('홈으로',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final bool fullWidth;
  const _Card(this.label, this.value, this.unit, this.color,
      {this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    final child = Container(
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
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        if (unit.isNotEmpty)
          Text(unit,
              style: TextStyle(
                  color: color.withOpacity(0.6), fontSize: 11)),
      ]),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, child: child)
        : Expanded(child: child);
  }
}

class _PaceChart extends StatelessWidget {
  final List<PaceRecord> records;
  const _PaceChart({required this.records});

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: CustomPaint(
          painter: _ChartPainter(records),
          child: const SizedBox.expand(),
        ),
      );
}

class _ChartPainter extends CustomPainter {
  final List<PaceRecord> records;
  const _ChartPainter(this.records);

  @override
  void paint(Canvas canvas, Size size) {
    if (records.length < 2) return;
    final paces = records.map((r) => r.paceSec.toDouble()).toList();
    final maxP  = paces.reduce((a, b) => a > b ? a : b);
    final minP  = paces.reduce((a, b) => a < b ? a : b);
    final range = (maxP - minP).clamp(1.0, double.infinity);

    final linePaint = Paint()
      ..color       = AppColors.primary
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final fillShader = LinearGradient(
      begin: Alignment.topCenter,
      end:   Alignment.bottomCenter,
      colors: [
        AppColors.primary.withOpacity(0.3),
        AppColors.primary.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPaint = Paint()
      ..shader = fillShader
      ..style  = PaintingStyle.fill;

    final path = Path(), fill = Path();
    for (int i = 0; i < paces.length; i++) {
      final x = size.width  * i / (paces.length - 1);
      final y = size.height * (1 - (paces[i] - minP) / range * 0.8 - 0.1);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.records != records;
}
