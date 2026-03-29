// lib/services/gps_service.dart
//
// 실시간 GPS 페이스 측정 (계획서 ② 실시간 GPS 음성 코칭 시스템)
// ─ 1~2초 간격 위치 수집
// ─ Haversine 공식으로 거리 계산
// ─ 5~10초 이동 평균 필터로 노이즈 제거

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/running_session.dart';

class GpsService {
  // ── 설정값 (계획서 사양) ─────────────────────────────────────
  static const _windowSec    = 7;    // 이동 평균 윈도우 (5~10초)
  static const _maxAccuracyM = 20.0; // 정확도 불량 임계값 (m)
  static const _minSpeedMs   = 0.5;  // 정지 판정 최소 속도 (m/s)
  static const _maxJumpKm    = 0.10; // GPS 튐 무시 임계값 (1.5초 내 100m)

  // ── 상태 ────────────────────────────────────────────────────
  final List<_Sample>   _window = [];
  StreamSubscription<Position>? _sub;
  Position? _lastPos;
  double    _totalKm = 0;
  bool      _active  = false;

  // ── 출력 스트림 ──────────────────────────────────────────────
  final _paceCtrl    = StreamController<int>.broadcast();
  final _distCtrl    = StreamController<double>.broadcast();
  final _recordCtrl  = StreamController<PaceRecord>.broadcast();

  /// 현재 페이스 스트림 (sec/km)
  Stream<int>    get paceStream   => _paceCtrl.stream;
  /// 누적 거리 스트림 (km)
  Stream<double> get distStream   => _distCtrl.stream;
  /// 위치 기록 스트림 (DB 저장용)
  Stream<PaceRecord> get recordStream => _recordCtrl.stream;

  double get totalKm => _totalKm;

  // ── 권한 확인 ────────────────────────────────────────────────
  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
           perm == LocationPermission.always;
  }

  // ── 세션 시작 ────────────────────────────────────────────────
  Future<void> start() async {
    if (_active) return;
    if (!await ensurePermission()) throw Exception('위치 권한 필요');
    _active = true;
    _window.clear();
    _lastPos = null;
    _totalKm = 0;

    const settings = LocationSettings(
      accuracy:       LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition);
  }

  // ── 세션 중지 ────────────────────────────────────────────────
  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    _sub = null;
  }

  // ── 위치 수신 처리 ───────────────────────────────────────────
  void _onPosition(Position pos) {
    if (pos.accuracy > _maxAccuracyM) return; // 정확도 불량 무시

    final now = DateTime.now();

    // 직전 위치 대비 거리 누적
    if (_lastPos != null) {
      final delta = _haversine(
        _lastPos!.latitude, _lastPos!.longitude,
        pos.latitude,       pos.longitude,
      );
      if (delta < _maxJumpKm) { // GPS 튐 무시
        _totalKm += delta;
        _distCtrl.add(_totalKm);
      }
    }
    _lastPos = pos;

    // 이동 평균 윈도우 갱신
    _window.add(_Sample(lat: pos.latitude, lng: pos.longitude, time: now));
    final cutoff = now.subtract(const Duration(seconds: _windowSec));
    _window.removeWhere((s) => s.time.isBefore(cutoff));

    // 평균 페이스 계산
    final pace = _smoothedPace();
    if (pace != null) {
      _paceCtrl.add(pace);
      _recordCtrl.add(PaceRecord(
        timestamp:  now,
        distanceKm: _totalKm,
        paceSec:    pace,
        latitude:   pos.latitude,
        longitude:  pos.longitude,
      ));
    }
  }

  // ── 이동 평균 페이스 계산 ────────────────────────────────────
  int? _smoothedPace() {
    if (_window.length < 2) return null;

    double totalM  = 0;
    int    totalMs = 0;
    for (int i = 1; i < _window.length; i++) {
      totalM  += _haversine(
        _window[i-1].lat, _window[i-1].lng,
        _window[i].lat,   _window[i].lng,
      ) * 1000;
      totalMs += _window[i].time.difference(_window[i-1].time).inMilliseconds;
    }
    if (totalMs == 0) return null;

    final speedMs = totalM / (totalMs / 1000); // m/s
    if (speedMs < _minSpeedMs) return null;    // 정지 처리

    return (1000 / speedMs).round().clamp(200, 1800); // 3'20"~30'00"
  }

  // ── Haversine 공식 (두 좌표 거리, km) ───────────────────────
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) +
              cos(_rad(lat1))*cos(_rad(lat2))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  static double _rad(double d) => d * pi / 180;

  void dispose() {
    stop();
    _paceCtrl.close();
    _distCtrl.close();
    _recordCtrl.close();
  }
}

class _Sample {
  final double lat, lng;
  final DateTime time;
  const _Sample({required this.lat, required this.lng, required this.time});
}
