// lib/services/running_provider.dart
// ── Firebase DB 저장 추가 버전 ──────────────────────
// 변경 사항:
//   setProfile() 완료 후 DatabaseService.saveProfile() 호출 추가
//   stopRun() 완료 후 DatabaseService.saveSession() 호출 추가

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/pace_calculator.dart';
import '../models/body_profile.dart';
import '../models/running_session.dart';
import 'gps_service.dart';
import 'tts_service.dart';
import 'database_service.dart';

enum SessionState { idle, running, paused, finished }

class RunningProvider extends ChangeNotifier {
  final _gps = GpsService();
  final _tts = TtsService();
  final _db  = DatabaseService();

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
  int     _lastKm = 0;
  String? _currentRunType; // 현재 러닝 세션의 런 타입
  String? get currentRunType => _currentRunType;

  // ── 회원가입 시 이름 임시 저장 ───────────────────────────────
  String? pendingName;

  void setPendingName(String name) {
    pendingName = name;
  }

  // ── 러닝 상태 초기화 (러닝 화면 진입 시) ───────────────────
  void resetRun() {
    _timer?.cancel();
    state          = SessionState.idle;
    elapsedSeconds = 0;
    distanceKm     = 0;
    currentPaceSec = 0;
    _lastKm        = 0;
    history.clear();
    notifyListeners();
  }

  // ── 프로필 초기화 (로그아웃 시) ─────────────────────────────
  void clearProfile() {
    profile     = null;
    pendingName = null;
    notifyListeners();
  }

  // ── 프로필 DB에서 로드 (앱 재실행 / 로그인 시) ──────────────
  Future<bool> loadProfile(String uid) async {
    final p = await _db.getProfile(uid);
    if (p == null) return false;

    // 기존 계정 마이그레이션: hasWearable 미설정 시 세션 HR 데이터로 자동 감지
    if (p.hasWearable == null) {
      final sessions = await _db.getRecentSessions(uid, limit: 10);
      final hasHr    = sessions.any((s) => s.averageHeartRate != null);
      final migrated = p.copyWith(hasWearable: hasHr);
      await _db.saveProfile(uid, migrated);
      profile = migrated;
    } else {
      profile = p;
    }

    await _tts.init();
    notifyListeners();
    return true;
  }

  // ── 프로필 설정 ──────────────────────────────────────────────
  Future<void> setProfile(BodyProfile p) async {
    profile = p;
    await _tts.init();

    // ── 신체 데이터 DB 저장 ────────────────────────
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _db.saveProfile(uid, p);
    }

