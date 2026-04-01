// lib/screens/signup_screen.dart
// ══════════════════════════════════════════════════
// [팀원3 담당] 회원가입 화면
// ══════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _pw2Ctrl   = TextEditingController();
  final _auth      = AuthService();

  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text('회원가입',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RunRight에 오신 것을 환영해요! 🏃',
                    style: AppTextStyles.subheading),
                const SizedBox(height: 6),
                const Text('계정을 만들고 맞춤 페이스를 받아보세요.',
                    style: AppTextStyles.body),
                const SizedBox(height: 32),

                _inputField(
                  controller: _nameCtrl,
                  label: '이름',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.isEmpty ? '이름을 입력해주세요' : null,
                ),
                const SizedBox(height: 14),

                _inputField(
                  controller: _emailCtrl,
                  label: '이메일',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? '올바른 이메일을 입력해주세요' : null,
                ),
                const SizedBox(height: 14),

                _inputField(
                  controller: _pwCtrl,
                  label: '비밀번호 (6자 이상)',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) =>
                      v == null || v.length < 6 ? '6자 이상 입력해주세요' : null,
                ),
                const SizedBox(height: 14),

                _inputField(
                  controller: _pw2Ctrl,
                  label: '비밀번호 확인',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) =>
                      v != _pwCtrl.text ? '비밀번호가 일치하지 않습니다' : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.tooFast, fontSize: 13)),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onSignup,
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
                        : const Text('회원가입',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _auth.signUp(
        email:    _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        name:     _nameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
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
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _pwCtrl.dispose();   _pw2Ctrl.dispose();
    super.dispose();
  }
}
