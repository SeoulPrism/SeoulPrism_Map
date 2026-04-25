import 'package:flutter/material.dart';

/// 앱 전역 색상 토큰
/// 하드코딩된 색상 대신 이 클래스를 참조
abstract final class AppColors {
  // ── Surface ──
  static const surface = Color(0xFF0a0a1a);
  static const surfaceCard = Color(0xFF1A1A2E);
  static const surfaceOverlay = Colors.white10;

  // ── Glass ──
  static const glassTint = Colors.white;
  static const double glassTintOpacity = 0.12;
  static const double glassBorderOpacity = 0.20;
  static const double glassDropOpacity = 0.35;

  // ── Text ──
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textTertiary = Color(0x99FFFFFF); // white60
  static const textDisabled = Color(0x73FFFFFF); // white45
  static const textMuted = Color(0x66FFFFFF);    // white40

  // ── Accent ──
  static const accent = Colors.blueAccent;
  static const success = Colors.greenAccent;
  static const warning = Colors.orangeAccent;
  static const danger = Colors.redAccent;

  // ── Divider ──
  static const divider = Colors.white12;
  static const borderSubtle = Colors.white24;

  // ── Weather ──
  static const weatherClear = Colors.amberAccent;
  static const weatherCloudy = Color(0xFFB0BEC5);
  static const weatherRain = Colors.lightBlueAccent;
  static const weatherDrizzle = Colors.lightBlue;
  static const weatherSnow = Color(0xFFE0E0E0);
  static const weatherFog = Color(0xFF90A4AE);
  static const weatherThunder = Colors.deepPurpleAccent;
  static const weatherTimeIcon = Color(0xFFE0E0E0);
  static const weatherTimeText = Color(0xFFF5F5F5);
}
