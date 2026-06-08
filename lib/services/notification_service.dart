import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final StorageService _storageService = StorageService();

  Future<void> requestNotificationPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getFcmToken() async {
    final token = await _firebaseMessaging.getToken();
    return token;
  }

  Future<Map<String, dynamic>> saveFcmTokenToApi() async {
    final rasaToken = await _storageService.getToken();

    if (rasaToken == null || rasaToken.isEmpty) {
      return {
        'success': false,
        'message': 'Token login tidak ditemukan. Silakan login ulang.',
      };
    }

    await requestNotificationPermission();

    final fcmToken = await getFcmToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      return {
        'success': false,
        'message': 'FCM token tidak ditemukan.',
      };
    }

    final url = Uri.parse(ApiConfig.notificationToken);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $rasaToken',
      },
      body: jsonEncode({
        'fcmToken': fcmToken,
        'deviceName': 'Android Device',
      }),
    );

    if (response.body.isEmpty) {
      return {
        'success': false,
        'message': 'Response API kosong. Status code: ${response.statusCode}',
      };
    }

    Map<String, dynamic> responseBody;

    try {
      responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message':
            'Response API bukan JSON. Status code: ${response.statusCode}. Body: ${response.body}',
      };
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'message': responseBody['message'] ?? 'FCM token berhasil disimpan',
        'fcmToken': fcmToken,
      };
    }

    return {
      'success': false,
      'message': responseBody['message'] ?? 'Gagal menyimpan FCM token',
    };
  }

  void listenForegroundNotification() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('NOTIF FOREGROUND TITLE: ${message.notification?.title}');
      print('NOTIF FOREGROUND BODY: ${message.notification?.body}');
      print('NOTIF DATA: ${message.data}');
    });
  }
}