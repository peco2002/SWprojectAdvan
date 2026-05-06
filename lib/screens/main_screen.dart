// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/running_provider.dart';
import '../services/tcx_share_service.dart';
import '../models/running_session.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱이 공유로 열렸을 때 (첫 진입)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSharedTcx());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 백그라운드에서 포그라운드로 전환될 때 (공유로 복귀)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSharedTcx();
    }
  }

  Future<void> _checkSharedTcx() async {
    final data = await TcxShareService.getPendingData();
    if (data == null || !mounted) return;

    final bpm = data.bpm!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final sessions = await DatabaseService().getSessions(uid);
    if (sessions.isEmpty || !mounted) return;

    // TCX <Id> 타임스탬프(UTC)와 세션 시작 시간을 대조해 ±10분 이내 세션 매칭
    RunningSession? matched;
    if (data.startTime != null) {
      for (final s in sessions) {
        final diff = s.startTime.difference(data.startTime!).abs();
        if (diff.inMinutes <= 10) {
          matched = s;
          break;
        }
      }
    }

    if (matched == null) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('매칭 실패',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            '동일한 시간대의 운동기록이 존재하지 않습니다.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final target = matched;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('심박수 데이터 가져오기',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '평균 심박수 $bpm BPM을\n'
          '${target.formattedDate} 세션에 적용할까요?',
          style: const TextStyle(
              color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await DatabaseService().updateSessionHeartRate(uid, target.id, bpm);

    // 웨어러블 사용자: HR 적용 후 적응형 보정 실행
    if (mounted) {
      final provider = Provider.of<RunningProvider>(context, listen: false);
      if (provider.profile?.hasWearable == true) {
        await provider.adaptAfterHeartRateUpdate(uid);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('평균 심박수 $bpm BPM이 적용됐습니다.',
            style: const TextStyle(fontSize: 13, color: AppColors.primary)),
        backgroundColor: AppColors.card,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _idx,
        children: [
          const HomeScreen(),
          StatisticsScreen(uid: uid),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _idx,
          onTap: (i) => setState(() => _idx = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: '통계',
            ),
          ],
        ),
      ),
    );
  }
}
