// lib/screens/home_screen.dart
// ── Firebase DB 기록 목록 추가 버전 ─────────────────
// 변경 사항:
//   _EmptyHistory → _SessionList (DB에서 기록 불러와서 표시)
//   로그아웃 버튼 추가

import 'dart:math';
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
import 'session_detail_screen.dart';

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
                  const _LogoutButton(),
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

// ── 로그아웃 버튼 ─────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  const _LogoutButton();

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textHint),
            )
          : const Icon(Icons.logout, color: AppColors.textHint),
      onPressed: _loading ? null : _logout,
    );
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      final navigator = Navigator.of(context);
      final provider  = Provider.of<RunningProvider>(context, listen: false);
      navigator.popUntil((route) => route.isFirst);
      await AuthService().signOut();
      provider.clearProfile();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
          itemBuilder: (_, i) => _SessionCard(session: sessions[i], uid: uid),
        );
      },
    );
  }
}

// ── 기록 카드 ─────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final RunningSession session;
  final String uid;
  const _SessionCard({required this.session, required this.uid});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('기록 삭제',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('이 러닝 기록을 삭제할까요?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tooFast,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService().deleteSession(uid, session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 러닝 정보 ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.formattedDate, style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Text(
                    '${session.totalDistanceKm.toStringAsFixed(2)} km'
                    '  ·  ${session.formattedDuration}'
                    '  ·  ${session.formattedPace}/km',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.caloriesBurned.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── 경로 썸네일 ──────────────────────────
            _RouteThumbnail(history: session.paceHistory),

            // ── 삭제 버튼 ──────────────────────────────
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textHint, size: 18),
              onPressed: () => _confirmDelete(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      ),
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

// ── 경로 썸네일 (CustomPaint) ─────────────────────────
class _RouteThumbnail extends StatelessWidget {
  final List<PaceRecord> history;
  const _RouteThumbnail({required this.history});

  @override
  Widget build(BuildContext context) {
    final points = history
        .where((r) => r.latitude != 0.0 || r.longitude != 0.0)
        .toList();

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: points.length < 2
            ? const Center(
                child: Icon(Icons.route, color: AppColors.textHint, size: 22),
              )
            : CustomPaint(
                painter: _RoutePainter(points),
                size: const Size(56, 56),
              ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<PaceRecord> points;
  const _RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final lats = points.map((p) => p.latitude).toList();
    final lngs = points.map((p) => p.longitude).toList();

    final minLat = lats.reduce(min);
    final maxLat = lats.reduce(max);
    final minLng = lngs.reduce(min);
    final maxLng = lngs.reduce(max);

    // 범위가 0이면 epsilon 처리 (직선 경로 등)
    final latRange = max(maxLat - minLat, 0.00001);
    final lngRange = max(maxLng - minLng, 0.00001);

    const padding = 6.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    Offset toOffset(PaceRecord r) => Offset(
          padding + (r.longitude - minLng) / lngRange * w,
          padding + (1 - (r.latitude - minLat) / latRange) * h,
        );

    // 경로 선
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = toOffset(points.first);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < points.length; i++) {
      final o = toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint);

    // 출발점 (초록)
    canvas.drawCircle(
      toOffset(points.first),
      2.5,
      Paint()..color = Colors.green,
    );
    // 도착점 (빨강)
    canvas.drawCircle(
      toOffset(points.last),
      2.5,
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.points.length != points.length;
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
