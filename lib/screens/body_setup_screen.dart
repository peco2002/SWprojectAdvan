// lib/screens/body_setup_screen.dart
//
// ══════════════════════════════════════════════════
//  [메인 기능] 신체 데이터 입력 화면
//  계획서 ① Flutter 기반 개인 맞춤형 모바일 트레이닝 환경 구축
//    - 신체 데이터 동적 연동 (키·몸무게·나이·성별)
//    - 인바디 데이터 선택 입력 (체지방률·근육량)
// ══════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/body_profile.dart';
import '../services/running_provider.dart';
import 'pace_result_screen.dart';

class BodySetupScreen extends StatefulWidget {
  final String uid;
  final String name;
  const BodySetupScreen({super.key, required this.uid, required this.name});

  @override
  State<BodySetupScreen> createState() => _BodySetupScreenState();
}

class _BodySetupScreenState extends State<BodySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0; // 0: 기본정보, 1: 운동경험, 2: 인바디(선택)

  // 컨트롤러
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '65');
  final _ageCtrl    = TextEditingController(text: '25');
  final _fatCtrl    = TextEditingController();
  final _muscleCtrl = TextEditingController();

  String _gender       = 'male';
  String _fitnessLevel = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _step),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: [
                    _buildStep0(),
                    _buildStep1(),
                    _buildStep2(),
                  ][_step],
                ),
              ),
            ),
            _BottomNav(
              step: _step,
              onBack:  _step == 0 ? null : () => setState(() => _step--),
              onNext:  _onNext,
              lastStep: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: 기본 신체 정보 ────────────────────────────────────
  Widget _buildStep0() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('신체 정보를 알려주세요', '정확한 페이스를 계산하려면\n키·몸무게·나이가 필요해요.'),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: _numField(_heightCtrl, '키',   'cm', min: 130, max: 220)),
            const SizedBox(width: 14),
            Expanded(child: _numField(_weightCtrl, '체중', 'kg', min: 30,  max: 200)),
          ]),
          const SizedBox(height: 16),
          _numField(_ageCtrl, '나이', '세', min: 10, max: 80),
          const SizedBox(height: 24),
          _label('성별'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _genderBtn('남성', 'male',   Icons.male)),
            const SizedBox(width: 12),
            Expanded(child: _genderBtn('여성', 'female', Icons.female)),
          ]),
        ],
      );

  // ── Step 1: 운동 경험 ────────────────────────────────────────
  Widget _buildStep1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('운동 경험은 어느 정도인가요?', '현재 체력 수준에 맞는\n페이스를 추천해 드려요.'),
          const SizedBox(height: 28),
          _fitnessCard('none',       '처음 시작해요',     '운동 경험이 거의 없어요',     Icons.directions_walk),
          const SizedBox(height: 12),
          _fitnessCard('occasional', '가끔 운동해요',     '가끔씩 운동하는 편이에요',    Icons.directions_run),
          const SizedBox(height: 12),
          _fitnessCard('regular',    '꾸준히 운동해요',   '주 1~2회 이상 운동해요',     Icons.fitness_center),
        ],
      );

  // ── Step 2: 인바디 (선택) ─────────────────────────────────────
  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('인바디 데이터가 있나요? (선택)', '체지방률·근육량을 입력하면\n더 정밀한 페이스를 계산해요.\n없으면 그냥 넘어가도 됩니다.'),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.monitor_heart, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('인바디 측정값',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _numField(_fatCtrl,    '체지방률',  '%',  min: 3,  max: 60,  required: false)),
                const SizedBox(width: 14),
                Expanded(child: _numField(_muscleCtrl, '골격근량',  'kg', min: 10, max: 80,  required: false)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            '인바디 데이터를 입력하면 체지방률과 근육량을\n반영해 훨씬 정밀한 맞춤 페이스를 드려요.',
            style: TextStyle(color: AppColors.textHint, fontSize: 13, height: 1.5),
          ),
        ],
      );

  // ── 컴포넌트 ─────────────────────────────────────────────────

  Widget _title(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading),
          const SizedBox(height: 8),
          Text(sub, style: AppTextStyles.body.copyWith(height: 1.6)),
        ],
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary,
          fontSize: 13, fontWeight: FontWeight.w500));

  Widget _numField(TextEditingController ctrl, String label, String unit,
      {required double min, required double max, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        labelStyle: const TextStyle(color: AppColors.textHint),
        suffixStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.card,
        enabledBorder:  _border(AppColors.divider),
        focusedBorder:  _border(AppColors.primary),
        errorBorder:    _border(Colors.redAccent),
        focusedErrorBorder: _border(Colors.redAccent),
      ),
      validator: (v) {
        if (!required && (v == null || v.isEmpty)) return null;
        if (required  &&  (v == null || v.isEmpty)) return '입력해주세요';
        final n = double.tryParse(v!);
        if (n == null)         return '숫자를 입력해주세요';
        if (n < min || n > max) return '$min~$max';
        return null;
      },
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderSide: BorderSide(color: color),
        borderRadius: BorderRadius.circular(10),
      );

  Widget _genderBtn(String label, String value, IconData icon) {
    final sel = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.12) : AppColors.card,
          border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: sel ? AppColors.primary : AppColors.textHint),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: sel ? AppColors.primary : AppColors.textSecondary,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _fitnessCard(String value, String title, String sub, IconData icon) {
    final sel = _fitnessLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _fitnessLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.10) : AppColors.card,
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.divider, width: sel ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: sel ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: sel ? AppColors.primary : AppColors.textHint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: sel ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: AppTextStyles.caption),
          ])),
          if (sel) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        ]),
      ),
    );
  }

  // ── 다음 버튼 핸들러 ─────────────────────────────────────────
  void _onNext() async {
    if (_step < 2) {
      if (_step == 0 && !_formKey.currentState!.validate()) return;
      setState(() => _step++);
      return;
    }

    // Step 2 완료 → 프로필 생성 → 페이스 결과 화면
    final profile = BodyProfile(
      uid:            widget.uid,
      name:           widget.name,
      heightCm:       double.parse(_heightCtrl.text),
      weightKg:       double.parse(_weightCtrl.text),
      age:            int.parse(_ageCtrl.text),
      gender:         _gender,
      fitnessLevel:   _fitnessLevel,
      bodyFatPercent: _fatCtrl.text.isNotEmpty ? double.tryParse(_fatCtrl.text) : null,
      muscleMassKg:   _muscleCtrl.text.isNotEmpty ? double.tryParse(_muscleCtrl.text) : null,
    );

    await context.read<RunningProvider>().setProfile(profile);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaceResultScreen()),
      );
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose(); _weightCtrl.dispose();
    _ageCtrl.dispose();    _fatCtrl.dispose(); _muscleCtrl.dispose();
    super.dispose();
  }
}

// ── 하단 네비게이션 ───────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int step, lastStep;
  final VoidCallback? onBack, onNext;
  const _BottomNav({required this.step, required this.lastStep,
      required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      color: AppColors.background,
      child: Row(children: [
        if (onBack != null)
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
          ),
        if (onBack != null) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              step == lastStep ? '내 페이스 확인하기' : '다음',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 단계 표시기 ────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(children: List.generate(3, (i) {
        final active = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      })),
    );
  }
}
