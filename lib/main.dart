// lib/main.dart
// ── Firebase 연동 완료 버전 ──────────────────────────
// 변경 사항:
//   1. Firebase 초기화 추가
//   2. 로그인 상태에 따라 LoginScreen / BodySetupScreen 분기

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'core/constants.dart';
import 'services/running_provider.dart';
import 'services/vo2max_model.dart';
import 'screens/login_screen.dart';
import 'screens/body_setup_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  // 오프라인 캐시 활성화: 네트워크 없이도 기존 데이터 즉시 로드
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (_) {}
  await VO2maxModel.instance.initialize();
  runApp(const RunRightApp());
}

class RunRightApp extends StatelessWidget {
  const RunRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RunningProvider(),
      child: MaterialApp(
        title: 'RunRight',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.primaryDark,
          ),
        ),
        // ── 로그인 상태에 따라 화면 분기 ──────────────────
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (snapshot.data == null) {
              return const LoginScreen();
            }
            // 로그인 된 상태 → DB 프로필 조회 후 분기
            return _ProfileLoader(user: snapshot.data!);
          },
        ),
      ),
    );
  }
}

// ── 로그인 후 프로필 유무에 따라 화면 분기 ──────────────────────
class _ProfileLoader extends StatefulWidget {
  final User user;
  const _ProfileLoader({required this.user});

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  bool   _initialized = false;
  bool   _loadFailed  = false;
  String _userName    = '러너';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loadFailed = false; });
    try {
      final uid      = widget.user.uid;
      final provider = Provider.of<RunningProvider>(context, listen: false);
      if (provider.profile == null) {
        await provider.loadProfile(uid)
            .timeout(const Duration(seconds: 15));
      }
      _userName = provider.profile?.name
          ?? provider.pendingName
          ?? FirebaseAuth.instance.currentUser?.displayName
          ?? '러너';
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textHint, size: 48),
              const SizedBox(height: 16),
              const Text('서버 연결에 실패했습니다.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('네트워크 상태를 확인하고 다시 시도해주세요.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black),
                onPressed: _load,
                child: const Text('재시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final profile = context.watch<RunningProvider>().profile;
    if (profile != null) return const MainScreen();
    return BodySetupScreen(
      uid:  widget.user.uid,
      name: _userName,
    );
  }
}
