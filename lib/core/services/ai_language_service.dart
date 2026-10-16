import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Representation of a supported AI response language in StudySilo.
class AILanguageOption {
  final String id;
  final String name;
  final String nativeName;
  final String icon;
  final String description;

  const AILanguageOption({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.icon,
    required this.description,
  });
}

/// Global service managing persistent AI response language configuration.
class AILanguageService {
  static const String _prefKey = 'studysilo_ai_response_language';

  /// Top supported languages for academic learning
  static const List<AILanguageOption> supportedLanguages = [
    AILanguageOption(
      id: 'auto',
      name: 'Auto / All',
      nativeName: 'Prompt Tone Match',
      icon: '🌐',
      description: 'Matches the exact language & tone of your query automatically',
    ),
    AILanguageOption(
      id: 'hinglish',
      name: 'Hinglish',
      nativeName: 'Hindi in Roman Script',
      icon: '🇮🇳',
      description: 'Simple conversational Hindi in English letters (Feynman style)',
    ),
    AILanguageOption(
      id: 'english',
      name: 'English',
      nativeName: 'English (Academic)',
      icon: '🇬🇧',
      description: 'Clear, rigorous academic English with precise scientific terms',
    ),
    AILanguageOption(
      id: 'hindi',
      name: 'Hindi',
      nativeName: 'हिन्दी (Devanagari)',
      icon: '🇮🇳',
      description: 'Pure Hindi in clean Devanagari script with English tech terms',
    ),
    AILanguageOption(
      id: 'bengali',
      name: 'Bengali',
      nativeName: 'বাংলা',
      icon: '🇮🇳',
      description: 'Academic Bengali explanations with clear step-by-step logic',
    ),
    AILanguageOption(
      id: 'marathi',
      name: 'Marathi',
      nativeName: 'मराठी',
      icon: '🇮🇳',
      description: 'Academic Marathi with point-by-point conceptual clarity',
    ),
    AILanguageOption(
      id: 'tamil',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      icon: '🇮🇳',
      description: 'Clear Tamil explanations preserving standard scientific formulas',
    ),
    AILanguageOption(
      id: 'telugu',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      icon: '🇮🇳',
      description: 'Student-friendly Telugu explanations for exam readiness',
    ),
    AILanguageOption(
      id: 'gujarati',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      icon: '🇮🇳',
      description: 'Point-by-point Gujarati breakdown of complex subjects',
    ),
  ];

  static SharedPreferences? _prefs;
  static String _currentLanguage = 'auto';

  /// Initialize service on application launch
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _currentLanguage = _prefs?.getString(_prefKey) ?? 'auto';
  }

  /// Synchronous retrieval for fast network interceptors
  static String getSelectedLanguageSync() {
    return _currentLanguage;
  }

  /// Find language option metadata by ID
  static AILanguageOption getOption(String id) {
    return supportedLanguages.firstWhere(
      (lang) => lang.id.toLowerCase() == id.toLowerCase(),
      orElse: () => supportedLanguages.first,
    );
  }

  /// Update selected language and persist to storage
  static Future<void> setLanguage(String langId) async {
    final valid = supportedLanguages.any((l) => l.id == langId);
    final target = valid ? langId : 'auto';
    _currentLanguage = target;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_prefKey, target);
  }
}

/// Riverpod 3.x Notifier for reactive UI state across screens
class AILanguageNotifier extends Notifier<String> {
  @override
  String build() {
    return AILanguageService.getSelectedLanguageSync();
  }

  Future<void> selectLanguage(String langId) async {
    await AILanguageService.setLanguage(langId);
    state = AILanguageService.getSelectedLanguageSync();
  }
}

/// Provider exposing the reactive AI language selection
final aiLanguageProvider = NotifierProvider<AILanguageNotifier, String>(AILanguageNotifier.new);
