// lib/firebase_options.dart
// ══════════════════════════════════════════════════
// Firebase 설정 — 환경 변수 기반 (하드코딩 없음)
//
// [실행 방법]
//   flutter run --dart-define-from-file=.env.json
//   flutter build apk --dart-define-from-file=.env.json
//
// [설정 방법]
//   1. 프로젝트 루트의 .env.json.example 을 복사해서 .env.json 으로 저장
//   2. Firebase 콘솔(console.firebase.google.com)에서 발급받은 값으로 채우기
//   3. .env.json 은 .gitignore 에 포함되어 있으므로 git에 올라가지 않음
// ══════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: 지원하지 않는 플랫폼입니다.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    appId:             String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId:         String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket:     String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    databaseURL:       String.fromEnvironment('FIREBASE_DATABASE_URL'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId:             String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId:         String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket:     String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    databaseURL:       String.fromEnvironment('FIREBASE_DATABASE_URL'),
    iosBundleId:       String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    appId:             String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId:         String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket:     String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    databaseURL:       String.fromEnvironment('FIREBASE_DATABASE_URL'),
  );
}
