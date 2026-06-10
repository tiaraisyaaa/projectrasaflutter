import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class EnvironmentService {
  final StorageService _storageService = StorageService();

  Map<String, dynamic> _safeDecodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'message': 'Response API kosong. Status code: ${response.statusCode}',
      };
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'message': 'Response API bukan Map JSON.',
        'data': decoded,
      };
    } catch (_) {
      return {
        'message':
            'Response API bukan JSON. Status code: ${response.statusCode}. Body: ${response.body}',
      };
    }
  }

  Future<Map<String, dynamic>> createEnvironmentRecord({
    required double temperature,
    required double humidity,
    required String airQuality,
    required String riskLevel,
    required double latitude,
    required double longitude,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': null,
      };
    }

    final requestBody = {
      'temperature': temperature,
      'humidity': humidity,
      'airQuality': airQuality,
      'riskLevel': riskLevel,
      'latitude': latitude,
      'longitude': longitude,
    };

    final url = Uri.parse(ApiConfig.createEnvironmentRecord);

    print('POST ENV URL: $url');
    print('POST ENV BODY: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('POST ENV STATUS: ${response.statusCode}');
      print('POST ENV RESPONSE: ${response.body}');

      final responseBody = _safeDecodeResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message':
              responseBody['message'] ?? 'Data lingkungan berhasil dikirim',
          'data': responseBody['data'] ??
              responseBody['environment'] ??
              responseBody,
        };
      }

      return {
        'success': false,
        'message':
            responseBody['message'] ?? 'Gagal mengirim data lingkungan',
        'data': responseBody,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal menghubungi server: $e',
        'data': null,
      };
    }
  }


  Future<Map<String, dynamic>?> getLatestEnvironmentForSelf() async {
  final token = await _storageService.getToken();
  if (token == null || token.isEmpty) return null;

  final url = Uri.parse(ApiConfig.latestEnvironment('self')); // backend harus support self
  try {
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode != 200 || response.body.isEmpty) return null;
    final data = jsonDecode(response.body);
    return data['environment'] ?? data['data'] ?? data;
  } catch (e) {
    print('Error getLatestEnvironmentForSelf: $e');
    return null;
  }
}



  Future<Map<String, dynamic>?> getLatestEnvironment(String elderlyId) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    final url = Uri.parse(ApiConfig.latestEnvironment(elderlyId));

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET ENV STATUS: ${response.statusCode}');
      print('GET ENV RESPONSE: ${response.body}');

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      final data = jsonDecode(response.body);

      return data['environment'] ?? data['data'] ?? data;
    } catch (e) {
      print('Error getLatestEnvironment: $e');
      return null;
    }
  }
}