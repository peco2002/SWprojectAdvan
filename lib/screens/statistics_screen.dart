// lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';
import '../services/database_service.dart';

enum _Period { week, month, year }

class StatisticsScreen extends StatefulWidget {
  final String uid;
  const StatisticsScreen({super.key, required this.uid});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _Period _period = _Period.week;
  late int _weekIdx;
  late int _monthIdx;
  late int _yearIdx;
  late final Stream<List<RunningSession>> _stream;

  // ── 기간 목록 (날짜가 늘어나면 자동 확장) ──────────────────────────
  List<DateTime> get _weeks {
    final firstMonday = DateTime(2026, 1, 5); // 2026년 첫 월요일
    final now = DateTime.now();
    final todayFloor = DateTime(now.year, now.month, now.day);
    final currentMonday =
        todayFloor.subtract(Duration(days: todayFloor.weekday - 1));
    final last =
        currentMonday.isBefore(firstMonday) ? firstMonday : currentMonday;

    final list = <DateTime>[];
    var d = DateTime(2026, 1, 5);
    while (!d.isAfter(last)) {
      list.add(d);
      d = d.add(const Duration(days: 7));
    }
    return list.isEmpty ? [DateTime(2026, 1, 5)] : list;
  }

  List<DateTime> get _months {
    final now = DateTime.now();
    final list = <DateTime>[];
    var d = DateTime(2026, 1);
    while (d.year < now.year ||
        (d.year == now.year && d.month <= now.month)) {
      list.add(d);
      d = DateTime(d.year, d.month + 1);
    }
    return list.isEmpty ? [DateTime(2026, 1)] : list;
  }

  List<int> get _years {
    final endYear = DateTime.now().year >= 2026 ? DateTime.now().year : 2026;
    return List.generate(endYear - 2025, (i) => 2026 + i);
  }

  @override
  void initState() {
    super.initState();
    _stream = widget.uid.isEmpty
        ? const Stream.empty()
        : DatabaseService().sessionStream(widget.uid);
    _weekIdx  = _weeks.length  - 1;
    _monthIdx = _months.length - 1;
    _yearIdx  = _years.length  - 1;
  }

  // ── 라벨 ──────────────────────────────────────────────────────────
  String _weekLabel(DateTime monday) {
    final weekOfMonth = ((monday.day - 1) ~/ 7) + 1;
    return '${monday.year}년 ${monday.month}월 $weekOfMonth주차';
  }

  String _monthLabel(DateTime m) => '${m.year}년 ${m.month}월';
  String _yearLabel(int y)       => '$y년';

  // ── 캐러셀 섹션 ──────────────────────────────────────────────────
  Widget _buildCarousel() {
    switch (_period) {
      case _Period.week:
        final labels = _weeks.map(_weekLabel).toList();
        return _PeriodCarousel(
          key:          const ValueKey(_Period.week),
          labels:       labels,
          initialIndex: _weekIdx.clamp(0, labels.length - 1),
          onChanged:    (i) => setState(() => _weekIdx = i),
        );
      case _Period.month:
        final labels = _months.map(_monthLabel).toList();
        return _PeriodCarousel(
          key:          const ValueKey(_Period.month),
          labels:       labels,
          initialIndex: _monthIdx.clamp(0, labels.length - 1),
          onChanged:    (i) => setState(() => _monthIdx = i),
        );
      case _Period.year:
        final labels = _years.map(_yearLabel).toList();
        return _PeriodCarousel(
          key:          const ValueKey(_Period.year),
          labels:       labels,
          initialIndex: _yearIdx.clamp(0, labels.length - 1),
          onChanged:    (i) => setState(() => _yearIdx = i),
        );
    }
  }

  // ── 기간 필터 ─────────────────────────────────────────────────────
  List<RunningSession> _filter(List<RunningSession> all) {
    switch (_period) {
      case _Period.week:
        final weeks     = _weeks;
        final weekStart = weeks[_weekIdx.clamp(0, weeks.length - 1)];
        final weekEnd   = weekStart.add(const Duration(days: 7));
        return all
            .where((s) =>
                !s.startTime.isBefore(weekStart) &&
                s.startTime.isBefore(weekEnd))
            .toList();
      case _Period.month:
        final months = _months;
        final m      = months[_monthIdx.clamp(0, months.length - 1)];
        return all
            .where((s) =>
                s.startTime.year  == m.year &&
                s.startTime.month == m.month)
            .toList();
      case _Period.year:
        final years = _years;
        final y     = years[_yearIdx.clamp(0, years.length - 1)];
        return all.where((s) => s.startTime.year == y).toList();
    }
  }

