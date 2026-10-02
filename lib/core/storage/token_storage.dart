import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _keyToken = 'auth_jwt_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserName = 'auth_user_name';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveSession({
    required String token,
    String? userId,
    String? email,
    String? name,
  }) async {
    await init();
    await _prefs!.setString(_keyToken, token);
    if (userId != null) await _prefs!.setString(_keyUserId, userId);
    if (email != null) await _prefs!.setString(_keyUserEmail, email);
    if (name != null) await _prefs!.setString(_keyUserName, name);
  }

  static String? getToken() {
    return _prefs?.getString(_keyToken);
  }

  static bool hasToken() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  static String? getUserName() {
    return _prefs?.getString(_keyUserName);
  }

  static String? getUserEmail() {
    return _prefs?.getString(_keyUserEmail);
  }

  static Future<void> clearSession() async {
    await init();
    await _prefs!.remove(_keyToken);
    await _prefs!.remove(_keyUserId);
    await _prefs!.remove(_keyUserEmail);
    await _prefs!.remove(_keyUserName);
  }
}
