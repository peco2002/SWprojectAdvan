// lib/screens/home_screen.dart
// ── Firebase DB 기록 목록 추가 버전 ─────────────────
// 변경 사항:
//   _EmptyHistory → _SessionList (DB에서 기록 불러와서 표시)
//   로그아웃 버튼 추가

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/pace_calculator.dart';
import '../models/body_profile.dart';
import '../models/running_session.dart';
import '../services/running_provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'running_screen.dart';
import 'session_detail_screen.dart';
import 'pace_result_screen.dart';

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
              if (profile != null && profile.fastLimitSec != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaceResultScreen()),
                  ),
                  child: _MyPaceCard(
                    fast:     PaceCalculator.formatPace(profile.fastLimitSec!),
                    slow:     PaceCalculator.formatPace(profile.slowLimitSec!),
                    vo2max:   profile.vo2max!,
                    hasInbody: profile.hasInbodyData,
                    tempoKm:  profile.recommendedDistances?['tempo'] ?? 0.0,
                    longKm:   profile.recommendedDistances?['long']  ?? 0.0,
                  ),
                )
              else if (profile != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(children: [
                    Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('VO₂max 모델 로드 실패 — 앱을 재시작해 주세요.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ]),
                ),

              const SizedBox(height: 16),

              // ── 러닝 시작 버튼 ───────────────────────
              _StartButton(onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RunningScreen()),
              )),

              // ── 디버그: 가짜 세션 주입 (debug 빌드에서만 표시) ──
              if (kDebugMode && profile != null && profile.fastLimitSec != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DebugSimulateButton(profile: profile),
                ),

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

class _SessionList extends StatefulWidget {
  final String uid;
  const _SessionList({required this.uid});

  @override
  State<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<_SessionList> {
  late final Stream<List<RunningSession>> _stream;

  @override
  void initState() {
    super.initState();
    // 스트림을 한 번만 생성 — rebuild마다 재생성하면 구독이 끊겼다 재연결되어
    // 최신 세션이 잠시 안 보이는 문제 발생
    _stream = widget.uid.isEmpty
        ? const Stream.empty()
        : DatabaseService().sessionStream(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const _EmptyHistory();

    return StreamBuilder<List<RunningSession>>(
      stream: _stream,
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
          itemBuilder: (_, i) =>
              _SessionCard(session: sessions[i], uid: widget.uid),
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
                  Row(children: [
                    Text(session.formattedDate, style: AppTextStyles.caption),
                    const Spacer(),
                    Icon(
                      session.averageHeartRate != null
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 14,
                      color: session.averageHeartRate != null
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  ]),
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

class _MyPaceCard extends StatefulWidget {
  final String fast, slow;
  final double vo2max;
  final bool hasInbody;
  final double tempoKm, longKm;
  const _MyPaceCard({
    required this.fast,
    required this.slow,
    required this.vo2max,
    required this.hasInbody,
    required this.tempoKm,
    required this.longKm,
  });

  @override
  State<_MyPaceCard> createState() => _MyPaceCardState();
}

class _MyPaceCardState extends State<_MyPaceCard> {
  bool _isTempo = true;

  @override
  Widget build(BuildContext context) {
    final pace   = _isTempo ? widget.fast : widget.slow;
    final distKm = _isTempo ? widget.tempoKm : widget.longKm;

    return Container(
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
          _buildToggle(),
          const Spacer(),
          if (widget.hasInbody)
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pace,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 10, right: 10),
              child: Text('·',
                  style: TextStyle(
                      color: AppColors.primary.withOpacity(0.4),
                      fontSize: 22, fontWeight: FontWeight.w300)),
            ),
            Text('${distKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '/km  ·  VO₂max ${widget.vo2max.toStringAsFixed(0)} ml/kg/min',
          style: AppTextStyles.caption,
        ),
      ]),
    );
  }

  Widget _buildToggle() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('템포런', _isTempo, () => setState(() => _isTempo = true)),
          const SizedBox(width: 4),
          _chip('롱런', !_isTempo, () => setState(() => _isTempo = false)),
        ],
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

// ── 경로 썸네일 (Static Maps API) ────────────────────
class _RouteThumbnail extends StatelessWidget {
  final List<PaceRecord> history;
  const _RouteThumbnail({required this.history});

  String? _buildStaticMapUrl() {
    final points = history
        .where((r) => !(r.latitude == 0.0 && r.longitude == 0.0))
        .toList();
    if (points.length < 2) return null;

    // 최대 50개 균등 샘플링
    final List<PaceRecord> sampled;
    if (points.length <= 50) {
      sampled = points;
    } else {
      sampled = [];
      final step = (points.length - 1) / 49;
      for (int i = 0; i < 50; i++) {
        sampled.add(points[(i * step).round()]);
      }
    }

    final path  = sampled.map((p) => '${p.latitude},${p.longitude}').join('|');
    final first = points.first;
    final last  = points.last;

    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?size=144x144'
        '&scale=1'
        '&maptype=roadmap'
        '&style=feature:all|element:labels|visibility:off'
        '&style=feature:poi|visibility:off'
        '&style=feature:transit|visibility:off'
        '&path=color:0x2ECC71FF|weight:5|$path'
        '&markers=size:tiny|color:green|${first.latitude},${first.longitude}'
        '&markers=size:tiny|color:red|${last.latitude},${last.longitude}'
        '&key=${AppConstants.mapsApiKey}';
  }

  @override
  Widget build(BuildContext context) {
    final url = _buildStaticMapUrl();

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url == null
            ? const Center(
                child: Icon(Icons.route, color: AppColors.textHint, size: 22),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.route, color: AppColors.textHint, size: 22),
                ),
              ),
      ),
    );
  }
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

