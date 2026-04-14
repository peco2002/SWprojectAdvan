// lib/main.dart
// ── Firebase 연동 완료 버전 ──────────────────────────
// 변경 사항:
//   1. Firebase 초기화 추가
//   2. 로그인 상태에 따라 LoginScreen / BodySetupScreen 분기

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/constants.dart';
import 'services/running_provider.dart';
import 'screens/login_screen.dart';
import 'screens/body_setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
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
  String _userName    = '러너';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid      = widget.user.uid;
    final provider = Provider.of<RunningProvider>(context, listen: false);
    if (provider.profile == null) {
      await provider.loadProfile(uid);
    }
    // 이름 우선순위: 저장된 프로필 > DB userName > Firebase Auth displayName
    _userName = provider.profile?.name
        ?? provider.pendingName
        ?? FirebaseAuth.instance.currentUser?.displayName
        ?? '러너';
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final profile = context.watch<RunningProvider>().profile;
    if (profile != null) return const HomeScreen();
    return BodySetupScreen(
      uid:  widget.user.uid,
      name: _userName,
    );
  }
}
