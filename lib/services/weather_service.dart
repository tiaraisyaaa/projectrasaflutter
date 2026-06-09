import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<Map<String, dynamic>?> getWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat'
        '&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m',
      );

      final response = await http.get(url);

      print('GET WEATHER STATUS: ${response.statusCode}');
      print('GET WEATHER BODY: ${response.body}');

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      final data = jsonDecode(response.body);
      final current = data['current'];

      if (current == null) {
        return null;
      }

      return {
        'temperature': current['temperature_2m'] ?? 0,
        'humidity': current['relative_humidity_2m'] ?? 0,
        'windspeed': current['wind_speed_10m'] ?? 0,
        'winddirection': current['wind_direction_10m'] ?? 0,
      };
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }
}