import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 맵 배경을 실시간 반영하는 글라스 효과 컨테이너
/// BackdropFilter 기반이라 맵 라이팅(낮/밤/새벽/저녁) 변경에도 자연스럽게 반응
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool capsule;        // true면 완전 둥근 캡슐
  final double blur;
  final Color tint;
  final double tintOpacity;
  final double borderOpacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.capsule = false,
    this.blur = 20,
    this.tint = AppColors.glassTint,
    this.tintOpacity = AppColors.glassTintOpacity,
    this.borderOpacity = AppColors.glassBorderOpacity,
  });

  /// 캡슐 프리셋
  const GlassContainer.capsule({
    super.key,
    required this.child,
    this.blur = 20,
    this.tint = AppColors.glassTint,
    this.tintOpacity = AppColors.glassTintOpacity,
    this.borderOpacity = AppColors.glassBorderOpacity,
  })  : capsule = true,
        borderRadius = 999;

  /// 둥근 사각형 프리셋
  const GlassContainer.rounded({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 20,
    this.tint = AppColors.glassTint,
    this.tintOpacity = AppColors.glassTintOpacity,
    this.borderOpacity = AppColors.glassBorderOpacity,
  }) : capsule = false;

  @override
  Widget build(BuildContext context) {
    final radius = capsule ? BorderRadius.circular(999) : BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
