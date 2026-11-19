import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _keyToken = 'shopsilo_token';
  static const String _keyRefreshToken = 'shopsilo_refresh_token';
  static const String _keyUserJson = 'shopsilo_user';
  static const String _keyShopJson = 'shopsilo_shop';
  static const String _keyStaffJson = 'shopsilo_staff';
  static const String _keyLanguage = 'shopsilo_language';
  static const String _keyThemeMode = 'shopsilo_theme_mode';
  static const String _keyShowProfitMargins = 'shopsilo_show_profit_margins';
  static const String _keyCustomServerUrl = 'shopsilo_custom_server_url';
  static const String _keyUseProduction = 'shopsilo_use_production';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveLanguage(String languageCode) async {
    await init();
    await _prefs!.setString(_keyLanguage, languageCode);
  }

  static String getLanguage() {
    return _prefs?.getString(_keyLanguage) ?? 'en';
  }

  static Future<void> saveThemeMode(String mode) async {
    await init();
    await _prefs!.setString(_keyThemeMode, mode);
  }

  static String getThemeMode() {
    return _prefs?.getString(_keyThemeMode) ?? 'system';
  }

  static Future<void> saveShowProfitMargins(bool show) async {
    await init();
    await _prefs!.setBool(_keyShowProfitMargins, show);
  }

  static bool getShowProfitMargins() {
    return _prefs?.getBool(_keyShowProfitMargins) ?? true;
  }

  static Future<void> saveCustomServerUrl(String url) async {
    await init();
    await _prefs!.setString(_keyCustomServerUrl, url.trim());
  }

  static String? getCustomServerUrl() {
    return _prefs?.getString(_keyCustomServerUrl);
  }

  static Future<void> saveUseProduction(bool useProd) async {
    await init();
    await _prefs!.setBool(_keyUseProduction, useProd);
  }

  static bool getUseProduction({bool defaultValue = false}) {
    return _prefs?.getBool(_keyUseProduction) ?? defaultValue;
  }

  static String? _memoryToken;
  static String? _memoryRefreshToken;

  static Future<void> saveToken(String token) async {
    _memoryToken = token;
    await init();
    await _prefs!.setString(_keyToken, token);
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    _memoryRefreshToken = refreshToken;
    await init();
    await _prefs!.setString(_keyRefreshToken, refreshToken);
  }

  static String? getRefreshToken() {
    if (_memoryRefreshToken != null && _memoryRefreshToken!.isNotEmpty) {
      return _memoryRefreshToken;
    }
    final stored = _prefs?.getString(_keyRefreshToken);
    if (stored != null && stored.isNotEmpty) {
      _memoryRefreshToken = stored;
      return stored;
    }
    return null;
  }

  static Future<void> saveSession({
    required String token,
    String? refreshToken,
    Map<String, dynamic>? user,
    Map<String, dynamic>? shop,
  }) async {
    _memoryToken = token;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _memoryRefreshToken = refreshToken;
    }
    await init();
    await _prefs!.setString(_keyToken, token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _prefs!.setString(_keyRefreshToken, refreshToken);
    }
    if (user != null) {
      await _prefs!.setString(_keyUserJson, jsonEncode(user));
    }
    if (shop != null) {
      await _prefs!.setString(_keyShopJson, jsonEncode(shop));
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    await init();
    await _prefs!.setString(_keyUserJson, jsonEncode(user));
  }

  static Future<void> saveShop(Map<String, dynamic> shop) async {
    await init();
    await _prefs!.setString(_keyShopJson, jsonEncode(shop));
  }

  static Future<void> removeShop() async {
    await init();
    await _prefs!.remove(_keyShopJson);
  }

  static Future<void> saveStaff(Map<String, dynamic> staff) async {
    await init();
    await _prefs!.setString(_keyStaffJson, jsonEncode(staff));
  }

  static String? getToken() {
    if (_memoryToken != null && _memoryToken!.isNotEmpty) {
      return _memoryToken;
    }
    final stored = _prefs?.getString(_keyToken);
    if (stored != null && stored.isNotEmpty) {
      _memoryToken = stored;
      return stored;
    }
    return null;
  }

  static bool hasToken() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  static Map<String, dynamic>? getUser() {
    final jsonStr = _prefs?.getString(_keyUserJson);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getShop() {
    final jsonStr = _prefs?.getString(_keyShopJson);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getStaff() {
    final jsonStr = _prefs?.getString(_keyStaffJson);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static const String _keyLastRoute = 'shopsilo_last_route';
  static const String _keyActiveTabIndex = 'shopsilo_active_tab_index';

  static Future<void> saveLastRoute(String route) async {
    if (route.isEmpty ||
        route == '/' ||
        route == '/login' ||
        route == '/register') {
      return;
    }
    await init();
    await _prefs!.setString(_keyLastRoute, route);
  }

  static String? getLastRoute() {
    return _prefs?.getString(_keyLastRoute);
  }

  static Future<void> saveActiveTabIndex(int index) async {
    await init();
    await _prefs!.setInt(_keyActiveTabIndex, index);
  }

  static int getActiveTabIndex() {
    return _prefs?.getInt(_keyActiveTabIndex) ?? 0;
  }

  static Future<void> clearSession() async {
    _memoryToken = null;
    _memoryRefreshToken = null;
    await init();
    await _prefs!.remove(_keyToken);
    await _prefs!.remove(_keyRefreshToken);
    await _prefs!.remove(_keyUserJson);
    await _prefs!.remove(_keyShopJson);
    await _prefs!.remove(_keyStaffJson);
    await _prefs!.remove(_keyLastRoute);
    await _prefs!.remove(_keyActiveTabIndex);
  }
}
