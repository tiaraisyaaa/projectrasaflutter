import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class AlertService {
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

      return {'data': decoded};
    } catch (_) {
      return {
        'message':
            'Response API bukan JSON. Status code: ${response.statusCode}. Body: ${response.body}',
      };
    }
  }

  Future<Map<String, dynamic>> createAlert({
    required String alertType,
    required String message,
    required String riskLevel,
    double latitude = 0,
    double longitude = 0,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    final url = Uri.parse(ApiConfig.createAlert);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'alertType': alertType,
        'message': message,
        'riskLevel': riskLevel,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Alert berhasil dikirim',
        'data': responseBody,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengirim alert',
    };
  }

  Future<Map<String, dynamic>> getElderlyAlerts({
    required String elderlyId,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': [],
      };
    }

    final url = Uri.parse(ApiConfig.elderlyAlerts(elderlyId));

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Alert berhasil diambil',
        'data':
            responseBody['alerts'] ??
            responseBody['data'] ??
            responseBody['notifications'] ??
            [],
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengambil alert',
      'data': [],
    };
  }

  Future<Map<String, dynamic>> deleteAlertHistory({
    required String alertId,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    if (alertId.trim().isEmpty) {
      return {'success': false, 'message': 'ID notifikasi tidak ditemukan.'};
    }

    final url = Uri.parse(ApiConfig.deleteAlertHistory(alertId.trim()));

    final response = await http.delete(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'message':
            responseBody['message'] ?? 'Riwayat notifikasi berhasil dihapus',
        'deleted_alert_id':
            responseBody['deleted_alert_id']?.toString() ?? alertId.trim(),
        'data': responseBody,
      };
    }

    return {
      'success': false,
      'message':
          responseBody['message'] ?? 'Gagal menghapus riwayat notifikasi',
      'statusCode': response.statusCode,
      'data': responseBody,
    };
  }
}
