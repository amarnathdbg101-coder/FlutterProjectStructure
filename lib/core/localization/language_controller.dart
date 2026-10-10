import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/token_storage.dart';
import 'app_translations.dart';

enum AppLanguage { english, hindi }

class LanguageController extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;
  String get languageCode => _currentLanguage == AppLanguage.hindi ? 'hi' : 'en';

  LanguageController() {
    _loadSavedLanguage();
  }

  void _loadSavedLanguage() {
    final savedCode = TokenStorage.getLanguage();
    if (savedCode == 'hi') {
      _currentLanguage = AppLanguage.hindi;
    } else {
      _currentLanguage = AppLanguage.english;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    await TokenStorage.saveLanguage(languageCode);
    notifyListeners();
  }

  String tr(String key) {
    return AppTranslations.get(key, _currentLanguage);
  }
}

extension LocalizationContext on BuildContext {
  String tr(String key) {
    try {
      return Provider.of<LanguageController>(this, listen: false).tr(key);
    } catch (_) {
      return key;
    }
  }

  LanguageController get languageController => Provider.of<LanguageController>(this, listen: false);

  bool get isHindi => languageController.currentLanguage == AppLanguage.hindi;
}

