import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Supported voice doubt input languages
enum VoiceDoubtLanguage {
  hinglish(label: 'Hinglish (India)', code: 'hi_IN', flag: '🇮🇳'),
  english(label: 'English', code: 'en_IN', flag: '🇬🇧'),
  hindi(label: 'हिन्दी', code: 'hi_IN', flag: '🇮🇳');

  final String label;
  final String code;
  final String flag;

  const VoiceDoubtLanguage({
    required this.label,
    required this.code,
    required this.flag,
  });
}

/// Service managing Voice Doubt Input (Speech-to-Text & Academic Speech Cleaning).
/// Supports natural Hinglish, English, and Hindi voice queries from students,
/// cleans academic terminology, and provides instant voice doubt prompt starters.
class VoiceDoubtService {
  static final VoiceDoubtService _instance = VoiceDoubtService._internal();
  factory VoiceDoubtService() => _instance;
  VoiceDoubtService._internal();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized && _speechToText.isAvailable;

  /// Curated student voice doubt prompts across subjects for instant 1-tap testing
  static const List<Map<String, String>> popularVoiceDoubts = [
    {
      'topic': 'Physics / Induction',
      'query': "Bhai ye Faraday's law me negative sign kyu aata hai?",
      'lang': 'hinglish',
      'icon': '⚡',
    },
    {
      'topic': 'Calculus & Math',
      'query': 'Iska step-by-step rigorous mathematical derivation aur intuition samjhao',
      'lang': 'hinglish',
      'icon': '📐',
    },
    {
      'topic': 'Exams & Scoring',
      'query': 'Exam point of view se is concept me kaunse common traps aur pitfalls hote hain?',
      'lang': 'hinglish',
      'icon': '🎯',
    },
    {
      'topic': 'Feynman Analogy',
      'query': 'Explain this concept using a simple everyday real-world analogy like I am 10 years old',
      'lang': 'english',
      'icon': '🧠',
    },
    {
      'topic': 'Thermodynamics',
      'query': 'Entropy hamesha increase kyu hoti hai second law of thermodynamics me?',
      'lang': 'hinglish',
      'icon': '🔥',
    },
    {
      'topic': 'CS / Algorithms',
      'query': 'What is the time and space complexity with edge cases for this algorithm?',
      'lang': 'english',
      'icon': '💻',
    },
    {
      'topic': 'Organic Chemistry',
      'query': 'Electrophilic aromatic substitution me ortho-para directing groups kaise decide hote hain?',
      'lang': 'hinglish',
      'icon': '🧪',
    },
  ];

  /// Academic keyword auto-capitalization and speech cleanup dictionary
  static final Map<String, String> _academicReplacements = {
    r'\bfaraday(\w*)?\b': "Faraday's",
    r'\blenz(\w*)?\b': "Lenz's",
    r'\bnewton(\w*)?\b': "Newton's",
    r'\beuler(\w*)?\b': "Euler-Lagrange",
    r'\bbernoulli(\w*)?\b': "Bernoulli's",
    r'\bschrod(\w*)?\b': "Schrödinger",
    r'\bmaxwell(\w*)?\b': "Maxwell's",
    r'\bgauss(\w*)?\b': "Gauss's",
    r'\bboltzmann(\w*)?\b': "Boltzmann",
    r'\bkyu\b': 'kyun',
    r'\bkyu aata\b': 'kyun aata',
    r'\bderivasion\b': 'derivation',
    r'\bdefination\b': 'definition',
  };

  /// Clean, standardize, and format transcribed student speech for optimal LLM tutor context
  String cleanAcademicSpeech(String rawSpeech) {
    if (rawSpeech.trim().isEmpty) return '';

    String cleaned = rawSpeech.trim();

    // Remove vocal filler words
    cleaned = cleaned.replaceAll(RegExp(r'\b(umm|uhh|ahh|like you know)\b', caseSensitive: false), '');

    // Normalize spacing
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Standardize academic names & terms
    for (final entry in _academicReplacements.entries) {
      cleaned = cleaned.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }

    // Ensure sentence starts capitalized
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Add question mark if it is an inquisitive doubt without punctuation
    if (!cleaned.endsWith('?') && !cleaned.endsWith('.') && !cleaned.endsWith('!')) {
      final isQuestion = RegExp(
        r'\b(kyu|kyun|kaise|kya|why|how|what|explain|when|where|prove|derive|samjhao|batao)\b',
        caseSensitive: false,
      ).hasMatch(cleaned);

      if (isQuestion) {
        cleaned = '$cleaned?';
      }
    }

    return cleaned.trim();
  }

  /// Initialize Speech-to-Text engine
  Future<bool> initSpeech({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('VoiceDoubtService status: $status');
          if (onStatus != null) onStatus(status);
        },
        onError: (errorNotification) {
          debugPrint('VoiceDoubtService error: ${errorNotification.errorMsg}');
          if (onError != null) onError(errorNotification.errorMsg);
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('VoiceDoubtService init exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening and streaming recognized words
  Future<bool> startListening({
    required ValueChanged<String> onResult,
    String localeId = 'hi_IN',
    VoidCallback? onDone,
  }) async {
    if (!_isInitialized) {
      final success = await initSpeech();
      if (!success) return false;
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (result.finalResult) {
            final cleaned = cleanAcademicSpeech(words);
            onResult(cleaned.isNotEmpty ? cleaned : words);
            if (onDone != null) onDone();
          } else {
            onResult(words);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 60),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('VoiceDoubtService startListening exception: $e');
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('VoiceDoubtService stopListening exception: $e');
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
    } catch (e) {
      debugPrint('VoiceDoubtService cancelListening exception: $e');
    }
  }

  /// Returns sample voice doubt prompts for a given context or topic
  List<Map<String, String>> getSuggestedDoubtsForTopic({String? topic, String? noteTitle, String? scopeTitle}) {
    final title = scopeTitle ?? noteTitle ?? topic;
    if (title != null && title.isNotEmpty) {
      return [
        {
          'topic': title,
          'query': 'Bhai "$title" ka core essence aur high-yield exam points samjhao',
          'lang': 'hinglish',
          'icon': '📖',
        },
        {
          'topic': title,
          'query': 'What is the physical meaning and step-by-step intuition behind "$title"?',
          'lang': 'english',
          'icon': '💡',
        },
        ...popularVoiceDoubts.take(4),
      ];
    }
    return popularVoiceDoubts;
  }
}
