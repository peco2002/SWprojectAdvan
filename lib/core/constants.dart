// lib/core/constants.dart
// 앱 전체에서 쓰는 색상·공통 상수

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background   = Color(0xFF0D0D0D);
  static const surface      = Color(0xFF1A1A1A);
  static const card         = Color(0xFF222222);
  static const primary      = Color(0xFF2ECC71); // 초록
  static const primaryDark  = Color(0xFF27AE60);
  static const accent       = Color(0xFF58D68D);

  static const tooFast  = Color(0xFFE74C3C); // 빨강
  static const good     = Color(0xFF2ECC71); // 초록
  static const tooSlow  = Color(0xFFF39C12); // 주황
  static const stopped  = Color(0xFF555555); // 회색

  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFFAAAAAA);
  static const textHint      = Color(0xFF555555);
  static const divider       = Color(0xFF2A2A2A);
}

class AppTextStyles {
  AppTextStyles._();

  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  static const subheading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
  );
  static const caption = TextStyle(
    color: AppColors.textHint,
    fontSize: 12,
  );
  static const paceHero = TextStyle(
    color: AppColors.primary,
    fontSize: 64,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    height: 1,
  );
}
