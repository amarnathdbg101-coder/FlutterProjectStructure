import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ai_tts_platform.dart' as tts_platform;

enum TtsState { stopped, playing, paused }

class AiTtsService extends ChangeNotifier {
  static final AiTtsService _instance = AiTtsService._internal();
  factory AiTtsService() => _instance;
  AiTtsService._internal();

  TtsState _state = TtsState.stopped;
  double _speechRate = 1.0; // 1.0, 1.25, 1.5, 2.0
  String _currentText = '';

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;
  double get speechRate => _speechRate;
  String get currentText => _currentText;

  void setSpeechRate(double rate) {
    _speechRate = rate;
    notifyListeners();
    if (isPlaying) {
      final current = _currentText;
      stop();
      speak(current);
    }
  }

  void cycleSpeechRate() {
    if (_speechRate == 1.0) {
      setSpeechRate(1.25);
    } else if (_speechRate == 1.25) {
      setSpeechRate(1.5);
    } else if (_speechRate == 1.5) {
      setSpeechRate(2.0);
    } else {
      setSpeechRate(1.0);
    }
  }

  static String sanitizeTextForSpeech(String text) {
    var s = text;

    // 1. Remove Code fences & JSON diagram blocks
    s = s.replaceAll(RegExp(r'```[\s\S]*?```'), ' Code and diagram block omitted. ');

    // 2. Clean LaTeX math equations into natural spoken words
    s = s.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '${m.group(1)} divided by ${m.group(2)}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => 'square root of ${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\vec\{([^}]+)\}'), (m) => 'vector ${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) => ' to the power of ${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\^([0-9a-zA-Z])'), (m) => ' to the power of ${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (m) => ' subscript ${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'_([0-9a-zA-Z])'), (m) => ' subscript ${m.group(1)}');

    // Greek symbols
    const greekSpoken = {
      r'\alpha': 'alpha', r'\beta': 'beta', r'\gamma': 'gamma', r'\delta': 'delta',
      r'\theta': 'theta', r'\lambda': 'lambda', r'\mu': 'mu', r'\pi': 'pi',
      r'\sigma': 'sigma', r'\omega': 'omega', r'\Delta': 'delta', r'\infty': 'infinity',
      r'\times': ' times ', r'\cdot': ' times ', r'\div': ' divided by ',
      r'\sum': 'summation of ', r'\int': 'integral of ', r'\lim': 'limit as ',
    };
    greekSpoken.forEach((k, v) { s = s.replaceAll(k, v); });

    // Clean wrapping math dollars $$...$$ and $...$
    s = s.replaceAll(r'$$', ' ');
    s = s.replaceAll(r'$', ' ');

    // 3. Clean Markdown headers & formatting markers
    s = s.replaceAll(RegExp(r'#{1,6}\s*'), ' ');
    s = s.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    s = s.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    s = s.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    s = s.replaceAll(RegExp(r'[-*•]\s+'), ' ');

    // 4. Clean emojis and special symbols
    s = s.replaceAll('💡', ' Note: ');
    s = s.replaceAll('⚠️', ' Warning: ');
    s = s.replaceAll('❌', ' Incorrect: ');
    s = s.replaceAll('✅', ' Correct: ');
    s = s.replaceAll('🎯', ' Exam Focus: ');
    s = s.replaceAll('🧠', ' Feynman Hook: ');
    s = s.replaceAll('📌', ' Key Takeaway: ');

    // Clean multiple whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Future<void> speak(String text) async {
    final clean = sanitizeTextForSpeech(text);
    if (clean.isEmpty) return;

    _currentText = text;
    _state = TtsState.playing;
    notifyListeners();

    try {
      tts_platform.speakTextWeb(clean, _speechRate, () {
        _state = TtsState.stopped;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('TTS Error: $e');
      _state = TtsState.stopped;
      notifyListeners();
    }
  }

  void pause() {
    if (_state == TtsState.playing) {
      tts_platform.pauseTextWeb();
      _state = TtsState.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (_state == TtsState.paused) {
      tts_platform.resumeTextWeb();
      _state = TtsState.playing;
      notifyListeners();
    } else if (_currentText.isNotEmpty) {
      speak(_currentText);
    }
  }

  void stop() {
    tts_platform.stopTextWeb();
    _state = TtsState.stopped;
    notifyListeners();
  }
}