// ── 디버그: 세션 시뮬레이션 버튼 ─────────────────────────
class _DebugSimulateButton extends StatefulWidget {
  final BodyProfile profile;
  const _DebugSimulateButton({required this.profile});

  @override
  State<_DebugSimulateButton> createState() => _DebugSimulateButtonState();
}

class _DebugSimulateButtonState extends State<_DebugSimulateButton> {
  bool _loading = false;

  Future<void> _showDialog() async {
    if (widget.profile.fastLimitSec == null) return;

    final result = await showDialog<({
      String runType,
      int    paceSec,
      double distKm,
      int    durSec,
      int?   bpm,
    })>(
      context: context,
      builder: (_) => _DebugSimulateDialog(profile: widget.profile),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);
    final provider  = Provider.of<RunningProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final output = await provider.debugSimulateRun(
      runType:         result.runType,
      avgPaceSec:      result.paceSec,
      distanceKm:      result.distKm,
      durationSeconds: result.durSec,
      averageHeartRate: result.bpm,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    messenger.showSnackBar(SnackBar(
      content: Text(output,
          style: const TextStyle(
              fontSize: 12, height: 1.5, color: AppColors.primary)),
      backgroundColor: AppColors.card,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textHint))
            : const Icon(Icons.science_outlined,
                size: 16, color: AppColors.textHint),
        label: const Text('[TEST] 세션 시뮬레이션',
            style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: _loading ? null : _showDialog,
      ),
    );
  }
}

// ── 디버그: 시뮬레이션 다이얼로그 ────────────────────────
class _DebugSimulateDialog extends StatefulWidget {
  final BodyProfile profile;
  const _DebugSimulateDialog({required this.profile});

  @override
  State<_DebugSimulateDialog> createState() => _DebugSimulateDialogState();
}

class _DebugSimulateDialogState extends State<_DebugSimulateDialog> {
  String _runType = 'tempo';

  static final _paceMinList = List.generate(14, (i) => i + 2);  // 2..15
  static final _paceSecList = List.generate(60, (i) => i);       // 0..59
  static final _distList    = List.generate(43, (i) => i + 1);   // 1..43 km

  late int _paceMin;
  late int _paceSec;
  int _selectedDistKm = 5;
  String _bpmText = '';

  late final FixedExtentScrollController _paceMinCtrl;
  late final FixedExtentScrollController _paceSecCtrl;
  late final FixedExtentScrollController _distCtrl;

