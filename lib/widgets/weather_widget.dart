import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import '../services/environment_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// 지도 위 날씨/시간 위젯 (리퀴드 글라스, 완전 세로 배치)
class WeatherTimeWidget extends StatelessWidget {
  final EnvironmentData? environment;

  const WeatherTimeWidget({super.key, this.environment});

  @override
  Widget build(BuildContext context) {
    final env = environment;
    if (env == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final timeIcon = switch (env.timeOfDay) {
      DayPhase.dawn => Icons.wb_twilight,
      DayPhase.day => Icons.wb_sunny,
      DayPhase.dusk => Icons.wb_twilight,
      DayPhase.night => Icons.nights_stay,
    };

    final weatherColor = switch (env.weather) {
      WeatherCondition.clear => AppColors.weatherClear,
      WeatherCondition.cloudy => AppColors.weatherCloudy,
      WeatherCondition.rain => AppColors.weatherRain,
      WeatherCondition.drizzle => AppColors.weatherDrizzle,
      WeatherCondition.snow => AppColors.weatherSnow,
      WeatherCondition.fog => AppColors.weatherFog,
      WeatherCondition.thunderstorm => AppColors.weatherThunder,
    };

    const shadow = [Shadow(blurRadius: 4, color: Colors.black54)];

    return Semantics(
      label: '현재 시간 $timeStr, 기온 ${env.temperature.toStringAsFixed(0)}도',
      child: LiquidGlassContainer(
        config: const LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.capsule,
          interactive: false,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(timeIcon, size: 18, color: AppColors.weatherTimeIcon),
              const SizedBox(height: AppSpacing.xs),
              Text(timeStr, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.weatherTimeText, shadows: shadow)),
              const SizedBox(height: AppSpacing.sm),
              Icon(env.weatherIcon, size: 18, color: weatherColor),
              const SizedBox(height: AppSpacing.xs),
              Text('${env.temperature.toStringAsFixed(0)}°', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: weatherColor, shadows: shadow)),
            ],
          ),
        ),
      ),
    );
  }
}
