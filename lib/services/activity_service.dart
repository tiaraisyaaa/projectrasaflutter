import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class ActivityService {
  final StorageService _storageService = StorageService();

  Map<String, dynamic> _safeDecodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'message': 'Response API kosong. Status code: ${response.statusCode}',
      };
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'message':
            'Response API bukan JSON. Status code: ${response.statusCode}. Body: ${response.body}',
      };
    }
  }

  Future<Map<String, dynamic>> createActivity({
    required double xAxis,
    required double yAxis,
    required double zAxis,
    required double accelerationValue,
    required String activityStatus,
    required String riskLevel,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    final url = Uri.parse(ApiConfig.createActivity);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'xAxis': xAxis,
        'yAxis': yAxis,
        'zAxis': zAxis,
        'accelerationValue': accelerationValue,
        'activityStatus': activityStatus,
        'riskLevel': riskLevel,
      }),
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Aktivitas berhasil dikirim',
        'data': responseBody,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengirim aktivitas',
    };
  }

  Future<Map<String, dynamic>> getLatestActivity({
    required String elderlyId,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': null,
      };
    }

    final url = Uri.parse(ApiConfig.latestActivity(elderlyId));

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Aktivitas terakhir berhasil diambil',
        'data': responseBody['activity'] ??
            responseBody['latestActivity'] ??
            responseBody['data'] ??
            responseBody,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengambil aktivitas terakhir',
      'data': null,
    };
  }
}