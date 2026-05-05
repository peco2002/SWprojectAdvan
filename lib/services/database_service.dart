// lib/services/database_service.dart
// ══════════════════════════════════════════════════
// [팀원4 담당] Firebase Realtime Database 서비스
// - 러닝 세션 저장
// - 러닝 기록 불러오기
// - 신체 데이터 저장/불러오기
// ══════════════════════════════════════════════════

import 'package:firebase_database/firebase_database.dart';
import '../models/running_session.dart';
import '../models/body_profile.dart';

class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ── 러닝 세션 저장 ────────────────────────────────
  // running_provider.dart 의 stopRun() 완료 후 호출
  Future<void> saveSession(String uid, RunningSession session) async {
    await _db
        .ref('users/$uid/sessions/${session.id}')
        .set(session.toMap());
  }

  // ── 러닝 기록 전체 불러오기 ───────────────────────
  // home_screen.dart 의 기록 목록에서 사용
  Future<List<RunningSession>> getSessions(String uid) async {
    final snapshot = await _db.ref('users/$uid/sessions').get();
    if (!snapshot.exists) return [];

    final List<RunningSession> sessions = [];
    final data = snapshot.value as Map<dynamic, dynamic>;

    data.forEach((key, value) {
      try {
        sessions.add(
          RunningSession.fromMap(Map<String, dynamic>.from(value as Map)),
        );
      } catch (_) {}
    });

    // 최신 순으로 정렬
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  // ── 러닝 기록 실시간 스트림 ───────────────────────
  // 기록이 추가될 때마다 자동 갱신
  Stream<List<RunningSession>> sessionStream(String uid) {
    return _db.ref('users/$uid/sessions').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final List<RunningSession> sessions = [];
      data.forEach((key, value) {
        try {
          sessions.add(
            RunningSession.fromMap(Map<String, dynamic>.from(value as Map)),
          );
        } catch (_) {}
      });
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    });
  }

  // ── 신체 데이터 저장 ──────────────────────────────
  // body_setup_screen.dart 에서 프로필 설정 완료 후 호출
  Future<void> saveProfile(String uid, BodyProfile profile) async {
    await _db.ref('users/$uid/profile').set(profile.toMap());
  }

  // ── 신체 데이터 불러오기 ──────────────────────────
  // 앱 재실행 시 저장된 프로필 불러오기
  Future<BodyProfile?> getProfile(String uid) async {
    final snapshot = await _db.ref('users/$uid/profile').get();
    if (!snapshot.exists) return null;
    return BodyProfile.fromMap(
      Map<String, dynamic>.from(snapshot.value as Map),
    );
  }

  // ── 최근 N개 세션 불러오기 (적응형 알고리즘용) ────
  Future<List<RunningSession>> getRecentSessions(String uid,
      {int limit = 5}) async {
    final all = await getSessions(uid); // 이미 최신 순 정렬
    return all.take(limit).toList();
  }

  // ── 러닝 세션 삭제 ────────────────────────────────
  Future<void> deleteSession(String uid, String sessionId) async {
    await _db.ref('users/$uid/sessions/$sessionId').remove();
  }

  // ── 평균 심박수 업데이트 (TCX 가져오기용) ─────────
  Future<void> updateSessionHeartRate(
      String uid, String sessionId, int bpm) async {
    await _db
        .ref('users/$uid/sessions/$sessionId/averageHeartRate')
        .set(bpm);
  }
}
