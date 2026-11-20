import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../localization/language_controller.dart';
import '../widgets/custom_snackbar.dart';

bool _safeIsHindi(BuildContext context) {
  try {
    return context.isHindi;
  } catch (_) {
    return false;
  }
}

/// Universal Industrial-Grade Speech-to-Text Voice Engine for ShopSilo.
/// Seamlessly handles:
/// 1. Dynamic bilingual locale resolution (`hi_IN` for Hindi & `en_IN` for Indian English).
/// 2. Punctuation stripping (`.` `,` `?` `!`) and conversational stopword cleaning.
/// 3. Bilingual Indian retail staple keyword mapping (e.g., 'टाटा नमक' -> 'Tata Salt').
/// 4. Resilient silence detection (1500ms) with auto-search execution.
/// 5. Human-friendly error recovery across Web, Android, and Windows.
class AppVoiceInputService extends ChangeNotifier {
  static final AppVoiceInputService _instance = AppVoiceInputService._internal();
  factory AppVoiceInputService() => _instance;
  AppVoiceInputService._internal();

  static AppVoiceInputService get instance => _instance;

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentSpokenText = '';
  String? _lastError;
  List<LocaleName> _supportedLocales = [];

  // Active controller and callbacks being dictated into
  TextEditingController? _activeController;
  ValueChanged<String>? _activeOnChanged;
  ValueChanged<String>? _activeOnSubmitted;
  VoidCallback? _activeOnDone;
  Timer? _silenceTimer;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized && _speechToText.isAvailable;
  String get currentSpokenText => _currentSpokenText;
  String? get lastError => _lastError;
  TextEditingController? get activeController => _activeController;

  // Indian Retail Colloquial to Catalog Staple Mapping
  static const Map<String, String> retailBilingualMap = {
    'दूध': 'Amul Milk',
    'अमूल दूध': 'Amul Milk',
    'टाटा नमक': 'Tata Salt',
    'नमक': 'Tata Salt',
    'तेल': 'Fortune Oil',
    'सरसों तेल': 'Mustard Oil',
    'सरसो तेल': 'Mustard Oil',
    'रिफाइंड': 'Refined Oil',
    'घी': 'Amul Ghee',
    'चावल': 'Basmati Rice',
    'बासमती': 'Basmati Rice',
    'आटा': 'Aashirvaad Atta',
    'गेहूं आटा': 'Wheat Atta',
    'मैदा': 'Maida',
    'बेसन': 'Besan',
    'सूजी': 'Sooji',
    'पोहा': 'Poha',
    'दाल': 'Toor Dal',
    'अरहर दाल': 'Arhar Dal',
    'तूर दाल': 'Toor Dal',
    'मूंग दाल': 'Moong Dal',
    'चना': 'Chana',
    'चना दाल': 'Chana Dal',
    'राजमा': 'Rajma',
    'चीनी': 'Sugar',
    'शक्कर': 'Sugar',
    'गुड़': 'Jaggery',
    'मसाला': 'Masala',
    'हल्दी': 'Haldi Turmeric',
    'मिर्च': 'Mirch Chilli',
    'धनिया': 'Dhaniya Coriander',
    'जीरा': 'Jeera Cumin',
    'अदरक': 'Ginger Adrak',
    'लहसुन': 'Garlic Lehsun',
    'चाय': 'Red Label Tea',
    'चायपत्ती': 'Tea Chaipatti',
    'कॉफ़ी': 'Nescafe Coffee',
    'पानी': 'Bisleri Water',
    'बिस्कुट': 'Parle G Biscuit',
    'बिस्किट': 'Parle G Biscuit',
    'पारले जी': 'Parle G',
    'नमकीन': 'Haldiram Namkeen',
    'भुजिया': 'Haldiram Bhujia',
    'चिप्स': 'Lays Chips',
    'कुरकुरे': 'Kurkure',
    'चॉकलेट': 'Cadbury Chocolate',
    'साबुन': 'Lifebuoy Soap',
    'डव': 'Dove Soap',
    'शैम्पू': 'Clinic Plus Shampoo',
    'सर्फ': 'Surf Excel',
    'सर्फ़': 'Surf Excel',
    'घड़ी': 'Ghadi Detergent',
    'हार्पिक': 'Harpic Cleaner',
    'कोलगेट': 'Colgate Toothpaste',
    'मंजन': 'Colgate Toothpaste',
    'टूथपेस्ट': 'Colgate Toothpaste',
    'ब्रश': 'Toothbrush',
    'दवा': 'Paracetamol Tablet',
    'मैगी': 'Maggi Noodles',
    'नूडल्स': 'Maggi Noodles',
  };

