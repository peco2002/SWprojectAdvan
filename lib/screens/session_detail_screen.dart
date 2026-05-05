// lib/screens/session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';

class SessionDetailScreen extends StatefulWidget {
  final RunningSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  GoogleMapController? _mapController;

  List<LatLng> get _routePoints => widget.session.paceHistory
      .where((r) => r.latitude != 0.0 && r.longitude != 0.0)
      .map((r) => LatLng(r.latitude, r.longitude))
      .toList();

  CameraPosition get _initialCamera {
    final points = _routePoints;
    if (points.isEmpty) {
      return const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 14);
    }
    if (points.length == 1) {
      return CameraPosition(target: points.first, zoom: 16);
    }
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final centerLat = lats.reduce((a, b) => a + b) / points.length;
    final centerLng = lngs.reduce((a, b) => a + b) / points.length;
    return CameraPosition(target: LatLng(centerLat, centerLng), zoom: 15);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final points = _routePoints;
    if (points.length < 2) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    });
  }

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
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kmPaces = _buildKmPaces(widget.session.paceHistory);
    final points  = _routePoints;
    final hasPaceChart = widget.session.paceHistory.length >= 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          widget.session.formattedDate,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 경로 지도 ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 220,
              child: points.isEmpty
                  ? Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Text('GPS 데이터 없음',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 14)),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: _initialCamera,
                      onMapCreated: _onMapCreated,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: points,
                          color: AppColors.primary,
                          width: 4,
                        ),
                      },
                      markers: {
                        Marker(
                          markerId: const MarkerId('start'),
                          position: points.first,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen),
                          infoWindow: const InfoWindow(title: '출발'),
                        ),
                        Marker(
                          markerId: const MarkerId('end'),
                          position: points.last,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: '도착'),
                        ),
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 통합 통계 카드 ────────────────────────
                  _SummaryCard(
                    session: widget.session,
                    heartRate: widget.session.averageHeartRate,
                  ),

                  // ── 페이스 변화 그래프 ───────────────────
                  if (hasPaceChart) ...[
                    const SizedBox(height: 20),
                    const Text(
                      '페이스 변화',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    _PaceChartEnhanced(records: widget.session.paceHistory),
                  ],

                  // ── 구간별 페이스 ─────────────────────────
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

// ── 통합 통계 카드 ───────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final RunningSession session;
  final int? heartRate;
  const _SummaryCard({required this.session, this.heartRate});

  String get _dateTime {
    final d   = session.startTime;
    final h   = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month}.${d.day.toString().padLeft(2, '0')}. $h:$min';
  }

  String get _durationHMS {
    final sec = session.durationSeconds;
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.totalDistanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(_dateTime, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatItem(
                    label: '운동 시간',
                    value: _durationHMS,
                    align: CrossAxisAlignment.start),
                const Spacer(),
                _StatItem(
                    label: '칼로리',
                    value: '${session.caloriesBurned.toStringAsFixed(0)} kcal',
                    align: CrossAxisAlignment.end),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatItem(
                    label: '평균 페이스',
                    value: '${session.formattedPace}/km',
                    align: CrossAxisAlignment.start),
                const Spacer(),
                _StatItem(
                    label: '평균 심박수',
                    value: heartRate != null ? '$heartRate BPM' : '-- BPM',
                    align: CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      );
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final CrossAxisAlignment align;
  const _StatItem(
      {required this.label, required this.value, required this.align});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: align,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

// ── 페이스 변화 그래프 ────────────────────────────────────────

class _PaceChartEnhanced extends StatelessWidget {
  final List<PaceRecord> records;
  const _PaceChartEnhanced({required this.records});

  @override
  Widget build(BuildContext context) {
    final valid = records.where((r) => r.paceSec > 0).toList();
    if (valid.length < 2) return const SizedBox.shrink();
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _PaceChartPainter(all: records, valid: valid),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PaceChartPainter extends CustomPainter {
  final List<PaceRecord> all;
  final List<PaceRecord> valid;
  const _PaceChartPainter({required this.all, required this.valid});

  String _fmtPace(int sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$m'$s\"";
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintChart(
      canvas: canvas,
      size: size,
      values: valid.map((r) => r.paceSec.toDouble()).toList(),
      timestamps: valid.map((r) => r.timestamp).toList(),
      t0: all.first.timestamp.millisecondsSinceEpoch.toDouble(),
      t1: all.last.timestamp.millisecondsSinceEpoch.toDouble(),
      lineColor: AppColors.primary,
      labelFmt: (v) => _fmtPace(v.toInt()),
    );
  }

  @override
  bool shouldRepaint(_PaceChartPainter old) =>
      old.all != all || old.valid != valid;
}

// ── 공통 차트 페인터 로직 ─────────────────────────────────────

void _paintChart({
  required Canvas canvas,
  required Size size,
  required List<double> values,
  required List<DateTime> timestamps,
  required double t0,
  required double t1,
  required Color lineColor,
  required String Function(double) labelFmt,
}) {
  if (values.length < 2) return;

  const lM = 12.0, rM = 56.0, tM = 10.0, bM = 24.0;
  final cL = lM, cR = size.width - rM;
  final cT = tM, cB = size.height - bM;
  final cW = cR - cL, cH = cB - cT;

  final maxV  = values.reduce((a, b) => a > b ? a : b);
  final minV  = values.reduce((a, b) => a < b ? a : b);
  final avgV  = values.reduce((a, b) => a + b) / values.length;
  final range = (maxV - minV).clamp(1.0, double.infinity);
  final tR    = (t1 - t0).clamp(1.0, double.infinity);

  double vy(double v) => cT + cH * (0.9 - (v - minV) / range * 0.8);
  double tx(DateTime ts) =>
      cL + cW * (ts.millisecondsSinceEpoch - t0) / tR;

  final fillPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lineColor.withOpacity(0.28), lineColor.withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(cL, cT, cW, cH))
    ..style = PaintingStyle.fill;

  final linePaint = Paint()
    ..color = lineColor
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final line = Path(), fill = Path();
  for (int i = 0; i < values.length; i++) {
    final x = tx(timestamps[i]);
    final y = vy(values[i]);
    if (i == 0) {
      line.moveTo(x, y);
      fill.moveTo(x, cB);
      fill.lineTo(x, y);
    } else {
      line.lineTo(x, y);
      fill.lineTo(x, y);
    }
  }
  fill.lineTo(tx(timestamps.last), cB);
  fill.close();
  canvas.drawPath(fill, fillPaint);
  canvas.drawPath(line, linePaint);

  // 평균 점선
  final avgY    = vy(avgV);
  final dashPnt = Paint()
    ..color = AppColors.textHint.withOpacity(0.55)
    ..strokeWidth = 1;
  _dash(canvas, Offset(cL, avgY), Offset(cR, avgY), dashPnt);

  // Y축 레이블
  _label(canvas, labelFmt(maxV), Offset(cR + 5, vy(maxV)));
  if ((vy(avgV) - vy(maxV)).abs() > 12 && (vy(minV) - vy(avgV)).abs() > 12) {
    _label(canvas, labelFmt(avgV),
        Offset(cR + 5, avgY), color: AppColors.textSecondary);
  }
  _label(canvas, labelFmt(minV), Offset(cR + 5, vy(minV)));

  // X축 시간 레이블 (4분할)
  for (int i = 0; i <= 4; i++) {
    final frac = i / 4.0;
    final x    = cL + cW * frac;
    final ms   = t0 + tR * frac;
    final dt   = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    final hh   = dt.hour.toString().padLeft(2, '0');
    final mm   = dt.minute.toString().padLeft(2, '0');
    _label(canvas, '$hh:$mm', Offset(x, cB + 12), align: TextAlign.center);
  }
}

void _dash(Canvas canvas, Offset a, Offset b, Paint p) {
  const dl = 5.0, gl = 4.0;
  final dir  = b - a;
  final dist = dir.distance;
  final unit = dir / dist;
  double d = 0;
  bool on = true;
  while (d < dist) {
    final step = on ? dl : gl;
    if (on) {
      canvas.drawLine(
          a + unit * d, a + unit * (d + step).clamp(0.0, dist), p);
    }
    d += step;
    on = !on;
  }
}

void _label(Canvas canvas, String text, Offset center,
    {double fontSize = 9.5,
    Color color = AppColors.textHint,
    TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text, style: TextStyle(color: color, fontSize: fontSize)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout();
  double dx = center.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;
  tp.paint(canvas, Offset(dx, center.dy - tp.height / 2));
}

// ── km별 페이스 행 ────────────────────────────────────────────

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
              child: Text('$km',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 10),
          const Text('km',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          const Spacer(),
          Text(PaceCalculator.formatPace(paceSec),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Text('/km',
              style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ]),
      );
}
