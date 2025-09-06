import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserPrefs {
  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';
  static const _kEmail = 'email';
  static const _kKeyPassword = 'password'; // secure
  static const _secure = FlutterSecureStorage();

  static Future<String?> getUserId() async => (await SharedPreferences.getInstance()).getString(_kUserId);
  static Future<String?> getUserName() async => (await SharedPreferences.getInstance()).getString(_kUserName);
  static Future<String?> getEmail() async => (await SharedPreferences.getInstance()).getString(_kEmail);
  static Future<String?> getPassword() async => await _secure.read(key: _kKeyPassword);

  static Future<void> saveSession({
    required String userId,
    required String email,
    String? userName,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kEmail, email);
    if (userName != null && userName.isNotEmpty) {
      await prefs.setString(_kUserName, userName);
    }
    if (password != null && password.isNotEmpty) {
      await _secure.write(key: _kKeyPassword, value: password);
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kEmail);
    await _secure.delete(key: _kKeyPassword);
  }
}
