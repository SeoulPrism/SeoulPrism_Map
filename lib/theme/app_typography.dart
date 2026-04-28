import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 앱 전역 타이포그래피 토큰 (Roboto 기반, 5단계 스케일)
abstract final class AppTypography {
  /// 대제목 — 경로 총 시간, 메인 타이틀
  static final displayLg = GoogleFonts.roboto(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 패널 제목, 역명, 노선명
  static final titleMd = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 본문, 검색 입력, 일반 텍스트
  static final bodyMd = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// 라벨, 부가 정보, 설명
  static final bodySm = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// 배지, 메타데이터, 캡션
  static final caption = GoogleFonts.roboto(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
  );

  /// Roboto TextTheme (ThemeData에 적용용)
  static TextTheme get textTheme => GoogleFonts.robotoTextTheme(
    const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary),
      displayMedium: TextStyle(color: AppColors.textPrimary),
      displaySmall: TextStyle(color: AppColors.textPrimary),
      headlineLarge: TextStyle(color: AppColors.textPrimary),
      headlineMedium: TextStyle(color: AppColors.textPrimary),
      headlineSmall: TextStyle(color: AppColors.textPrimary),
      titleLarge: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      titleSmall: TextStyle(color: AppColors.textPrimary),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textSecondary),
      bodySmall: TextStyle(color: AppColors.textTertiary),
      labelLarge: TextStyle(color: AppColors.textPrimary),
      labelMedium: TextStyle(color: AppColors.textSecondary),
      labelSmall: TextStyle(color: AppColors.textTertiary),
    ),
  );
}
