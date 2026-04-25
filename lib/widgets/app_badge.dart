import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// 재사용 가능한 컬러 배지 (상태 표시, 라벨, 태그 등)
///
/// 사용 예:
/// ```dart
/// AppBadge(text: '3분 지연', color: AppColors.danger)
/// AppBadge.outlined(text: 'DEMO', color: AppColors.warning)
/// AppBadge.filled(text: '1호선', color: lineColor)
/// ```
class AppBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  final bool hasBorder;
  final double? fontSize;
  final FontWeight? fontWeight;

  /// 반투명 배경 + 테두리 (기본)
  const AppBadge({
    super.key,
    required this.text,
    required this.color,
    this.fontSize,
    this.fontWeight,
  })  : filled = false,
        hasBorder = true;

  /// 테두리만 (배경 투명)
  const AppBadge.outlined({
    super.key,
    required this.text,
    required this.color,
    this.fontSize,
    this.fontWeight,
  })  : filled = false,
        hasBorder = true;

  /// 꽉 찬 배경색 (흰색 텍스트)
  const AppBadge.filled({
    super.key,
    required this.text,
    required this.color,
    this.fontSize,
    this.fontWeight,
  })  : filled = true,
        hasBorder = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: hasBorder && !filled
            ? Border.all(color: color.withValues(alpha: 0.5), width: 0.5)
            : null,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: filled ? AppColors.textPrimary : color,
          fontWeight: fontWeight ?? FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// 재사용 가능한 선택형 칩 (노선 필터, 타입 탭 등)
///
/// 사용 예:
/// ```dart
/// AppFilterChip(
///   label: '1호선',
///   color: lineColor,
///   isSelected: true,
///   onTap: () {},
/// )
/// ```
class AppFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? color : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 아이콘 원형 버튼 (닫기, 스왑, 전원 등)
/// Semantics 라벨 내장
class AppCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? borderColor;
  final String semanticLabel;

  const AppCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 32,
    this.iconSize = 16,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? Colors.white10,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
          child: Icon(icon, size: iconSize, color: borderColor ?? AppColors.textTertiary),
        ),
      ),
    );
  }
}
