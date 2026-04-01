// lib/screens/home_screen.dart
// ── Firebase DB 기록 목록 추가 버전 ─────────────────
// 변경 사항:
//   _EmptyHistory → _SessionList (DB에서 기록 불러와서 표시)
//   로그아웃 버튼 추가

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/running_session.dart';
import '../services/running_provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'running_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RunningProvider>();
    final profile  = provider.profile;
    final uid      = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더 ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('RunRight 🏃', style: AppTextStyles.heading),
                    const SizedBox(height: 2),
                    Text(
                      profile != null
                          ? '${profile.name}님, 오늘도 달려볼까요?'
                          : '오늘도 달려볼까요?',
                      style: AppTextStyles.body,
                    ),
                  ]),
                  // 로그아웃 버튼
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.textHint),
                    onPressed: () async {
                      await AuthService().signOut();
                      // StreamBuilder가 자동으로 LoginScreen으로 전환
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── 맞춤 페이스 카드 ─────────────────────
              if (profile != null)
                _MyPaceCard(
                  fast:      PaceCalculator.formatPace(profile.fastLimitSec),
                  slow:      PaceCalculator.formatPace(profile.slowLimitSec),
                  vo2max:    profile.vo2max,
                  hasInbody: profile.hasInbodyData,
                ),

              const SizedBox(height: 16),

              // ── 러닝 시작 버튼 ───────────────────────
              _StartButton(onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RunningScreen()),
              )),

              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 12),

              // ── 최근 기록 ────────────────────────────
              const Text('최근 러닝 기록',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // ── DB에서 기록 불러오기 ──────────────────
              Expanded(child: _SessionList(uid: uid)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 기록 목록 (Firebase DB 연동) ──────────────────────

class _SessionList extends StatelessWidget {
  final String uid;
  const _SessionList({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const _EmptyHistory();

    return StreamBuilder<List<RunningSession>>(
      stream: DatabaseService().sessionStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) return const _EmptyHistory();

        return ListView.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
        );
      },
    );
  }
}

// ── 기록 카드 ─────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final RunningSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_run,
              color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.formattedDate, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(
              '${session.totalDistanceKm.toStringAsFixed(2)}km  ·  ${session.formattedDuration}  ·  ${session.formattedPace}/km',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        Text(
          '${session.caloriesBurned.toStringAsFixed(0)}kcal',
          style: const TextStyle(color: AppColors.textHint, fontSize: 12),
        ),
      ]),
    );
  }
}

// ── 기록 없을 때 ──────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.directions_run,
              color: AppColors.textHint, size: 44),
          const SizedBox(height: 12),
          const Text(
            '아직 러닝 기록이 없어요.\n첫 번째 러닝을 시작해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textHint, fontSize: 13, height: 1.6),
          ),
        ]),
      );
}

// ── 페이스 카드 / 시작 버튼 (기존과 동일) ─────────────

class _MyPaceCard extends StatelessWidget {
  final String fast, slow;
  final double vo2max;
  final bool hasInbody;
  const _MyPaceCard({required this.fast, required this.slow,
      required this.vo2max, required this.hasInbody});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.primaryDark.withOpacity(0.06),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('내 맞춤 페이스',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            const SizedBox(width: 6),
            if (hasInbody)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('인바디 반영',
                    style: TextStyle(color: Colors.teal, fontSize: 9)),
              ),
          ]),
          const SizedBox(height: 8),
          Text('$fast  ~  $slow',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('/km  ·  VO₂max ${vo2max.toStringAsFixed(0)} ml/kg/min',
              style: AppTextStyles.caption),
        ]),
      );
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, height: 58,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 16, offset: const Offset(0, 6),
            )],
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
            SizedBox(width: 8),
            Text('러닝 시작', style: TextStyle(
                color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}
