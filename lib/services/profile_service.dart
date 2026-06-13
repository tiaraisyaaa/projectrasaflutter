import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

class ProfileService {
  final StorageService _storageService = StorageService();

  Map<String, dynamic> _safeDecode(String body) {
    if (body.isEmpty) {
      return {'message': 'Response API kosong'};
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'message': body};
    } catch (_) {
      return {'message': body};
    }
  }

  bool _isValidPhotoUrl(String? value) {
    if (value == null) return false;

    final photoUrl = value.trim();

    if (photoUrl.isEmpty) return false;
    if (photoUrl.toLowerCase() == 'null') return false;
    if (photoUrl == '-') return false;

    return true;
  }

  String? _extractPhotoUrl(Map<String, dynamic> responseBody) {
    final user = responseBody['user'];

    if (user is Map<String, dynamic>) {
      return user['photo_url']?.toString() ??
          user['photoUrl']?.toString() ??
          user['profile_photo_url']?.toString() ??
          user['profilePhotoUrl']?.toString();
    }

    return responseBody['photo_url']?.toString() ??
        responseBody['photoUrl']?.toString() ??
        responseBody['profile_photo_url']?.toString() ??
        responseBody['profilePhotoUrl']?.toString();
  }

  String _normalizePhotoUrl(String photoUrl) {
    final cleanPhotoUrl = photoUrl.trim();

    if (cleanPhotoUrl.startsWith('http://') ||
        cleanPhotoUrl.startsWith('https://')) {
      return cleanPhotoUrl;
    }

    if (cleanPhotoUrl.startsWith('/')) {
      return '${ApiConfig.baseUrl}$cleanPhotoUrl';
    }

    return '${ApiConfig.baseUrl}/$cleanPhotoUrl';
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token tidak ditemukan. Silakan login ulang.',
      };
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.profile),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = _safeDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final rawPhotoUrl = _extractPhotoUrl(responseBody);

        String? finalPhotoUrl;

        if (_isValidPhotoUrl(rawPhotoUrl)) {
          finalPhotoUrl = _normalizePhotoUrl(rawPhotoUrl!);
          await _storageService.saveProfilePhotoUrl(finalPhotoUrl);
        } else {
          await _storageService.removeProfilePhotoUrl();
        }

        return {
          'success': true,
          'message':
              responseBody['message']?.toString() ?? 'Profile berhasil diambil',
          'user': responseBody['user'],
          'photo_url': finalPhotoUrl,
          'data': responseBody,
        };
      }

      return {
        'success': false,
        'message': responseBody['message']?.toString() ??
            'Gagal mengambil profile. Status code: ${response.statusCode}',
        'statusCode': response.statusCode,
        'data': responseBody,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengambil profile: $e'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token tidak ditemukan. Silakan login ulang.',
      };
    }

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.profile),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'Name': name,
          'Email': email,
          'Phone': phone,
        }),
      );

      final responseBody = _safeDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final user = responseBody['user'];

        if (user is Map<String, dynamic>) {
          final updatedName = user['name']?.toString() ??
              user['Name']?.toString() ??
              name;

          await _storageService.updateName(updatedName);
        } else {
          await _storageService.updateName(name);
        }

        return {
          'success': true,
          'message':
              responseBody['message']?.toString() ?? 'Profile berhasil diperbarui',
          'user': responseBody['user'],
          'data': responseBody,
        };
      }

      return {
        'success': false,
        'message': responseBody['message']?.toString() ??
            'Gagal memperbarui profile. Status code: ${response.statusCode}',
        'statusCode': response.statusCode,
        'data': responseBody,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal memperbarui profile: $e',
      };
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto({
    required File photoFile,
  }) async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token tidak ditemukan. Silakan login ulang.',
      };
    }

    if (!photoFile.existsSync()) {
      return {'success': false, 'message': 'File foto tidak ditemukan.'};
    }

    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.profilePhoto),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.files.add(
        await http.MultipartFile.fromPath('Photo', photoFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseBody = _safeDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final rawPhotoUrl = _extractPhotoUrl(responseBody);

        String? finalPhotoUrl;

        if (_isValidPhotoUrl(rawPhotoUrl)) {
          finalPhotoUrl = _normalizePhotoUrl(rawPhotoUrl!);
          await _storageService.saveProfilePhotoUrl(finalPhotoUrl);
        } else {
          await _storageService.removeProfilePhotoUrl();
        }

        return {
          'success': true,
          'message': responseBody['message']?.toString() ??
              'Foto profile berhasil diupload',
          'user': responseBody['user'],
          'photo_url': finalPhotoUrl,
          'data': responseBody,
        };
      }

      return {
        'success': false,
        'message': responseBody['message']?.toString() ??
            'Gagal upload foto. Status code: ${response.statusCode}',
        'statusCode': response.statusCode,
        'data': responseBody,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal upload foto: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteProfilePhoto() async {
    final token = await _storageService.getToken();

    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'message': 'Token tidak ditemukan. Silakan login ulang.',
      };
    }

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.profilePhoto),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final responseBody = _safeDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _storageService.removeProfilePhotoUrl();
        await _storageService.removeProfilePhotoPath();

        return {
          'success': true,
          'message': responseBody['message']?.toString() ??
              'Foto profile berhasil dihapus',
          'user': responseBody['user'],
          'photo_url': null,
          'data': responseBody,
        };
      }

      return {
        'success': false,
        'message': responseBody['message']?.toString() ??
            'Gagal hapus foto. Status code: ${response.statusCode}',
        'statusCode': response.statusCode,
        'data': responseBody,
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal hapus foto: $e'};
    }
  }
}