// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'services/running_provider.dart';
import 'screens/body_setup_screen.dart';

// ── Firebase 초기화 (팀원3·4 연동 시 주석 해제) ──────────────────
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        // ────────────────────────────────────────────────────────
        // 현재: 신체 데이터 입력 화면 바로 시작 (로그인 없이 테스트)
        //
        // 팀원3 (Firebase Auth) 연동 후 아래처럼 교체:
        //
        // home: StreamBuilder<User?>(
        //   stream: FirebaseAuth.instance.authStateChanges(),
        //   builder: (ctx, snap) {
        //     if (snap.connectionState == ConnectionState.waiting)
        //       return const SplashScreen();
        //     if (snap.data == null)
        //       return const LoginScreen();          // 팀원3 구현
        //     return BodySetupScreen(
        //       uid:  snap.data!.uid,
        //       name: snap.data!.displayName ?? '러너',
        //     );
        //   },
        // ),
        // ────────────────────────────────────────────────────────
        home: const BodySetupScreen(uid: 'test_uid', name: '러너'),
      ),
    );
  }
}
