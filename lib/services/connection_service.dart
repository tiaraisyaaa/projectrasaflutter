import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class ConnectionService {
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

  Future<Map<String, dynamic>> sendConnectionRequest({
    required String familyEmail,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    final url = Uri.parse(ApiConfig.createConnection);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'familyEmail': familyEmail.trim().toLowerCase(),
      }),
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Permintaan berhasil dikirim',
        'data': responseBody,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengirim permintaan',
    };
  }

  Future<Map<String, dynamic>> getIncomingConnections() async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': [],
      };
    }

    final url = Uri.parse(ApiConfig.incomingConnections);

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
        'message': responseBody['message'] ?? 'Data berhasil diambil',
        'data': responseBody['connections'] ??
            responseBody['data'] ??
            responseBody['requests'] ??
            [],
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengambil permintaan',
      'data': [],
    };
  }

  Future<Map<String, dynamic>> updateConnectionStatus({
    required String connectionId,
    required String status,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    final url = Uri.parse(ApiConfig.updateConnection(connectionId));

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': status,
      }),
    );

    final responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'Status koneksi berhasil diubah',
        'data': responseBody,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal mengubah status koneksi',
    };
  }

  Future<Map<String, dynamic>> getConnectedFamilies() async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': [],
      };
    }

    final url = Uri.parse(ApiConfig.connectedFamilies);

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
        'message': responseBody['message'] ?? 'Data keluarga berhasil diambil',
        'data': responseBody['families'] ??
            responseBody['connections'] ??
            responseBody['data'] ??
            [],
      };
    }

    return {
      'success': false,
      'message':
          responseBody['message'] ?? 'Gagal mengambil keluarga terhubung',
      'data': [],
    };
  }

  Future<Map<String, dynamic>> getConnectedElderlies() async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
        'data': [],
      };
    }

    final url = Uri.parse(ApiConfig.connectedElderlies);

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
        'message': responseBody['message'] ?? 'Data lansia berhasil diambil',
        'data': responseBody['elderlies'] ??
            responseBody['connections'] ??
            responseBody['data'] ??
            [],
      };
    }

    return {
      'success': false,
      'message':
          responseBody['message'] ?? 'Gagal mengambil lansia terhubung',
      'data': [],
    };
  }
}