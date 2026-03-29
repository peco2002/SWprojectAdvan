// lib/services/tts_service.dart
//
// TTS 음성 피드백 시스템 (계획서 ② TTS 음성 피드백)
// ─ 플랫폼 내장 TTS 엔진 활용
// ─ 쿨다운으로 과도한 알림 방지
// ─ 페이스 이탈 감지 후 10~15초 내 알림 달성 목표
// ─ 지능형 가이드: "페이스를 조금 낮춰보세요" 등 구체적 메시지

import 'package:flutter_tts/flutter_tts.dart';
import '../core/pace_calculator.dart';

class TtsService {
  final _tts = FlutterTts();

  static const _paceCooldownSec = 15; // 동일 상태 재알림 방지
  static const _kmCooldownSec   = 3;

  DateTime?  _lastPaceAlert;
  DateTime?  _lastKmAlert;
  PaceZone   _lastZone = PaceZone.stopped;
  bool       _ready    = false;

  // ── 초기화 ───────────────────────────────────────────────────
  Future<void> init() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  // ── 페이스 구간 판정 → 음성 출력 ────────────────────────────
  Future<void> onPaceZoneChanged({
    required PaceZone zone,
    required int currentPaceSec,
  }) async {
    if (!_ready) return;
    final now = DateTime.now();

    // 상태 변경 시 즉시, 동일 상태이면 쿨다운 적용
    final sinceLastAlert = _lastPaceAlert == null
        ? const Duration(days: 1)
        : now.difference(_lastPaceAlert!);
    final stateChanged = zone != _lastZone;

    if (!stateChanged && sinceLastAlert.inSeconds < _paceCooldownSec) return;

    _lastZone      = zone;
    _lastPaceAlert = now;

    final msg = _paceMessage(zone, currentPaceSec);
    if (msg != null) await _say(msg);
  }

  // ── km 통과 알림 ─────────────────────────────────────────────
  Future<void> announceKm({
    required int km,
    required int paceSec,
    required int elapsedSec,
  }) async {
    if (!_ready) return;
    final now = DateTime.now();
    if (_lastKmAlert != null &&
        now.difference(_lastKmAlert!).inSeconds < _kmCooldownSec) return;
    _lastKmAlert = now;

    final pace    = PaceCalculator.formatPaceKorean(paceSec);
    final elapsed = _fmtDur(elapsedSec);
    await _say('$km킬로미터 완주! 이번 킬로미터 페이스 $pace, 경과시간 $elapsed.');
  }

  // ── 시작 / 종료 안내 ─────────────────────────────────────────
  Future<void> announceStart(int fastSec, int slowSec) async {
    if (!_ready) return;
    final fast = PaceCalculator.formatPaceKorean(fastSec);
    final slow = PaceCalculator.formatPaceKorean(slowSec);
    await _say('러닝 시작합니다! 오늘 목표 페이스는 킬로미터당 $fast에서 $slow입니다. 화이팅!');
  }

  Future<void> announceFinish({
    required double distKm,
    required int    avgPaceSec,
    required int    elapsedSec,
  }) async {
    if (!_ready) return;
    final dist  = distKm.toStringAsFixed(2);
    final pace  = PaceCalculator.formatPaceKorean(avgPaceSec);
    final dur   = _fmtDur(elapsedSec);
    await _say('러닝 완료! 총 거리 ${dist}킬로미터, 평균 페이스 $pace, 운동 시간 $dur. 수고하셨습니다!');
  }

  // ── 내부 ─────────────────────────────────────────────────────
  String? _paceMessage(PaceZone zone, int paceSec) {
    final pace = PaceCalculator.formatPaceKorean(paceSec);
    switch (zone) {
      case PaceZone.tooFast:
        return '페이스가 너무 빠릅니다. 조금 천천히 달려보세요. 현재 킬로미터당 $pace입니다.';
      case PaceZone.good:
        return '완벽한 페이스예요! 이 속도를 유지하세요.';
      case PaceZone.tooSlow:
        return '조금 더 힘을 내보세요. 페이스를 올려볼까요? 현재 킬로미터당 $pace입니다.';
      case PaceZone.stopped:
        return null;
    }
  }

  Future<void> _say(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  static String _fmtDur(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return m > 0 ? '$m분 $s초' : '$s초';
  }

  Future<void> stop() async => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
