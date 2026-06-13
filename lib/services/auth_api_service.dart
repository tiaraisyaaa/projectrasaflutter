import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';
import 'notification_service.dart';

class AuthApiService {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  Map<String, dynamic> _safeDecodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'message':
            'Response API kosong. Status code: ${response.statusCode}. Cek endpoint API di Swagger online.',
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

  String _buildErrorMessage({
    required Map<String, dynamic> responseBody,
    required String defaultMessage,
  }) {
    final detail = responseBody['detail'];
    final inner = responseBody['inner'];

    String errorMessage = responseBody['message'] ?? defaultMessage;

    if (detail != null) {
      errorMessage += '\nDetail: $detail';
    }

    if (inner != null) {
      errorMessage += '\nInner: $inner';
    }

    return errorMessage;
  }

  Future<void> _copyFirebaseIdTokenToClipboard({
    required String label,
    required String idToken,
  }) async {
    if (idToken.isEmpty) {
      print('$label: Firebase ID Token kosong');
      return;
    }

    final String bodyForSwagger = jsonEncode({
      'idToken': idToken,
    });

    await Clipboard.setData(
      ClipboardData(text: bodyForSwagger),
    );

    print('========== $label ==========');
    print('FIREBASE ID TOKEN LANGSUNG:');
    print(idToken);
    print('===START_FIREBASE_ID_TOKEN===');
    print(idToken);
    print('===END_FIREBASE_ID_TOKEN===');
    print('BODY JSON FIREBASE ID TOKEN SUDAH DICOPY KE CLIPBOARD:');
    print(bodyForSwagger);
    print('PASTE KE BODY ENDPOINT LOGIN/REGISTER SWAGGER');
  }

  Future<void> _copyBackendTokenToClipboard({
    required String label,
    required dynamic token,
  }) async {
    final String backendToken = token?.toString() ?? '';

    if (backendToken.isEmpty) {
      print('$label: Token backend kosong');
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: backendToken),
    );

    print('========== $label ==========');
    print('TOKEN API BACKEND LANGSUNG:');
    print(backendToken);
    print('===START_BACKEND_API_TOKEN===');
    print(backendToken);
    print('===END_BACKEND_API_TOKEN===');
    print('TOKEN API BACKEND SUDAH DICOPY KE CLIPBOARD');
    print('PASTE KE AUTHORIZATION -> BEARER TOKEN DI POSTMAN/SWAGGER');
  }

  // Future<void> _saveFcmTokenIfFamily(dynamic user) async {
  //   final role = user['role']?.toString();

  //   if (role != 'keluarga') {
  //     return;
  //   }

  //   final result = await _notificationService.saveFcmTokenToApi();

  //   if (result['success'] == true) {
  //     print('FCM token keluarga berhasil disimpan');
  //   } else {
  //     print('Gagal simpan FCM token: ${result['message']}');
  //   }
  // }

  Future<void> _saveFcmTokenIfFamily(dynamic user) async {
    final role = user['role']?.toString();

    if (role != 'keluarga') {
      return;
    }

    try {
      final result = await _notificationService.saveFcmTokenToApi();

      if (result['success'] == true) {
        print('FCM token keluarga berhasil disimpan');
      } else {
        print('Gagal simpan FCM token: ${result['message']}');
      }
    } catch (e) {
      print('FCM error diabaikan, login tetap lanjut: $e');
    }
  }

  Future<Map<String, dynamic>> registerFirebaseUser({
    required String idToken,
    required String name,
    required String phone,
    required String role,
  }) async {
    final url = Uri.parse(ApiConfig.firebaseRegister);

    await _copyFirebaseIdTokenToClipboard(
      label: 'FIREBASE ID TOKEN REGISTER',
      idToken: idToken,
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
        'name': name,
        'phone': phone,
        'role': role,
      }),
    );

    final Map<String, dynamic> responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200) {
      final user = responseBody['user'];

      await _copyBackendTokenToClipboard(
        label: 'TOKEN API BACKEND REGISTER',
        token: responseBody['token'],
      );

      await _storageService.saveUserSession(
        token: responseBody['token'].toString(),
        userId: user['id'].toString(),
        name: user['name'].toString(),
        email: user['email'].toString(),
        role: user['role'].toString(),
      );

      await _saveFcmTokenIfFamily(user);

      return {
        'success': true,
        'message': responseBody['message'],
        'user': user,
      };
    }

    return {
      'success': false,
      'message': _buildErrorMessage(
        responseBody: responseBody,
        defaultMessage: 'Register gagal',
      ),
    };
  }

  Future<Map<String, dynamic>> loginFirebaseUser({
    required String idToken,
  }) async {
    final url = Uri.parse(ApiConfig.firebaseLogin);

    await _copyFirebaseIdTokenToClipboard(
      label: 'FIREBASE ID TOKEN LOGIN',
      idToken: idToken,
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
      }),
    );

    final Map<String, dynamic> responseBody = _safeDecodeResponse(response);

    if (response.statusCode == 200) {
      final user = responseBody['user'];

      await _copyBackendTokenToClipboard(
        label: 'TOKEN API BACKEND LOGIN',
        token: responseBody['token'],
      );

      await _storageService.saveUserSession(
        token: responseBody['token'].toString(),
        userId: user['id'].toString(),
        name: user['name'].toString(),
        email: user['email'].toString(),
        role: user['role'].toString(),
      );

      await _saveFcmTokenIfFamily(user);

      return {
        'success': true,
        'message': responseBody['message'],
        'user': user,
      };
    }

    return {
      'success': false,
      'message': _buildErrorMessage(
        responseBody: responseBody,
        defaultMessage: 'Login gagal',
      ),
    };
  }
}