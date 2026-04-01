// lib/main.dart
// ── Firebase 연동 완료 버전 ──────────────────────────
// 변경 사항:
//   1. Firebase 초기화 추가
//   2. 로그인 상태에 따라 LoginScreen / BodySetupScreen 분기

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';           // flutterfire configure 로 자동 생성
import 'core/constants.dart';
import 'services/running_provider.dart';
import 'screens/login_screen.dart';
import 'screens/body_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
            // 로딩 중
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            // 로그인 안 된 상태 → 로그인 화면
            if (snapshot.data == null) {
              return const LoginScreen();
            }
            // 로그인 된 상태 → 신체 데이터 입력 화면
            return BodySetupScreen(
              uid:  snapshot.data!.uid,
              name: snapshot.data!.displayName ?? '러너',
            );
          },
        ),
      ),
    );
  }
}
