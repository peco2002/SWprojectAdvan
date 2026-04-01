// lib/screens/login_screen.dart
// ══════════════════════════════════════════════════
// [팀원3 담당] 로그인 화면
// ══════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'body_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _pwCtrl     = TextEditingController();
  final _auth       = AuthService();

  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // ── 로고 ────────────────────────────────────
                const Text('RunRight 🏃',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('러닝 입문자를 위한 맞춤 코칭 앱',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),

                const SizedBox(height: 48),

                // ── 이메일 ───────────────────────────────────
                _inputField(
                  controller: _emailCtrl,
                  label: '이메일',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? '올바른 이메일을 입력해주세요' : null,
                ),
                const SizedBox(height: 14),

                // ── 비밀번호 ─────────────────────────────────
                _inputField(
                  controller: _pwCtrl,
                  label: '비밀번호',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? '6자 이상 입력해주세요' : null,
                ),

                // ── 에러 메시지 ──────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.tooFast, fontSize: 13)),
                ],

                const SizedBox(height: 28),

                // ── 로그인 버튼 ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : const Text('로그인',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 회원가입 이동 ─────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                    ),
                    child: const Text(
                      '계정이 없으신가요?  회원가입',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 로그인 처리 ────────────────────────────────────
  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      // 로그인 성공 → main.dart의 StreamBuilder가 자동으로 화면 전환
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textHint),
        labelStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.card,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.tooFast),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.tooFast),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }
}
