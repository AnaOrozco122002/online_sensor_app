// lib/services/user_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _kUserId = 'user_id';
  static const _kEmail = 'email';
  static const _kUserName = 'user_name';
  static const _kPassword = 'password'; // si no quieres guardar password, puedes omitir
  static const _kAvatarUrl = 'avatar_url';

  static Future<void> saveSession({
    required String userId,
    required String email,
    String? userName,
    String? password,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserId, userId);
    await sp.setString(_kEmail, email);
    if (userName != null) await sp.setString(_kUserName, userName);
    if (password != null) await sp.setString(_kPassword, password);
  }

  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kEmail);
    await sp.remove(_kUserName);
    await sp.remove(_kPassword);
    // Conservamos avatar si quieres que quede para la próxima sesión.
    // Si quieres borrarlo, descomenta:
    // await sp.remove(_kAvatarUrl);
  }

  static Future<String?> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUserId);
  }

  static Future<String?> getEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> getUserName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUserName);
  }

  static Future<String?> getPassword() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kPassword);
  }

  // Avatar URL
  static Future<void> setAvatarUrl(String? url) async {
    final sp = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await sp.remove(_kAvatarUrl);
    } else {
      await sp.setString(_kAvatarUrl, url.trim());
    }
  }

  static Future<String?> getAvatarUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAvatarUrl);
  }
}