  /// Strips trailing punctuation added by speech engines (e.g. "Tata Salt." -> "Tata Salt")
  static String stripTrailingPunctuation(String text) {
    if (text.isEmpty) return '';
    return text.trim().replaceAll(RegExp(r'[.,?!:;]+$'), '').trim();
  }

  /// Strips conversational fillers and stopwords from speech transcripts
  static String cleanVoiceQuery(String raw) {
    if (raw.isEmpty) return '';
    final stripped = stripTrailingPunctuation(raw);
    final words = stripped.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length <= 1) return stripped;

    final stopwords = <String>{
      // Hindi / Hinglish fillers
      'chahiye', 'chahie', 'chaahiye', 'dikhao', 'dikhaye', 'dikhaiye', 'batao', 'bataiye',
      'de do', 'dedo', 'do', 'lao', 'khojo', 'dhundho', 'dhundo',
      'ka', 'ki', 'ke', 'ko', 'se', 'me', 'mein', 'par', 'aur', 'ya',
      'wala', 'wali', 'wale', 'vale', 'vali',
      'sabse', 'sasta', 'achha', 'accha', 'bhai', 'bhaiya', 'please', 'plz',
      'packet', 'dabba', 'pauwa', 'kilo', 'kg', 'gram', 'litre', 'liter',
      // English fillers
      'i', 'want', 'need', 'show', 'give', 'get', 'find', 'search', 'for', 'look', 'looking',
      'near', 'nearby', 'best', 'cheap', 'cheapest', 'good', 'pack', 'bottle',
      // Devanagari fillers
      'चाहिए', 'दिखाओ', 'दिखाइए', 'बताओ', 'बताइए', 'दे', 'दो', 'लाओ', 'खोजो', 'ढूंढो',
      'का', 'की', 'के', 'को', 'से', 'में', 'पर', 'और', 'या',
      'वाला', 'वाली', 'वाले',
      'सबसे', 'सस्ता', 'अच्छा', 'भाई', 'भैया', 'प्लीज',
      'पैकेट', 'डब्बा', 'किलो', 'ग्राम', 'लीटर',
    };

