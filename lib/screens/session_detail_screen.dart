// lib/screens/session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';
import '../services/heart_rate_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final RunningSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  GoogleMapController? _mapController;

  // 그래프 토글 (0: 페이스 변화, 1: 심박수 변화)
  int _chartIndex = 0;
  List<({DateTime timestamp, int bpm})> _hrPoints = [];
  bool _hrLoaded = false;

  static const _chartTitles = ['페이스 변화', '심박수 변화'];

  @override
  void initState() {
    super.initState();
    _loadHrPoints();
  }

  Future<void> _loadHrPoints() async {
    final points = await HeartRateService.getHeartRatePoints(
      widget.session.startTime,
      widget.session.endTime,
    );
    if (mounted) {
      setState(() {
        _hrPoints = points;
        _hrLoaded = true;
      });
    }
  }

  // ── 임시 디버그: HC 심박수 조회 결과 다이얼로그 ──────────────
  Future<void> _debugHr() async {
    final s = widget.session;
    String fmt(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          SizedBox(width: 16),
          Text('조회 중...', style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
    );

    final buf = StringBuffer();
    buf.writeln('조회 범위');
    buf.writeln('${fmt(s.startTime)} ~ ${fmt(s.endTime)}');
    buf.writeln('(${s.startTime.timeZoneName})');
    buf.writeln('');

    try {
      // requestAuthorization 결과
      final granted = await HeartRateService.requestPermission();
      buf.writeln('requestAuthorization: ${granted ? '허용' : '거부'}');

      // hasPermissions 실제 권한 확인
      final hasPerm = await HeartRateService.hasPermission();
      buf.writeln('hasPermissions: $hasPerm');
      buf.writeln('');

      // 예외 노출 버전으로 조회
      final (points, diagLog) = await HeartRateService.getHeartRatePointsDebug(
          s.startTime, s.endTime);

      buf.writeln('── 진단 로그 ──');
      buf.write(diagLog);
      buf.writeln('');

      buf.writeln('포인트 수: ${points.length}개');
      if (points.isNotEmpty) {
        final avg = points.map((p) => p.bpm).reduce((a, b) => a + b) ~/
            points.length;
        buf.writeln('평균: $avg BPM');
        buf.writeln('');
        buf.writeln('--- 처음 5개 ---');
        for (final p in points.take(5)) {
          buf.writeln('${fmt(p.timestamp)}  ${p.bpm} BPM');
        }
      }
    } catch (e) {
      buf.writeln('외부 에러: $e');
    }

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('HC 심박수 디버그',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(buf.toString(),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined,
                color: AppColors.textHint, size: 20),
            onPressed: _debugHr,
            tooltip: 'HC 심박수 디버그',
          ),
        ],
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
                  _SummaryCard(session: widget.session),

                  // ── 그래프 (페이스 / 심박수 토글) ───────────
                  if (hasPaceChart) ...[
                    const SizedBox(height: 20),
                    // 헤더: 화살표 + 타이틀
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: AppColors.textSecondary),
                          onPressed: () => setState(() =>
                              _chartIndex =
                                  (_chartIndex - 1 + _chartTitles.length) %
                                      _chartTitles.length),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _chartTitles[_chartIndex],
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: AppColors.textSecondary),
                          onPressed: () => setState(() =>
                              _chartIndex =
                                  (_chartIndex + 1) % _chartTitles.length),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 그래프 본체
                    if (_chartIndex == 0)
                      _PaceChartEnhanced(records: widget.session.paceHistory)
                    else
                      _HrChartEnhanced(
                        points: _hrPoints,
                        loaded: _hrLoaded,
                      ),
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
  const _SummaryCard({required this.session});

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
                    value:
                        '${session.caloriesBurned.toStringAsFixed(0)} kcal',
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
                    value: session.averageHeartRate != null
                        ? '${session.averageHeartRate} BPM'
                        : '-- BPM',
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

// ── 심박수 변화 그래프 ────────────────────────────────────────

class _HrChartEnhanced extends StatelessWidget {
  final List<({DateTime timestamp, int bpm})> points;
  final bool loaded;
  const _HrChartEnhanced({required this.points, required this.loaded});

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }
    if (points.length < 2) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('심박수 데이터 없음',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ),
      );
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _HrChartPainter(points: points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HrChartPainter extends CustomPainter {
  final List<({DateTime timestamp, int bpm})> points;
  const _HrChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    _paintChart(
      canvas: canvas,
      size: size,
      values: points.map((p) => p.bpm.toDouble()).toList(),
      timestamps: points.map((p) => p.timestamp).toList(),
      t0: points.first.timestamp.millisecondsSinceEpoch.toDouble(),
      t1: points.last.timestamp.millisecondsSinceEpoch.toDouble(),
      lineColor: Colors.redAccent,
      labelFmt: (v) => v.toInt().toString(),
    );
  }

  @override
  bool shouldRepaint(_HrChartPainter old) => old.points != points;
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

  // Fill
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
    _label(canvas, '$hh:$mm', Offset(x, cB + 12),
        align: TextAlign.center);
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
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
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
