import 'package:flutter/material.dart';
import '../services/environment_service.dart';

/// 지도 위 날씨/시간 표시 위젯
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
      WeatherCondition.clear => Colors.amberAccent,
      WeatherCondition.cloudy => Colors.grey,
      WeatherCondition.rain => Colors.lightBlueAccent,
      WeatherCondition.drizzle => Colors.lightBlue,
      WeatherCondition.snow => Colors.white,
      WeatherCondition.fog => Colors.blueGrey,
      WeatherCondition.thunderstorm => Colors.deepPurpleAccent,
    };

    return Card(
      color: Colors.black.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(timeIcon, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(timeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 8),
            Icon(env.weatherIcon, size: 14, color: weatherColor),
            const SizedBox(width: 4),
            Text(
              '${env.temperature.toStringAsFixed(0)}°',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Text(
              env.weatherDescription,
              style: TextStyle(fontSize: 10, color: weatherColor),
            ),
          ],
        ),
      ),
    );
  }
}
