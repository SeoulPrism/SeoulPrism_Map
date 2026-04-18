import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 서울 좌표
const double _seoulLat = 37.5665;
const double _seoulLng = 126.9780;

/// 날씨 상태
enum WeatherCondition {
  clear,    // 맑음
  cloudy,   // 흐림
  rain,     // 비
  snow,     // 눈
  fog,      // 안개
  drizzle,  // 이슬비
  thunderstorm, // 뇌우
}

/// 시간대
enum DayPhase {
  night,  // 밤
  dawn,   // 새벽/일출
  day,    // 낮
  dusk,   // 황혼/일몰
}

/// 환경 데이터 (시간 + 날씨)
class EnvironmentData {
  final DayPhase timeOfDay;
  final String lightPreset; // Mapbox: day, night, dawn, dusk
  final WeatherCondition weather;
  final double temperature; // 섭씨
  final double cloudCover;  // 0~100%
  final double visibility;  // km
  final double windSpeed;   // km/h
  final double precipitation; // mm
  final String weatherDescription;
  final IconData weatherIcon;
  final DateTime sunrise;
  final DateTime sunset;

  const EnvironmentData({
    required this.timeOfDay,
    required this.lightPreset,
    required this.weather,
    required this.temperature,
    required this.cloudCover,
    required this.visibility,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.sunrise,
    required this.sunset,
  });
}

/// 실시간 환경 서비스 (시간 + 날씨)
/// - 서울 일출/일몰 자동 계산 (SunCalc 알고리즘)
/// - Open-Meteo API로 실시간 날씨 (무료, API 키 불필요)
class EnvironmentService {
  Timer? _timer;
  EnvironmentData? _current;
  VoidCallback? onUpdated;

  EnvironmentData? get current => _current;

  /// 서비스 시작 (즉시 1회 + 5분 주기)
  Future<void> start() async {
    await _update();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _update());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  Future<void> _update() async {
    final now = DateTime.now();
    final sunrise = _calcSunrise(now, _seoulLat, _seoulLng);
    final sunset = _calcSunset(now, _seoulLat, _seoulLng);
    final tod = _getDayPhase(now, sunrise, sunset);
    final lightPreset = _toLightPreset(tod);

    // 날씨 데이터 fetch
    WeatherCondition weather = WeatherCondition.clear;
    double temp = 20.0;
    double cloud = 0.0;
    double vis = 10.0;
    double wind = 0.0;
    double precip = 0.0;
    String desc = '맑음';
    IconData icon = Icons.wb_sunny;

    try {
      final weatherData = await _fetchWeather();
      if (weatherData != null) {
        weather = weatherData['condition'] as WeatherCondition;
        temp = weatherData['temperature'] as double;
        cloud = weatherData['cloudCover'] as double;
        vis = weatherData['visibility'] as double;
        wind = weatherData['windSpeed'] as double;
        precip = weatherData['precipitation'] as double;
        desc = weatherData['description'] as String;
        icon = weatherData['icon'] as IconData;
      }
    } catch (e) {
      debugPrint('[EnvironmentService] 날씨 fetch 실패: $e');
    }

    _current = EnvironmentData(
      timeOfDay: tod,
      lightPreset: lightPreset,
      weather: weather,
      temperature: temp,
      cloudCover: cloud,
      visibility: vis,
      windSpeed: wind,
      precipitation: precip,
      weatherDescription: desc,
      weatherIcon: icon,
      sunrise: sunrise,
      sunset: sunset,
    );

    onUpdated?.call();
  }

  // ── 일출/일몰 계산 (간이 SunCalc) ──

  static DateTime _calcSunrise(DateTime date, double lat, double lng) {
    return _calcSunEvent(date, lat, lng, isSunrise: true);
  }

  static DateTime _calcSunset(DateTime date, double lat, double lng) {
    return _calcSunEvent(date, lat, lng, isSunrise: false);
  }

  static DateTime _calcSunEvent(DateTime date, double lat, double lng, {required bool isSunrise}) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final zenith = 90.833; // 공식 일출/일몰 천정각

    // 시간 근사 (6=일출, 18=일몰)
    final approxTime = dayOfYear + ((isSunrise ? 6 : 18) - lng / 15) / 24;

    // 태양 평균 이상 (anomaly)
    final meanAnomaly = 0.9856 * approxTime - 3.289;
    final meanAnomalyRad = meanAnomaly * pi / 180;

    // 태양 경도
    var sunLng = meanAnomaly + 1.916 * sin(meanAnomalyRad) +
        0.020 * sin(2 * meanAnomalyRad) + 282.634;
    sunLng = sunLng % 360;
    final sunLngRad = sunLng * pi / 180;

    // 적경 (RA)
    var ra = atan(0.91764 * tan(sunLngRad)) * 180 / pi;
    final lQuadrant = (sunLng / 90).floor() * 90;
    final raQuadrant = (ra / 90).floor() * 90;
    ra += lQuadrant - raQuadrant;
    ra /= 15; // 시간으로 변환

