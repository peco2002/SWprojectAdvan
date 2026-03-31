// lib/models/running_session.dart
// 러닝 세션 및 위치 기록 모델 (계획서 ③ 러닝 로그)

class RunningSession {
  final String   id;
  final DateTime startTime;
  final DateTime endTime;
  final double   totalDistanceKm;
  final int      durationSeconds;
  final int      averagePaceSec;     // sec/km
  final double   caloriesBurned;
  final List<PaceRecord> paceHistory;

  const RunningSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalDistanceKm,
    required this.durationSeconds,
    required this.averagePaceSec,
    required this.caloriesBurned,
    required this.paceHistory,
  });

  // ── 포맷 헬퍼 ───────────────────────────────────────────────

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    final m = averagePaceSec ~/ 60;
    final s = (averagePaceSec % 60).toString().padLeft(2, '0');
    return "$m'$s\"";
  }

  String get formattedDate {
    final d = startTime;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  // ── 직렬화 (Firebase Realtime DB용) ─────────────────────────

  Map<String, dynamic> toMap() => {
        'id':              id,
        'startTime':       startTime.toIso8601String(),
        'endTime':         endTime.toIso8601String(),
        'totalDistanceKm': totalDistanceKm,
        'durationSeconds': durationSeconds,
        'averagePaceSec':  averagePaceSec,
        'caloriesBurned':  caloriesBurned,
        'paceHistory':     paceHistory.map((p) => p.toMap()).toList(),
      };

  factory RunningSession.fromMap(Map<String, dynamic> m) => RunningSession(
        id:              m['id']              as String,
        startTime:       DateTime.parse(m['startTime'] as String),
        endTime:         DateTime.parse(m['endTime']   as String),
        totalDistanceKm: (m['totalDistanceKm'] as num).toDouble(),
        durationSeconds: m['durationSeconds']  as int,
        averagePaceSec:  m['averagePaceSec']   as int,
        caloriesBurned:  (m['caloriesBurned']  as num).toDouble(),
        paceHistory:     (m['paceHistory'] as List<dynamic>)
            .map((e) => PaceRecord.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── 위치·페이스 기록 (1~2초마다 수집) ─────────────────────────────

class PaceRecord {
  final DateTime timestamp;
  final double   distanceKm;
  final int      paceSec;    // sec/km
  final double   latitude;
  final double   longitude;

  const PaceRecord({
    required this.timestamp,
    required this.distanceKm,
    required this.paceSec,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() => {
        'ts':  timestamp.toIso8601String(),
        'km':  distanceKm,
        'pac': paceSec,
        'lat': latitude,
        'lng': longitude,
      };

  factory PaceRecord.fromMap(Map<String, dynamic> m) => PaceRecord(
        timestamp:  DateTime.parse(m['ts'] as String),
        distanceKm: (m['km']  as num).toDouble(),
        paceSec:    m['pac']  as int,
        latitude:   (m['lat'] as num).toDouble(),
        longitude:  (m['lng'] as num).toDouble(),
      );
}
