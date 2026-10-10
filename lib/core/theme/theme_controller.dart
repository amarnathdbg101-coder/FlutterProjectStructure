import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/token_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeController() {
    _loadSavedTheme();
  }

  void _loadSavedTheme() {
    final saved = TokenStorage.getThemeMode();
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeString = 'system';
    if (mode == ThemeMode.dark) modeString = 'dark';
    if (mode == ThemeMode.light) modeString = 'light';
    await TokenStorage.saveThemeMode(modeString);
    notifyListeners();
  }
}

extension ThemeContext on BuildContext {
  ThemeController get themeController => Provider.of<ThemeController>(this, listen: false);
}
