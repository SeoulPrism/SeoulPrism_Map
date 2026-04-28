import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// 앱 글로벌 ThemeData (Roboto + 다크 테마)
abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: AppColors.accent,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: AppTypography.textTheme,
    cardColor: AppColors.surfaceCard,
    dividerColor: AppColors.divider,
  );
}