  @override
  void initState() {
    super.initState();
    final mid = ((widget.profile.fastLimitSec! + widget.profile.slowLimitSec!) / 2).round();
    _paceMin = (mid ~/ 60).clamp(2, 15);
    _paceSec = (mid % 60).clamp(0, 59);

    _paceMinCtrl = FixedExtentScrollController(
        initialItem: (_paceMin - 2).clamp(0, _paceMinList.length - 1));
    _paceSecCtrl = FixedExtentScrollController(
        initialItem: _paceSec.clamp(0, 59));
    _distCtrl    = FixedExtentScrollController(
        initialItem: (_selectedDistKm - 1).clamp(0, _distList.length - 1));
  }

  @override
  void dispose() {
    _paceMinCtrl.dispose();
    _paceSecCtrl.dispose();
    _distCtrl.dispose();
    super.dispose();
  }

  int    get _avgPaceSec => _paceMin * 60 + _paceSec;
  double get _distKm     => _selectedDistKm.toDouble();
  int    get _durSec     => (_selectedDistKm * _avgPaceSec);

  String get _durStr {
    final h = _durSec ~/ 3600;
    final m = (_durSec % 3600) ~/ 60;
    final s = _durSec % 60;
    if (h > 0) return '${h}시간 ${m}분 ${s}초';
    return '${m}분 ${s}초';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('[TEST] 세션 시뮬레이션',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
              fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 현재 설정 요약 ────────────────────────
            Text(
              '목표: ${PaceCalculator.formatPace(p.fastLimitSec!)} ~ ${PaceCalculator.formatPace(p.slowLimitSec!)}  ·  세션 ${p.sessionCount}회',
              style: const TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── 런 타입 ───────────────────────────────
            _label('런 타입'),
            const SizedBox(height: 8),
            Row(children: [
              _typeChip('템포런', 'tempo'),
              const SizedBox(width: 8),
              _typeChip('롱런', 'long'),
            ]),
            const SizedBox(height: 20),

            // ── 페이스 다이얼 ─────────────────────────
            _label('페이스 (분\' 초" /km)'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _picker(
                controller: _paceMinCtrl,
                items: _paceMinList.map((m) => '$m분').toList(),
                onChanged: (i) => setState(() => _paceMin = _paceMinList[i]),
              )),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text("'", style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 22)),
              ),
              Expanded(child: _picker(
                controller: _paceSecCtrl,
                items: _paceSecList
                    .map((s) => s.toString().padLeft(2, '0'))
                    .toList(),
                onChanged: (i) => setState(() => _paceSec = i),
              )),
            ]),
            Center(child: Text(
              '→ ${PaceCalculator.formatPace(_avgPaceSec)} /km',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
            )),
            const SizedBox(height: 20),

            // ── 운동 거리 다이얼 ──────────────────────
            _label('운동 거리'),
            const SizedBox(height: 8),
            _picker(
              controller: _distCtrl,
              items: _distList.map((d) => '$d km').toList(),
              onChanged: (i) => setState(() => _selectedDistKm = _distList[i]),
            ),
            Center(child: Text(
              '→ $_durStr',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
            )),
            const SizedBox(height: 20),

            // ── BPM 입력 ──────────────────────────────
            _label('평균 심박수 (선택)'),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '미입력 시 심박수 없음',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                suffixText: 'BPM',
                suffixStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) => _bpmText = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: AppColors.textHint)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(context, (
            runType: _runType,
            paceSec: _avgPaceSec,
            distKm:  _distKm,
            durSec:  _durSec,
            bpm:     int.tryParse(_bpmText),
          )),
          child: const Text('시뮬레이션', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary,
          fontSize: 12, fontWeight: FontWeight.w600));

  Widget _typeChip(String label, String value) {
    final sel = _runType == value;
    return GestureDetector(
      onTap: () => setState(() => _runType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.black : AppColors.textHint,
          fontWeight: FontWeight.w600, fontSize: 13,
        )),
      ),
    );
  }

  Widget _picker({
    required FixedExtentScrollController controller,
    required List<String> items,
    required ValueChanged<int> onChanged,
  }) =>
      SizedBox(
        height: 110,
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 34,
          backgroundColor: AppColors.card,
          selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
            background: Color(0x22B3FF5C),
          ),
          onSelectedItemChanged: onChanged,
          children: items
              .map((t) => Center(
                    child: Text(t,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 16)),
                  ))
              .toList(),
        ),
      );
}
