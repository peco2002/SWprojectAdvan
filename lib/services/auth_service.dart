// lib/services/auth_service.dart
// ══════════════════════════════════════════════════
// [팀원3 담당] Firebase Authentication 서비스
// - 이메일/비밀번호 회원가입
// - 이메일/비밀번호 로그인
// - 로그아웃
// - 현재 로그인 상태 확인
// ══════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── 현재 로그인된 유저 ────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── 로그인 상태 스트림 (main.dart에서 사용) ────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── 회원가입 ──────────────────────────────────────
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // 이름 저장
      await credential.user?.updateDisplayName(name);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // ── 로그인 ────────────────────────────────────────
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // ── 로그아웃 ──────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── 에러 메시지 한국어 변환 ───────────────────────
  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'user-not-found':
        return '존재하지 않는 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다.';
      default:
        return '오류가 발생했습니다. 다시 시도해주세요.';
    }
  }
}