    notifyListeners();
  }

  // ── 러닝 시작 ────────────────────────────────────────────────
  Future<void> startRun(String runType) async {
    if (state == SessionState.running) return;
    _currentRunType = runType;
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
    await _tts.announcePause();
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != SessionState.paused) return;
    state = SessionState.running;
    await _gps.start();
    await _tts.announceResume();
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
      weightKg:    profile?.weightKg ?? 65,
      distanceKm:  distanceKm,
    );

    final endTime   = DateTime.now();
    final startTime = endTime.subtract(Duration(seconds: elapsedSeconds));
    final session = RunningSession(
      id:               endTime.millisecondsSinceEpoch.toString(),
      startTime:        startTime,
      endTime:          endTime,
      totalDistanceKm:  distanceKm,
      durationSeconds:  elapsedSeconds,
      averagePaceSec:   avgPace,
      caloriesBurned:   calories,
      averageHeartRate: null,
      runType:          _currentRunType,
      paceHistory:      List.from(history),
    );

    // ── Firebase DB에 저장 + 적응형 보정 ────────────
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _db.saveSession(uid, session);
      if (profile?.hasWearable == true) {
        // 웨어러블 사용자: 카운트만 증가, TCX 임포트 후 보정
        await _incrementSessionCount(uid, session);
      } else {
        // 웨어러블 없는 사용자: 즉시 보정
        await _adaptProfile(uid, session);
      }
    }

    await _tts.announceFinish(
      distKm:     distanceKm,
      avgPaceSec: avgPace,
      elapsedSec: elapsedSeconds,
    );
    notifyListeners();
    return session;
  }

  // ── 세션 카운트만 증가 (웨어러블 사용자 전용) ────────────────
  Future<void> _incrementSessionCount(String uid, RunningSession session) async {
    if (profile == null || session.durationSeconds < 600) return;
    final updated = profile!.copyWith(sessionCount: profile!.sessionCount + 1);
    profile = updated;
    await _db.saveProfile(uid, updated);
    notifyListeners();
  }

  // ── TCX 임포트 후 보정 (웨어러블 사용자 전용, main_screen에서 호출) ─
  Future<void> adaptAfterHeartRateUpdate(String uid) async {
    if (profile == null) return;
    if (profile!.sessionCount < 3) return;
    if (profile!.fastLimitSec == null) return;

    final recent = await _db.getRecentSessions(uid, limit: 6);
    final valid  = recent.where((s) => s.durationSeconds >= 600).take(5).toList();
    if (valid.isEmpty) return;

    final v = profile!.vo2max;
    if (v == null) return;
    final baseDists = PaceCalculator.recommendedDistances(
      vo2max:         v,
      fitnessLevel:   profile!.fitnessLevel,
      weightKg:       profile!.weightKg,
      heightCm:       profile!.heightCm,
      gender:         profile!.gender,
      bodyFatPercent: profile!.bodyFatPercent,
    );

    final result = PaceCalculator.adaptFromSessions(
      sessions:            valid,
      currentFastLimitSec: profile!.fastLimitSec!,
      currentSlowLimitSec: profile!.slowLimitSec!,
      currentPaceAdjustSec: profile!.paceAdjustSec,
      currentTempoDistKm:  profile!.adaptedTempoDistKm ?? baseDists['tempo']!,
      currentLongDistKm:   profile!.adaptedLongDistKm  ?? baseDists['long']!,
      baseTempoDistKm:     baseDists['tempo']!,
      baseLongDistKm:      baseDists['long']!,
    );

    final updated = profile!.copyWith(
      paceAdjustSec:      result.paceAdjustSec,
      adaptedTempoDistKm: result.tempoDistKm,
      adaptedLongDistKm:  result.longDistKm,
    );

    profile = updated;
    await _db.saveProfile(uid, updated);
    notifyListeners();
  }

  // ── 적응형 보정 (웨어러블 없는 사용자 전용) ──────────────────
  Future<void> _adaptProfile(String uid, RunningSession latest) async {
    if (profile == null) return;
    if (latest.durationSeconds < 600) return;

    final newCount = profile!.sessionCount + 1;

    // 3회 미만이면 카운트만 증가
    if (newCount < 3) {
      final updated = profile!.copyWith(sessionCount: newCount);
      profile = updated;
      await _db.saveProfile(uid, updated);
      notifyListeners();
      return;
    }

    // 최근 유효 세션 최대 5개 조회
    final recent = await _db.getRecentSessions(uid, limit: 6);
    final valid  = recent
        .where((s) => s.durationSeconds >= 600)
        .take(5)
        .toList();
    if (valid.isEmpty) return;

    final v = profile!.vo2max;
    if (v == null) return;
    final baseDists = PaceCalculator.recommendedDistances(
      vo2max:         v,
      fitnessLevel:   profile!.fitnessLevel,
      weightKg:       profile!.weightKg,
      heightCm:       profile!.heightCm,
      gender:         profile!.gender,
      bodyFatPercent: profile!.bodyFatPercent,
    );

    final result = PaceCalculator.adaptFromSessions(
      sessions:            valid,
      currentFastLimitSec: profile!.fastLimitSec!,
      currentSlowLimitSec: profile!.slowLimitSec!,
      currentPaceAdjustSec: profile!.paceAdjustSec,
      currentTempoDistKm:  profile!.adaptedTempoDistKm ?? baseDists['tempo']!,
      currentLongDistKm:   profile!.adaptedLongDistKm  ?? baseDists['long']!,
      baseTempoDistKm:     baseDists['tempo']!,
      baseLongDistKm:      baseDists['long']!,
    );

    final updated = profile!.copyWith(
      paceAdjustSec:      result.paceAdjustSec,
      adaptedTempoDistKm: result.tempoDistKm,
      adaptedLongDistKm:  result.longDistKm,
      sessionCount:       newCount,
    );

    profile = updated;
    await _db.saveProfile(uid, updated);
    notifyListeners();
  }

  // ── 디버그: 가짜 세션 주입 (테스트 전용) ─────────────────────
  Future<String> debugSimulateRun({
    required String runType,
    required int    avgPaceSec,
    required double distanceKm,
    required int    durationSeconds,
    int? averageHeartRate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인 필요';
    if (profile == null) return '프로필 없음';

    final endTime   = DateTime.now();
    final startTime = endTime.subtract(Duration(seconds: durationSeconds));

    final session = RunningSession(
      id:              endTime.millisecondsSinceEpoch.toString(),
      startTime:       startTime,
      endTime:         endTime,
      totalDistanceKm: distanceKm,
      durationSeconds: durationSeconds,
      averagePaceSec:  avgPaceSec,
      caloriesBurned:  PaceCalculator.estimateCalories(
        weightKg:   profile!.weightKg,
        distanceKm: distanceKm,
      ),
      runType:          runType,
      averageHeartRate: averageHeartRate,
      paceHistory: [],
    );

    final beforeCount = profile!.sessionCount;
    final beforeFast  = profile!.fastLimitSec;
    final beforeSlow  = profile!.slowLimitSec;
    final beforeTempo = profile!.adaptedTempoDistKm
        ?? profile!.recommendedDistances?['tempo'];
    final beforeLong  = profile!.adaptedLongDistKm
        ?? profile!.recommendedDistances?['long'];

    await _db.saveSession(uid, session);
    // 디버그 시뮬레이션은 hasWearable 무관하게 즉시 보정
    await _adaptProfile(uid, session);

    final afterFast  = profile!.fastLimitSec;
    final afterSlow  = profile!.slowLimitSec;
    final afterTempo = profile!.recommendedDistances?['tempo'];
    final afterLong  = profile!.recommendedDistances?['long'];
    final newCount   = profile!.sessionCount;

    String fmt(int? s) => s == null ? '-' : PaceCalculator.formatPace(s);

    final bpmLabel = averageHeartRate != null ? '  ·  HR $averageHeartRate BPM' : '';
    return '[$runType$bpmLabel]  세션 추가 ($beforeCount → $newCount회)\n'
        '페이스: ${fmt(beforeFast)}~${fmt(beforeSlow)}'
        ' → ${fmt(afterFast)}~${fmt(afterSlow)}\n'
        '템포 거리: ${beforeTempo?.toStringAsFixed(1) ?? '-'}'
        ' → ${afterTempo?.toStringAsFixed(1) ?? '-'} km\n'
        '롱런 거리: ${beforeLong?.toStringAsFixed(1) ?? '-'}'
        ' → ${afterLong?.toStringAsFixed(1) ?? '-'} km';
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
