import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'user_id';
  static const String _nameKey = 'name';
  static const String _emailKey = 'email';
  static const String _roleKey = 'role';

  Future<void> saveUserSession({
    required String token,
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_roleKey, role);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
  }

  Future<void> savePendingFamilyRequest({
  required String familyEmail,
  String? familyName,
}) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('pending_family_email', familyEmail);
  await prefs.setString('pending_family_name', familyName ?? familyEmail);
}

Future<Map<String, String>?> getPendingFamilyRequest() async {
  final prefs = await SharedPreferences.getInstance();

  final email = prefs.getString('pending_family_email');
  final name = prefs.getString('pending_family_name');

  if (email == null || email.isEmpty) {
    return null;
  }

  return {
    'name': name ?? email,
    'email': email,
  };
}

Future<void> clearPendingFamilyRequest() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.remove('pending_family_email');
  await prefs.remove('pending_family_name');
}
}