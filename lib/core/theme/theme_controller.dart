import 'package:flutter/material.dart';
import '../storage/hive_storage.dart';

class ThemeController extends ChangeNotifier {
  static const String _themeKey = 'user_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeController() {
    _loadThemeMode();
  }

  void _loadThemeMode() {
    try {
      final savedMode = HiveStorage.boxSyncMeta.get(_themeKey) as String?;
      if (savedMode == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedMode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      await HiveStorage.boxSyncMeta.put(_themeKey, modeStr);
    } catch (_) {}
  }
}