    // 적위 (Declination)
    final sinDec = 0.39782 * sin(sunLngRad);
    final cosDec = cos(asin(sinDec));

    // 시간각
    final latRad = lat * pi / 180;
    final zenithRad = zenith * pi / 180;
    final cosH = (cos(zenithRad) - sinDec * sin(latRad)) / (cosDec * cos(latRad));

    if (cosH > 1 || cosH < -1) {
      // 극야/백야 — 기본값 반환
      return DateTime(date.year, date.month, date.day, isSunrise ? 6 : 18);
    }

    double h;
    if (isSunrise) {
      h = (360 - acos(cosH) * 180 / pi) / 15;
    } else {
      h = acos(cosH) * 180 / pi / 15;
    }

    final localTime = h + ra - 0.06571 * approxTime - 6.622;
    var utcTime = localTime - lng / 15;
    utcTime = utcTime % 24;

    // UTC → KST (+9)
    var kstTime = utcTime + 9;
    kstTime = kstTime % 24;

    final hour = kstTime.floor();
    final minute = ((kstTime - hour) * 60).round();

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// 현재 시간 → DayPhase
  static DayPhase _getDayPhase(DateTime now, DateTime sunrise, DateTime sunset) {
    final dawnStart = sunrise.subtract(const Duration(minutes: 30));
    final dawnEnd = sunrise.add(const Duration(minutes: 30));
    final duskStart = sunset.subtract(const Duration(minutes: 30));
    final duskEnd = sunset.add(const Duration(minutes: 30));

    if (now.isAfter(dawnStart) && now.isBefore(dawnEnd)) return DayPhase.dawn;
    if (now.isAfter(dawnEnd) && now.isBefore(duskStart)) return DayPhase.day;
    if (now.isAfter(duskStart) && now.isBefore(duskEnd)) return DayPhase.dusk;
    return DayPhase.night;
  }

  static String _toLightPreset(DayPhase tod) {
    switch (tod) {
      case DayPhase.dawn: return 'dawn';
      case DayPhase.day: return 'day';
      case DayPhase.dusk: return 'dusk';
      case DayPhase.night: return 'night';
    }
  }

  // ── Open-Meteo API ──

  Future<Map<String, dynamic>?> _fetchWeather() async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$_seoulLat&longitude=$_seoulLng'
      '&current=temperature_2m,weather_code,cloud_cover,visibility,wind_speed_10m,precipitation'
      '&timezone=Asia/Seoul',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    final current = json['current'];
    if (current == null) return null;

    final code = current['weather_code'] as int? ?? 0;
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 20.0;
    final cloud = (current['cloud_cover'] as num?)?.toDouble() ?? 0.0;
    final vis = ((current['visibility'] as num?)?.toDouble() ?? 10000.0) / 1000.0; // m → km
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
    final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;

    final parsed = _parseWeatherCode(code);
    return {
      'condition': parsed['condition'],
      'description': parsed['description'],
      'icon': parsed['icon'],
      'temperature': temp,
      'cloudCover': cloud,
      'visibility': vis,
      'windSpeed': wind,
      'precipitation': precip,
    };
  }

  /// WMO weather code → 상태/설명/아이콘
  static Map<String, dynamic> _parseWeatherCode(int code) {
    if (code == 0) {
      return {'condition': WeatherCondition.clear, 'description': '맑음', 'icon': Icons.wb_sunny};
    } else if (code <= 3) {
      return {'condition': WeatherCondition.cloudy, 'description': code == 1 ? '대체로 맑음' : code == 2 ? '구름 조금' : '흐림', 'icon': Icons.cloud};
    } else if (code <= 49) {
      return {'condition': WeatherCondition.fog, 'description': '안개', 'icon': Icons.foggy};
    } else if (code <= 59) {
      return {'condition': WeatherCondition.drizzle, 'description': '이슬비', 'icon': Icons.grain};
    } else if (code <= 69) {
      return {'condition': WeatherCondition.rain, 'description': '비', 'icon': Icons.water_drop};
    } else if (code <= 79) {
      return {'condition': WeatherCondition.snow, 'description': '눈', 'icon': Icons.ac_unit};
    } else if (code <= 84) {
      return {'condition': WeatherCondition.rain, 'description': '소나기', 'icon': Icons.thunderstorm};
    } else if (code <= 86) {
      return {'condition': WeatherCondition.snow, 'description': '눈보라', 'icon': Icons.ac_unit};
    } else if (code <= 99) {
      return {'condition': WeatherCondition.thunderstorm, 'description': '뇌우', 'icon': Icons.flash_on};
    }
    return {'condition': WeatherCondition.clear, 'description': '맑음', 'icon': Icons.wb_sunny};
  }
}
