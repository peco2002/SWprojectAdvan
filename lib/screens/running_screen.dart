// lib/screens/running_screen.dart
// 실시간 러닝 화면 — GPS 페이스 모니터링 + TTS 코칭

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';
import '../services/running_provider.dart';
import 'result_screen.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _started = false;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSub;

  static const _defaultPos = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 16,
  );

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final p = Provider.of<RunningProvider>(context, listen: false);
        p.resetRun();
        p.addListener(_onGpsUpdate);
        _startLocationStream();
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    Provider.of<RunningProvider>(context, listen: false)
        .removeListener(_onGpsUpdate);
    _mapController?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // 러닝 시작 전: 실시간 위치 스트림으로 카메라 갱신
  void _startLocationStream() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // 3m 이상 이동 시 갱신
      ),
    ).listen((pos) {
      if (!mounted || _mapController == null) return;
      final p = Provider.of<RunningProvider>(context, listen: false);
      // 러닝 중이 아닐 때만 카메라 자동 이동 (러닝 중엔 _onGpsUpdate가 담당)
      if (p.state != SessionState.running) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
        );
      }
    });
  }

  // 러닝 중: Provider history 기반 카메라 이동
  void _onGpsUpdate() {
    if (!mounted || _mapController == null) return;
    final history =
        Provider.of<RunningProvider>(context, listen: false).history;
    if (history.isEmpty) return;
    final last = history.last;
    if (last.latitude == 0.0 && last.longitude == 0.0) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(last.latitude, last.longitude)),
    );
  }

  // GPS 버튼: 현재 위치로 즉시 이동
  Future<void> _moveToCurrentLocation() async {
    if (_mapController == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<RunningProvider>();
    final zone = p.currentZone;

    final zoneColor = switch (zone) {
      PaceZone.tooFast => AppColors.tooFast,
      PaceZone.good    => AppColors.good,
      PaceZone.tooSlow => AppColors.tooSlow,
      PaceZone.stopped => AppColors.stopped,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── 상단 바 ────────────────────────────────────────
          _TopBar(onClose: () => _askStop(context, p)),

          // ── 목표 페이스 ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('목표 ', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                Text(p.displayTargetPace,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Text(' /km', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── 실시간 지도 + GPS 버튼 ─────────────────────────
          Stack(
            children: [
              _LiveMap(
                history:      p.history,
                onMapCreated: (c) {
                  _mapController = c;
                  _moveToCurrentLocation(); // 지도 생성 시 현재 위치로 이동
                },
                defaultPos:   _defaultPos,
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: _moveToCurrentLocation,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── 상태 배너 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ZoneBanner(zone: zone, color: zoneColor, pulse: _pulse),
          ),

          const SizedBox(height: 16),

          // ── 현재 페이스 (메인 숫자) ──────────────────────────
          _PaceHero(pace: p.displayPace, color: zoneColor),

          const SizedBox(height: 16),

          // ── 거리 / 시간 ────────────────────────────────────
          _StatsRow(distance: p.displayDistance, elapsed: p.displayElapsed),

          const Spacer(),

          // ── 컨트롤 버튼 ────────────────────────────────────
          _Controls(
            state:   p.state,
            started: _started,
            onStart:  () async { setState(() => _started = true); await p.startRun(); },
            onPause:  p.pause,
            onResume: p.resume,
            onStop:   () => _askStop(context, p),
          ),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _askStop(BuildContext ctx, RunningProvider p) {
    // 시작 전에 나가면 그냥 팝 (저장 없음)
    if (!_started || p.state == SessionState.idle) {
      Navigator.pop(ctx);
      return;
    }
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('러닝 종료', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('지금 러닝을 종료할까요?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('계속 달리기', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final session = await p.stopRun();
              if (ctx.mounted) {
                Navigator.pushReplacement(ctx,
                    MaterialPageRoute(builder: (_) => ResultScreen(session: session)));
              }
            },
            child: const Text('종료', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── 컴포넌트 ─────────────────────────────────────────────────────

// ── 실시간 경로 지도 ──────────────────────────────────────────
class _LiveMap extends StatelessWidget {
  final List<PaceRecord> history;
  final void Function(GoogleMapController) onMapCreated;
  final CameraPosition defaultPos;

  const _LiveMap({
    required this.history,
    required this.onMapCreated,
    required this.defaultPos,
  });

  List<LatLng> get _points => history
      .where((r) => !(r.latitude == 0.0 && r.longitude == 0.0))
      .map((r) => LatLng(r.latitude, r.longitude))
      .toList();

  @override
  Widget build(BuildContext context) {
    final pts = _points;

    return SizedBox(
      height: 190,
      child: GoogleMap(
        initialCameraPosition: defaultPos,
        onMapCreated: onMapCreated,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        polylines: pts.length >= 2
            ? {
                Polyline(
                  polylineId: const PolylineId('live'),
                  points: pts,
                  color: AppColors.primary,
                  width: 4,
                ),
              }
            : {},
        markers: pts.isNotEmpty
            ? {
                // 현재 위치 마커
                Marker(
                  markerId: const MarkerId('current'),
                  position: pts.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
                // 출발 마커 (2개 이상일 때만)
                if (pts.length >= 2)
                  Marker(
                    markerId: const MarkerId('start'),
                    position: pts.first,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                  ),
              }
            : {},
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.close, color: AppColors.textHint), onPressed: onClose),
          const Expanded(
            child: Text('러닝 중', textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 48),
        ]),
      );
}

class _ZoneBanner extends StatelessWidget {
  final PaceZone zone;
  final Color color;
  final AnimationController pulse;
  const _ZoneBanner({required this.zone, required this.color, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (zone) {
      PaceZone.tooFast => (Icons.arrow_downward_rounded, '페이스를 낮춰보세요'),
      PaceZone.good    => (Icons.check_circle_outline,   '완벽한 페이스! 유지하세요'),
      PaceZone.tooSlow => (Icons.arrow_upward_rounded,   '조금 더 힘내보세요'),
      PaceZone.stopped => (Icons.play_circle_outline,    '시작 버튼을 눌러주세요'),
    };

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(zone == PaceZone.good
              ? 0.12
              : 0.06 + pulse.value * 0.08),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _PaceHero extends StatelessWidget {
  final String pace;
  final Color color;
  const _PaceHero({required this.pace, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(pace, style: AppTextStyles.paceHero.copyWith(color: color, fontSize: 80)),
        const SizedBox(height: 4),
        Text('/km', style: TextStyle(color: color.withOpacity(0.6), fontSize: 16)),
      ]);
}

class _StatsRow extends StatelessWidget {
  final String distance, elapsed;
  const _StatsRow({required this.distance, required this.elapsed});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: '거리', value: distance, unit: 'km'),
          Container(width: 1, height: 40, color: AppColors.divider),
          _Stat(label: '시간', value: elapsed, unit: ''),
        ],
      );
}

class _Stat extends StatelessWidget {
  final String label, value, unit;
  const _Stat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        RichText(text: TextSpan(children: [
          TextSpan(text: value,
              style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 30, fontWeight: FontWeight.bold)),
          if (unit.isNotEmpty)
            TextSpan(text: ' $unit',
                style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
        ])),
      ]);
}

class _Controls extends StatelessWidget {
  final SessionState state;
  final bool started;
  final VoidCallback onStart, onPause, onResume, onStop;
  const _Controls({required this.state, required this.started,
      required this.onStart, required this.onPause,
      required this.onResume, required this.onStop});

  @override
  Widget build(BuildContext context) {
    if (!started || state == SessionState.idle) {
      return _BigBtn('시작', Icons.play_arrow_rounded, AppColors.primary, onStart);
    }
    if (state == SessionState.running) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _BigBtn('일시정지', Icons.pause_rounded, Colors.orangeAccent, onPause),
        const SizedBox(width: 20),
        _BigBtn('종료', Icons.stop_rounded, AppColors.tooFast, onStop),
      ]);
    }
    if (state == SessionState.paused) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _BigBtn('계속', Icons.play_arrow_rounded, AppColors.primary, onResume),
        const SizedBox(width: 20),
        _BigBtn('종료', Icons.stop_rounded, AppColors.tooFast, onStop),
      ]);
    }
    return const SizedBox.shrink();
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
