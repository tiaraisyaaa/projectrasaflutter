import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class WeatherService {
  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _calculateAqi({
    required double concentration,
    required double cLow,
    required double cHigh,
    required int iLow,
    required int iHigh,
  }) {
    final double aqi =
        ((iHigh - iLow) / (cHigh - cLow)) * (concentration - cLow) + iLow;

    return aqi.round().clamp(0, 500);
  }

  int _aqiFromBreakpoints({
    required double concentration,
    required List<Map<String, dynamic>> breakpoints,
  }) {
    for (final bp in breakpoints) {
      final double cLow = bp['cLow'];
      final double cHigh = bp['cHigh'];

      if (concentration >= cLow && concentration <= cHigh) {
        return _calculateAqi(
          concentration: concentration,
          cLow: cLow,
          cHigh: cHigh,
          iLow: bp['iLow'],
          iHigh: bp['iHigh'],
        );
      }
    }

    return 500;
  }

  int _calculatePm25Aqi(double pm25Raw) {
    final double pm25 = (pm25Raw * 10).floor() / 10;

    return _aqiFromBreakpoints(
      concentration: pm25,
      breakpoints: [
        {'cLow': 0.0, 'cHigh': 9.0, 'iLow': 0, 'iHigh': 50},
        {'cLow': 9.1, 'cHigh': 35.4, 'iLow': 51, 'iHigh': 100},
        {'cLow': 35.5, 'cHigh': 55.4, 'iLow': 101, 'iHigh': 150},
        {'cLow': 55.5, 'cHigh': 125.4, 'iLow': 151, 'iHigh': 200},
        {'cLow': 125.5, 'cHigh': 225.4, 'iLow': 201, 'iHigh': 300},
        {'cLow': 225.5, 'cHigh': 325.4, 'iLow': 301, 'iHigh': 500},
      ],
    );
  }

  int _calculatePm10Aqi(double pm10Raw) {
    final double pm10 = pm10Raw.floorToDouble();

    return _aqiFromBreakpoints(
      concentration: pm10,
      breakpoints: [
        {'cLow': 0.0, 'cHigh': 54.0, 'iLow': 0, 'iHigh': 50},
        {'cLow': 55.0, 'cHigh': 154.0, 'iLow': 51, 'iHigh': 100},
        {'cLow': 155.0, 'cHigh': 254.0, 'iLow': 101, 'iHigh': 150},
        {'cLow': 255.0, 'cHigh': 354.0, 'iLow': 151, 'iHigh': 200},
        {'cLow': 355.0, 'cHigh': 424.0, 'iLow': 201, 'iHigh': 300},
        {'cLow': 425.0, 'cHigh': 604.0, 'iLow': 301, 'iHigh': 500},
      ],
    );
  }

  String getAirQualityFromAqi(int aqi) {
    if (aqi <= 50) {
      return 'baik';
    }

    if (aqi <= 100) {
      return 'sedang';
    }

    return 'buruk';
  }

  String getRiskLevelFromAqi(int aqi) {
    if (aqi <= 50) {
      return 'normal';
    }

    if (aqi <= 150) {
      return 'waspada';
    }

    return 'darurat';
  }

  String getAqiCategoryText(int aqi) {
    if (aqi <= 50) {
      return 'bagus';
    }

    if (aqi <= 100) {
      return 'sedang';
    }

    if (aqi <= 150) {
      return 'tidak sehat untuk kelompok rentan';
    }

    if (aqi <= 200) {
      return 'tidak sehat';
    }

    if (aqi <= 300) {
      return 'sangat tidak sehat';
    }

    return 'berbahaya';
  }

  Future<Map<String, dynamic>?> getWeather(double lat, double lng) async {
    try {
      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat'
        '&lon=$lng'
        '&appid=${ApiConfig.apiKey}'
        '&units=metric'
        '&lang=id',
      );

      final airPollutionUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution'
        '?lat=$lat'
        '&lon=$lng'
        '&appid=${ApiConfig.apiKey}',
      );

      final weatherResponse = await http.get(weatherUrl);
      final airPollutionResponse = await http.get(airPollutionUrl);

      debugPrint('GET OPENWEATHER STATUS: ${weatherResponse.statusCode}');
      debugPrint('GET OPENWEATHER BODY: ${weatherResponse.body}');
      debugPrint(
        'GET AIR POLLUTION STATUS: ${airPollutionResponse.statusCode}',
      );
      debugPrint('GET AIR POLLUTION BODY: ${airPollutionResponse.body}');

      if (weatherResponse.statusCode != 200 ||
          weatherResponse.body.isEmpty ||
          airPollutionResponse.statusCode != 200 ||
          airPollutionResponse.body.isEmpty) {
        return null;
      }

      final weatherData = jsonDecode(weatherResponse.body);
      final airPollutionData = jsonDecode(airPollutionResponse.body);

      final main = weatherData['main'];
      final pollutionList = airPollutionData['list'];

      if (main == null ||
          pollutionList == null ||
          pollutionList is! List ||
          pollutionList.isEmpty) {
        return null;
      }

      final pollution = pollutionList.first;

      if (pollution is! Map) {
        return null;
      }

      final components = pollution['components'];

      if (components == null || components is! Map) {
        return null;
      }

      final double pm25 = _toDouble(components['pm2_5']);
      final double pm10 = _toDouble(components['pm10']);

      final int pm25Aqi = _calculatePm25Aqi(pm25);
      final int pm10Aqi = _calculatePm10Aqi(pm10);

      final int aqi = max(pm25Aqi, pm10Aqi);

      final String aqiSource = pm25Aqi >= pm10Aqi ? 'PM2.5' : 'PM10';
      final String airQuality = getAirQualityFromAqi(aqi);
      final String riskLevel = getRiskLevelFromAqi(aqi);
      final String aqiCategory = getAqiCategoryText(aqi);

      return {
        'temperature': _toDouble(main['temp']),
        'humidity': _toDouble(main['humidity']),

        // Angka AQI asli hasil hitung dari PM2.5 / PM10.
        // Ini yang nanti ditampilkan di dashboard, contoh: AQI: 16
        'aqi': aqi,
        'aqiSource': aqiSource,
        'aqiCategory': aqiCategory,

        // Opsional untuk debug/tampilan tambahan.
        'pm25': pm25,
        'pm10': pm10,

        // Ini tetap sesuai database kamu.
        'airQuality': airQuality,
        'riskLevel': riskLevel,
      };
    } catch (e) {
      debugPrint('Error fetching OpenWeather AQI data: $e');
      return null;
    }
  }
}