    final filtered = words.where((w) => !stopwords.contains(w.toLowerCase().trim())).toList();
    return filtered.isNotEmpty ? filtered.join(' ') : stripped;
  }

  /// Localized error message resolver
  static String getFriendlyErrorMessage(String errorMsg, bool isHindi) {
    switch (errorMsg) {
      case 'error_permission':
        return isHindi
            ? 'माइक्रोफ़ोन अनुमति की आवश्यकता है। कृपया अनुमति दें।'
            : 'Microphone permission is required. Please grant permission.';
      case 'error_no_match':
      case 'error_speech_timeout':
        return isHindi
            ? 'कोई आवाज़ सुनाई नहीं दी। कृपया माइक के पास आकर दोबारा बोलें।'
            : 'No speech detected. Please speak closer to the microphone.';
      case 'error_network':
        return isHindi
            ? 'नेटवर्क समस्या है। कृपया इंटरनेट जांचें।'
            : 'Network error. Please check your internet connection.';
      case 'error_busy':
        return isHindi
            ? 'माइक्रोफ़ोन पहले से उपयोग में है।'
            : 'Microphone is currently in use.';
      default:
        return isHindi
            ? 'वॉइस इनपुट में समस्या आई। पुनः प्रयास करें।'
            : 'Voice recognition issue. Please try again.';
    }
  }

  bool isListeningTo(TextEditingController controller) {
    return _isListening && identical(_activeController, controller);
  }

  /// Safe initialization of Speech-to-Text engine and locale discovery.
  Future<bool> init() async {
    if (_isInitialized) return _speechToText.isAvailable;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: kDebugMode,
      );
      if (_isInitialized) {
        try {
          _supportedLocales = await _speechToText.locales();
        } catch (_) {
          _supportedLocales = [];
        }
      }
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('[AppVoiceInputService] Failed to initialize: $e');
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  /// Resolves optimal locale for Indian retail speech (defaults to hi_IN or en_IN)
  Future<String> resolveLocaleId(bool isHindi) async {
    try {
      if (_supportedLocales.isEmpty && _isInitialized) {
        _supportedLocales = await _speechToText.locales();
      }

      final preferred = isHindi ? 'hi_in' : 'en_in';
      for (final loc in _supportedLocales) {
        if (loc.localeId.toLowerCase().replaceAll('-', '_') == preferred) {
          return loc.localeId;
        }
      }

      final targetPrefix = isHindi ? 'hi' : 'en';
      for (final loc in _supportedLocales) {
        if (loc.localeId.toLowerCase().startsWith(targetPrefix)) {
          return loc.localeId;
        }
      }
    } catch (_) {}

    return isHindi ? 'hi_IN' : 'en_IN';
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('[AppVoiceInputService] Error: ${error.errorMsg} (permanent: ${error.permanent})');
    _lastError = error.errorMsg;
    if (error.permanent || error.errorMsg == 'error_no_match') {
      _commitAndFinish();
    }
  }

  void _handleStatus(String status) {
    debugPrint('[AppVoiceInputService] Status: $status');
    if (status == 'listening') {
      _isListening = true;
      notifyListeners();
    } else if (status == 'notListening' || status == 'done') {
      if (_isListening) {
        _commitAndFinish();
      }
    }
  }

  /// 1-Tap Inline Voice Dictation and Auto-Search.
  /// Tapping mic starts listening inline. Speaking streams text live into controller.
  /// 1500ms after user stops speaking, it automatically stops, cleans text, and executes search!
  Future<void> listenAndFill({
    required BuildContext context,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onDone,
    Duration silenceTimeout = const Duration(milliseconds: 1500),
    String? localeId,
  }) async {
    // If already listening to this controller, user tapped mic to stop and commit early!
    if (isListeningTo(controller)) {
      debugPrint('[AppVoiceInputService] Tapped while listening. Committing immediately.');
      _commitAndFinish();
      return;
    }

    // If listening to a different controller, finish it first
    if (_isListening) {
      _commitAndFinish();
    }

    final isHindi = _safeIsHindi(context);
    final available = await init();
    if (!available) {
      final msg = isHindi
          ? 'वॉइस इनपुट Chrome वेब ब्राउज़र या Android पर उपलब्ध है'
          : 'Voice input is available on Chrome Web and Android';
      if (context.mounted) {
        try {
          CustomSnackbar.showWarning(context, msg);
        } catch (_) {}
      }
      return;
    }

    _activeController = controller;
    _activeOnChanged = onChanged;
    _activeOnSubmitted = onSubmitted;
    _activeOnDone = onDone;
    _currentSpokenText = '';
    _lastError = null;

    final effectiveLocale = localeId ?? await resolveLocaleId(isHindi);

    try {
      _isListening = true;
      notifyListeners();

      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _onSpeechResult(result, silenceTimeout);
        },
        listenOptions: SpeechListenOptions(
          localeId: effectiveLocale,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.search,
        ),
      );
    } catch (e) {
      debugPrint('[AppVoiceInputService] Error starting listen: $e');
      _commitAndFinish();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, Duration silenceTimeout) {
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      _currentSpokenText = words;
      if (_activeController != null) {
        _activeController!.text = words;
        _activeController!.selection = TextSelection.fromPosition(
          TextPosition(offset: words.length),
        );
      }
      _activeOnChanged?.call(words);
      notifyListeners();

      _silenceTimer?.cancel();

      if (result.finalResult) {
        _commitAndFinish();
      } else {
        // Auto-commit after comfortable 1.5s silence pause
        _silenceTimer = Timer(silenceTimeout, () {
          debugPrint('[AppVoiceInputService] Silence pause detected. Auto-committing: "$_currentSpokenText"');
          _commitAndFinish();
        });
      }
    }
  }

  /// Automatically commits spoken words, executes search, and restores mic state
  void _commitAndFinish() {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    final spoken = _currentSpokenText.trim();
    final ctrl = _activeController;
    final onSub = _activeOnSubmitted;
    final onChg = _activeOnChanged;
    final onDn = _activeOnDone;

    if (_isListening) {
      try {
        _speechToText.stop();
      } catch (_) {}
    }

    _isListening = false;
    _activeController = null;
    _activeOnChanged = null;
    _activeOnSubmitted = null;
    _activeOnDone = null;
    notifyListeners();

    if (spoken.isNotEmpty && ctrl != null) {
      // Clean trailing punctuation and conversational noise
      final clean = cleanVoiceQuery(spoken);
      final normalized = retailBilingualMap[clean] ?? clean;

      ctrl.text = normalized;
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: normalized.length),
      );
      onChg?.call(normalized);
      onSub?.call(normalized);
    }
    onDn?.call();
  }

  /// Start dictation with live transcription callback (generic listener)
  Future<bool> startListening({
    required BuildContext context,
    required ValueChanged<String> onResult,
    VoidCallback? onDone,
    ValueChanged<String>? onError,
    String? localeId,
  }) async {
    final isHindi = _safeIsHindi(context);
    final available = await init();
    if (!available) {
      final msg = isHindi
          ? 'इस डिवाइस पर वॉयस इनपुट उपलब्ध नहीं है'
          : 'Voice input not available on this device';
      if (context.mounted) {
        try {
          CustomSnackbar.showWarning(context, msg);
        } catch (_) {}
      }
      onError?.call(msg);
      return false;
    }

    if (_isListening) {
      await stopListening();
    }

    _currentSpokenText = '';
    _lastError = null;

    final effectiveLocale = localeId ?? await resolveLocaleId(isHindi);

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _currentSpokenText = result.recognizedWords;
          notifyListeners();
          onResult(result.recognizedWords);

          if (result.finalResult) {
            _isListening = false;
            notifyListeners();
            onDone?.call();
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: effectiveLocale,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );

      _isListening = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AppVoiceInputService] Error starting listen: $e');
      _isListening = false;
      notifyListeners();
      onError?.call(e.toString());
      return false;
    }
  }

  /// Stop listening immediately
  Future<void> stopListening() async {
    _commitAndFinish();
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_isListening) {
      try {
        await _speechToText.cancel();
      } catch (_) {}
      _isListening = false;
      _activeController = null;
      _activeOnChanged = null;
      _activeOnSubmitted = null;
      _currentSpokenText = '';
      notifyListeners();
    }
  }

  /// Ergonomic Dictation Helper.
  /// Seamlessly delegates to [listenAndFill] for instant inline typing & auto-search.
  static Future<String?> dictateInto(
    BuildContext context, {
    required TextEditingController controller,
    String? hint,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) async {
    await instance.listenAndFill(
      context: context,
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    return controller.text;
  }
}
