// lib/services/running_provider.dart
// Provider — GPS + TTS + 러닝 세션 상태 통합

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/pace_calculator.dart';
import '../models/body_profile.dart';
import '../models/running_session.dart';
import 'gps_service.dart';
import 'tts_service.dart';

enum SessionState { idle, running, paused, finished }

class RunningProvider extends ChangeNotifier {
  final _gps = GpsService();
  final _tts = TtsService();

  // ── 세션 상태 ────────────────────────────────────────────────
  SessionState state      = SessionState.idle;
  int    currentPaceSec  = 0;
  double distanceKm      = 0;
  int    elapsedSeconds  = 0;
  final  List<PaceRecord> history = [];

  // ── 신체 프로필 / 목표 페이스 ────────────────────────────────
  BodyProfile? profile;

  int get fastLimit => profile?.fastLimitSec ?? 0;
  int get slowLimit => profile?.slowLimitSec ?? 0;

  // ── 내부 ─────────────────────────────────────────────────────
  Timer? _timer;
  StreamSubscription<int>?        _paceSub;
  StreamSubscription<double>?     _distSub;
  StreamSubscription<PaceRecord>? _recSub;
  int _lastKm = 0;

  // ── 프로필 설정 ──────────────────────────────────────────────
  Future<void> setProfile(BodyProfile p) async {
    profile = p;
    await _tts.init();
    notifyListeners();
  }

  // ── 러닝 시작 ────────────────────────────────────────────────
  Future<void> startRun() async {
    if (state == SessionState.running) return;
    state = SessionState.running;
    elapsedSeconds = 0;
    distanceKm     = 0;
    currentPaceSec = 0;
    _lastKm        = 0;
    history.clear();
    notifyListeners();

    await _gps.start();
    await _tts.announceStart(fastLimit, slowLimit);

    _timer  = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
    _paceSub = _gps.paceStream.listen(_onPace);
    _distSub = _gps.distStream.listen(_onDist);
    _recSub  = _gps.recordStream.listen((r) => history.add(r));
  }

  // ── 일시정지 / 재개 ──────────────────────────────────────────
  Future<void> pause() async {
    if (state != SessionState.running) return;
    state = SessionState.paused;
    _timer?.cancel();
    await _gps.stop();
    await _tts.stop();
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != SessionState.paused) return;
    state = SessionState.running;
    await _gps.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  // ── 러닝 종료 ────────────────────────────────────────────────
  Future<RunningSession> stopRun() async {
    state = SessionState.finished;
    _timer?.cancel();
    await _paceSub?.cancel();
    await _distSub?.cancel();
    await _recSub?.cancel();
    await _gps.stop();

    final avgPace = history.isEmpty
        ? 0
        : history.map((r) => r.paceSec).reduce((a, b) => a + b) ~/ history.length;

    final calories = PaceCalculator.estimateCalories(
      weightKg:        profile?.weightKg ?? 65,
      durationSeconds: elapsedSeconds,
    );

    final session = RunningSession(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      startTime:       DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
      endTime:         DateTime.now(),
      totalDistanceKm: distanceKm,
      durationSeconds: elapsedSeconds,
      averagePaceSec:  avgPace,
      caloriesBurned:  calories,
      paceHistory:     List.from(history),
    );

    await _tts.announceFinish(
      distKm:     distanceKm,
      avgPaceSec: avgPace,
      elapsedSec: elapsedSeconds,
    );
    notifyListeners();
    return session;
  }

  // ── GPS 콜백 ─────────────────────────────────────────────────
  void _onPace(int pace) {
    currentPaceSec = pace;
    notifyListeners();

    if (fastLimit > 0) {
      final zone = PaceCalculator.judgeZone(
        currentPaceSec: pace,
        fastLimit:       fastLimit,
        slowLimit:       slowLimit,
      );
      _tts.onPaceZoneChanged(zone: zone, currentPaceSec: pace);
    }
  }

  void _onDist(double km) {
    distanceKm = km;
    final crossed = km.floor();
    if (crossed > _lastKm && crossed > 0) {
      _lastKm = crossed;
      _tts.announceKm(km: crossed, paceSec: currentPaceSec, elapsedSec: elapsedSeconds);
    }
    notifyListeners();
  }

  // ── UI 포맷 헬퍼 ─────────────────────────────────────────────
  String get displayPace => currentPaceSec == 0
      ? "--'--\""
      : PaceCalculator.formatPace(currentPaceSec);

  String get displayDistance => distanceKm.toStringAsFixed(2);

  String get displayElapsed {
    final m = elapsedSeconds ~/ 60;
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '${m.toString().padLeft(2, '0')}:$s';
  }

  String get displayTargetPace => fastLimit == 0
      ? '--'
      : '${PaceCalculator.formatPace(fastLimit)} ~ ${PaceCalculator.formatPace(slowLimit)}';

  PaceZone get currentZone => PaceCalculator.judgeZone(
        currentPaceSec: currentPaceSec,
        fastLimit:       fastLimit,
        slowLimit:       slowLimit,
      );

  @override
  void dispose() {
    _timer?.cancel();
    _gps.dispose();
    _tts.dispose();
    super.dispose();
  }
}
