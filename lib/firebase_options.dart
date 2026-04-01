// lib/firebase_options.dart
// FlutterFire CLI 대신 수동으로 생성한 Firebase 설정 파일
// ⚠️ 이 파일은 GitHub에 올리지 마세요 (.gitignore에 포함되어 있음)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS는 아직 설정되지 않았습니다.',
        );
      default:
        throw UnsupportedError(
          '이 플랫폼은 지원하지 않습니다.',
        );
    }
  }

  // ── Android 설정 ──────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBVc6IAQhcLNUyqDXhfIU6HM32oGjZgK_o',
    appId:             '1:221745858454:android:0f25675b78cca7697cbfb7',
    messagingSenderId: '221745858454',
    projectId:         'runright-bde12',
    storageBucket:     'runright-bde12.firebasestorage.app',
    databaseURL:       'https://runright-bde12-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // ── Web 설정 (추후 필요 시 사용) ──────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyBVc6IAQhcLNUyqDXhfIU6HM32oGjZgK_o',
    appId:             '1:221745858454:android:0f25675b78cca7697cbfb7',
    messagingSenderId: '221745858454',
    projectId:         'runright-bde12',
    storageBucket:     'runright-bde12.firebasestorage.app',
    databaseURL:       'https://runright-bde12-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