  // ── 요약 통계 ─────────────────────────────────────────────────────
  ({int runs, int totalSec, double km, double cal, int avgPace})
      _calcSummary(List<RunningSession> sessions) {
    if (sessions.isEmpty) {
      return (runs: 0, totalSec: 0, km: 0.0, cal: 0.0, avgPace: 0);
    }
    final sec  = sessions.fold(0,   (s, e) => s + e.durationSeconds);
    final km   = sessions.fold(0.0, (s, e) => s + e.totalDistanceKm);
    final cal  = sessions.fold(0.0, (s, e) => s + e.caloriesBurned);
    final pace = km > 0 ? (sec / km).round() : 0;
    return (runs: sessions.length, totalSec: sec, km: km, cal: cal, avgPace: pace);
  }

  // ── 막대 데이터 ───────────────────────────────────────────────────
  List<BarChartGroupData> _buildGroups(List<RunningSession> sessions) {
    final bw = _period == _Period.year ? 14.0
             : _period == _Period.month ? 7.0
             : 28.0;

    BarChartGroupData g(int x, double km) => BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: km,
              color: km > 0 ? AppColors.primary : AppColors.card,
              width: bw,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );

    switch (_period) {
      case _Period.week:
        final d = <int, double>{for (int i = 1; i <= 7; i++) i: 0.0};
        for (final s in sessions) {
          d[s.startTime.weekday] = (d[s.startTime.weekday] ?? 0) + s.totalDistanceKm;
        }
        return List.generate(7, (i) => g(i, d[i + 1] ?? 0));
      case _Period.month:
        final d = <int, double>{for (int i = 0; i < 31; i++) i: 0.0};
        for (final s in sessions) {
          final idx = s.startTime.day - 1; // day 1 → index 0
          d[idx] = (d[idx] ?? 0) + s.totalDistanceKm;
        }
        return List.generate(31, (i) => g(i, d[i] ?? 0));
      case _Period.year:
        final d = <int, double>{for (int i = 1; i <= 12; i++) i: 0.0};
        for (final s in sessions) {
          d[s.startTime.month] = (d[s.startTime.month] ?? 0) + s.totalDistanceKm;
        }
        return List.generate(12, (i) => g(i, d[i + 1] ?? 0));
    }
  }

  List<String> get _xLabels {
    switch (_period) {
      case _Period.week:
        return ['월', '화', '수', '목', '금', '토', '일'];
      case _Period.month:
        const monthTicks = {0: '1', 5: '6', 11: '12', 17: '18', 23: '24', 29: '30'};
        return List.generate(31, (i) => monthTicks[i] ?? '');
      case _Period.year:
        return ['1월', '2월', '3월', '4월', '5월', '6월',
                '7월', '8월', '9월', '10월', '11월', '12월'];
    }
  }

  double _niceMax(double raw) {
    if (raw <= 0) return 5;
    if (raw <= 2) return 2;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 20) return 20;
    if (raw <= 50) return 50;
    return ((raw / 10).ceil() * 10).toDouble();
  }

  double _niceInterval(double max) {
    if (max <= 2) return 0.5;
    if (max <= 5) return 1;
    if (max <= 10) return 2;
    if (max <= 20) return 5;
    return 10;
  }

  String _fmtTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('통계', style: AppTextStyles.heading),
              const SizedBox(height: 16),

              // ── 기간 탭 ────────────────────────────────
              _PeriodTabs(
                current:   _period,
                onChanged: (p) => setState(() => _period = p),
              ),

              const SizedBox(height: 10),

              // ── 캐러셀 ────────────────────────────────
              _buildCarousel(),

              const SizedBox(height: 14),

              // ── 데이터 영역 ────────────────────────────
              Expanded(
                child: widget.uid.isEmpty
                    ? const _EmptyLogin()
                    : StreamBuilder<List<RunningSession>>(
                        stream: _stream,
                        builder: (context, snap) {
                          if (snap.connectionState ==
                                  ConnectionState.waiting &&
                              !snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            );
                          }

                          final filtered = _filter(snap.data ?? []);
                          final stats    = _calcSummary(filtered);
                          final groups   = _buildGroups(filtered);
                          final rawMax   = groups
                              .map((g) => g.barRods.first.toY)
                              .fold(0.0, (a, b) => a > b ? a : b);
                          final maxY     = _niceMax(rawMax);
                          final interval = _niceInterval(maxY);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 그래프 (~30% 화면 높이)
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.30,
                                child: filtered.isEmpty
                                    ? const _EmptyPeriod()
                                    : _BarChartView(
                                        groups:   groups,
                                        xLabels:  _xLabels,
                                        maxY:     maxY,
                                        interval: interval,
                                        period:   _period,
                                      ),
                              ),

                              const SizedBox(height: 24),

                              // 통계 요약 (3+2 텍스트)
                              _StatsRows(
                                runs:    stats.runs,
                                sec:     stats.totalSec,
                                km:      stats.km,
                                cal:     stats.cal,
                                pace:    stats.avgPace,
                                fmtTime: _fmtTime,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 기간 탭 버튼 ─────────────────────────────────────────────────────
class _PeriodTabs extends StatelessWidget {
  final _Period current;
  final void Function(_Period) onChanged;
  const _PeriodTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {_Period.week: '주', _Period.month: '월', _Period.year: '년'};
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == current;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[p]!,
                  style: TextStyle(
                    color: active ? Colors.black : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 기간 캐러셀 ───────────────────────────────────────────────────────
class _PeriodCarousel extends StatefulWidget {
  final List<String> labels;
  final int initialIndex;
  final void Function(int) onChanged;

  const _PeriodCarousel({
    super.key,
    required this.labels,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_PeriodCarousel> createState() => _PeriodCarouselState();
}

class _PeriodCarouselState extends State<_PeriodCarousel> {
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      initialPage:      widget.initialIndex.clamp(0, widget.labels.length - 1),
      viewportFraction: 0.40,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final page = _ctrl.hasClients
              ? (_ctrl.page ?? widget.initialIndex.toDouble())
              : widget.initialIndex.toDouble();

          return PageView.builder(
            controller:    _ctrl,
            itemCount:     widget.labels.length,
            onPageChanged: widget.onChanged,
            itemBuilder:   (context, i) {
              final dist   = (page - i).abs().clamp(0.0, 1.0);
              final color  = Color.lerp(AppColors.primary,
                                        AppColors.textSecondary, dist)!;
              final fSize  = 15.0 - dist * 3.0; // 15 → 12
              final fWeight = dist < 0.5
                  ? FontWeight.bold
                  : FontWeight.normal;
              return Center(
                child: Text(
                  widget.labels[i],
                  style: TextStyle(
                    color:      color,
                    fontSize:   fSize,
                    fontWeight: fWeight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── 요약 통계 — 박스 없는 3+2 텍스트 ────────────────────────────────
class _StatsRows extends StatelessWidget {
  final int runs, sec, pace;
  final double km, cal;
  final String Function(int) fmtTime;
  const _StatsRows({
    required this.runs,
    required this.sec,
    required this.km,
    required this.cal,
    required this.pace,
    required this.fmtTime,
  });

  @override
  Widget build(BuildContext context) {
    final paceStr = pace > 0 ? PaceCalculator.formatPace(pace) : "--'--\"";
    return Column(
      children: [
        // 1행: 러닝 · 시간 · 거리
        Row(
          children: [
            Expanded(child: Center(child: _Col('$runs', '러닝'))),
            Expanded(child: Center(child: _Col(fmtTime(sec), '시간'))),
            Expanded(child: Center(child: _Col('${km.toStringAsFixed(2)} km', '거리'))),
          ],
        ),
        const SizedBox(height: 18),
        // 2행: 칼로리 · 평균페이스
        Row(
          children: [
            Expanded(child: Center(child: _Col('${cal.toStringAsFixed(0)} kcal', '칼로리'))),
            Expanded(child: Center(child: _Col(paceStr, '평균페이스'))),
          ],
        ),
      ],
    );
  }
}

class _Col extends StatelessWidget {
  final String value, label;
  const _Col(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      );
}

// ── 막대 그래프 ──────────────────────────────────────────────────────
class _BarChartView extends StatelessWidget {
  final List<BarChartGroupData> groups;
  final List<String> xLabels;
  final double maxY, interval;
  final _Period period;
  const _BarChartView({
    required this.groups,
    required this.xLabels,
    required this.maxY,
    required this.interval,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final isYear = period == _Period.year;
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.divider,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 36,
              interval:     interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                final s = value % 1 == 0
                    ? value.toInt().toString()
                    : value.toStringAsFixed(1);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(s,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: isYear ? 28 : 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= xLabels.length || xLabels[i].isEmpty) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(xLabels[i],
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: isYear ? 8 : 11)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            getTooltipItem: (_, __, rod, ___) {
              if (rod.toY == 0) return null;
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(2)} km',
                const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────────────
class _EmptyLogin extends StatelessWidget {
  const _EmptyLogin();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('로그인 후 통계를 확인하세요.',
            style: TextStyle(color: AppColors.textHint, fontSize: 13)));
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.directions_run, color: AppColors.textHint, size: 40),
          SizedBox(height: 10),
          Text('해당 기간에 러닝 기록이 없어요.',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ]));
}
