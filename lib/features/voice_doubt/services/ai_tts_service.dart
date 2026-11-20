import 'dart:async';
import 'dart:io' show Platform;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/latex_sanitizer.dart';
import 'ai_audio_cache_service.dart';
import 'cloud_neural_tts_service.dart';
import 'study_audio_handler.dart';

enum TtsState { stopped, playing, paused }

/// Academic Persona options for AI Voice delivery (Female Only)
enum VoicePersona {
  priya, // Warm, encouraging female tutor timbre (Priya Ma'am / hi-IN-SwaraNeural)
}

/// High-Performance AI Text-to-Speech (TTS) Service for StudySilo
/// Features:
/// 🌸 Sweet, polite, human academic voice tuning with natural pitch and cadence
/// 🧮 Comprehensive academic LaTeX, scientific formulas, and symbol spoken translation
/// ⚡ Seamless multi-sentence chunking for zero audio dropouts on long explanations
/// 📱 Full native cross-platform support across Android, iOS, Web, and Desktop
class SpokenChunk {
  final String rawText;
  final String spokenText;

  const SpokenChunk({
    required this.rawText,
    required this.spokenText,
  });
}

class AiTtsService extends ChangeNotifier {
  static final AiTtsService _instance = AiTtsService._internal();
  factory AiTtsService() => _instance;
  AiTtsService._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _webPlayer = AudioPlayer();
  StudyAudioHandler? _audioHandler;
  final CloudNeuralTtsService _cloudNeuralTts = CloudNeuralTtsService();
  bool _usingNeuralEngine = false;
  bool _dataSaverMode = false; // Zero data & low battery offline mode
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;

  static List<dynamic>? _cachedVoices;
  static final Map<VoicePersona, Map> _personaVoiceMap = {};

  TtsState _state = TtsState.stopped;
  VoicePersona _persona = VoicePersona.priya; // 100% Female Voice (Priya Ma'am)
  double _speechRate = 1.0; // User multiplier: 1.0x, 1.25x, 1.5x, 2.0x
  String _currentText = '';
  List<SpokenChunk> _chunks = [];
  int _currentChunkIndex = 0;
  bool _isInitialized = false;
  bool _isLoading = false; // Fast visual loading state

  bool _isNavigating = false;
  bool _isLiveTalkMode = false;
  VoidCallback? onLiveTalkCompleted;

  TtsState get state => _state;
  VoicePersona get persona => VoicePersona.priya;
  bool get isLoading => _isLoading;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;
  bool get isUsingNeuralEngine => _usingNeuralEngine;
  bool get isDataSaverMode => _dataSaverMode;
  bool get isLiveTalkMode => _isLiveTalkMode;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  StudyAudioHandler? get audioHandler => _audioHandler;
  double get speechRate => _speechRate;
  String get currentText => _currentText;

  /// Enables or disables Live Talk Mode (Gemini Live 1-on-1 continuous conversation loop)
  void setLiveTalkMode(bool enable, {VoidCallback? onCompleted}) {
    _isLiveTalkMode = enable;
    onLiveTalkCompleted = onCompleted;
    notifyListeners();
  }

  /// Toggles Data Saver Mode: when enabled, bypasses cloud network and uses 0KB data with low battery drain
  void toggleDataSaverMode() {
    _dataSaverMode = !_dataSaverMode;
    notifyListeners();
  }

  /// Sets an auto-off Sleep Timer (e.g. 10, 20, 30 minutes) to protect battery when studying in bed
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;
    notifyListeners();

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      stop();
      _sleepTimerMinutes = null;
      notifyListeners();
    });
  }

  /// Cancels active sleep timer
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerMinutes = null;
    notifyListeners();
  }

  /// Binds Lockscreen Audio Handler and synchronizes media notifications
  void setAudioHandler(StudyAudioHandler handler) {
    _audioHandler = handler;
    handler.onSkipNextRequested = () => nextChunk();
    handler.onSkipPreviousRequested = () => previousChunk();
    handler.onPlayRequested = () => resume();
    handler.onPauseRequested = () => pause();
    handler.onStopRequested = () => stop();
    handler.onPlaybackCompleted = () => _onChunkCompleted();
  }

  bool _isAudioHandlerInitializing = false;

  /// Lazy-initializes AudioService on mobile platforms only on-demand when student starts playback.
  /// This completely eliminates cold boot crashes on Android 14 / Vivo devices and saves 50-70MB RAM.
  Future<void> ensureAudioHandlerInitialized() async {
    if (_audioHandler != null || _isAudioHandlerInitializing) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _isAudioHandlerInitializing = true;
    try {
      final handler = await AudioService.init(
        builder: () => StudyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.studysilo.app.audio',
          androidNotificationChannelName: 'StudySilo AI Masterclass',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      setAudioHandler(handler);
    } catch (e) {
      debugPrint('Lazy AudioService init notice: $e');
    } finally {
      _isAudioHandlerInitializing = false;
    }
  }

  String _getPersonaDisplayName() {
    return 'Priya Ma\'am (Studio Neural)';
  }

  // Real-Time Karaoke & Progress Getters
  int get currentChunkIndex => _currentChunkIndex;
  int get totalChunks => _chunks.length;
  List<SpokenChunk> get chunks => List.unmodifiable(_chunks);
  bool get hasNextChunk => _chunks.isNotEmpty && _currentChunkIndex < _chunks.length - 1;
  bool get hasPreviousChunk => _chunks.isNotEmpty && _currentChunkIndex > 0;
  double get progress => _chunks.isEmpty ? 0.0 : (_currentChunkIndex + 1) / _chunks.length;
  String get currentRawSentence => (_currentChunkIndex < _chunks.length) ? _chunks[_currentChunkIndex].rawText : '';
  String get currentSpokenChunk => (_currentChunkIndex < _chunks.length) ? _chunks[_currentChunkIndex].spokenText : '';

  @visibleForTesting
  void setTestingState({
    TtsState state = TtsState.playing,
    List<SpokenChunk>? chunks,
    int chunkIndex = 0,
  }) {
    _state = state;
    if (chunks != null) _chunks = chunks;
    _currentChunkIndex = chunkIndex;
    notifyListeners();
  }

  void _initTts() {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      _flutterTts.setStartHandler(() {
        _state = TtsState.playing;
        notifyListeners();
      });

      _flutterTts.setCompletionHandler(() {
        _onChunkCompleted();
      });

      _flutterTts.setCancelHandler(() {
        if (!_isNavigating) {
          _state = TtsState.stopped;
          notifyListeners();
        }
      });

      _flutterTts.setPauseHandler(() {
        _state = TtsState.paused;
        notifyListeners();
      });

      _flutterTts.setContinueHandler(() {
        _state = TtsState.playing;
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('FlutterTts ErrorHandler: $msg');
        if (!_isNavigating) {
          _onChunkCompleted();
        }
      });

      if (kIsWeb) {
        _webPlayer.setLoopMode(LoopMode.off);
        _webPlayer.playerStateStream.listen((playerState) {
          if (playerState.processingState == ProcessingState.completed &&
              !_isNavigating &&
              _state == TtsState.playing) {
            _onChunkCompleted();
          }
        });
      }

      _configureSweetVoice();
    } catch (e) {
      debugPrint('AiTtsService initialization notice: $e');
    }
  }

  Future<void> setPersona(VoicePersona p) async {
    if (_persona == p) return;
    _persona = p;
    notifyListeners();
    await _configureSweetVoice();

    // Immediately switch voice on active sentence without stutter or lag
    if (_state == TtsState.playing && _chunks.isNotEmpty && _currentChunkIndex < _chunks.length) {
      _isNavigating = true;
      if (kIsWeb) {
        try {
          await _webPlayer.stop();
        } catch (_) {}
      }
      try {
        await _audioHandler?.stop();
      } catch (_) {}
      try {
        await _flutterTts.stop();
      } catch (_) {}
      _isNavigating = false;
      await _speakChunk(_chunks[_currentChunkIndex].spokenText);
    }
  }

  /// Configures a sweet, gentle, professional academic voice with warm pitch
  Future<void> _configureSweetVoice([String? sampleText]) async {
    try {
      // 1. Language preference: hi-IN for Hindi script, en-IN for English/Hinglish study terms
      final hasDevanagari = sampleText != null && RegExp(r'[\u0900-\u097F]').hasMatch(sampleText);
      final lang = hasDevanagari ? 'hi-IN' : 'en-IN';
      await _flutterTts.setLanguage(lang);

      // 2. Priya Ma'am: bright, encouraging, warm, sweet teacher tone (pitch 1.02)
      const double targetPitch = 1.02;
      await _flutterTts.setPitch(targetPitch);

      // 3. Energetic, human-like speech tempo: 0.48 gives crisp, natural, and articulate teacher cadence
      final baseRate = kIsWeb ? 0.92 : 0.48;
      await _flutterTts.setSpeechRate(baseRate * _speechRate);
      await _flutterTts.setVolume(1.0);

      // 4. Intelligent Neural Voice Selector: prioritizes Google's Neural2 and Studio network voices
      if (!kIsWeb) {
        if (_cachedVoices == null) {
          try {
            final voices = await _flutterTts.getVoices;
            if (voices is List) {
              _cachedVoices = voices;
            }
          } catch (_) {}
        }

        if (_cachedVoices != null && _cachedVoices!.isNotEmpty) {
          Map? bestVoice = _personaVoiceMap[_persona];
          if (bestVoice == null) {
            int bestScore = -100;
            for (final v in _cachedVoices!) {
              if (v is Map) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                int score = 0;

                // Locale matching
                final isTargetLang = locale.contains('en-in') || locale.contains('en_in') || locale.contains('hi-in') || locale.contains('hi_in');
                if (isTargetLang) {
                  score += 60;
                } else if (locale.contains('en-gb') || locale.contains('en-us')) {
                  score += 20;
                } else {
                  continue;
                }

                // Google Cloud Studio & Neural2 high-fidelity voices
                if (name.contains('neural2') || name.contains('studio')) {
                  score += 130;
                } else if (name.contains('network') || name.contains('neural') || name.contains('wavenet') || name.contains('natural')) {
                  score += 100;
                }
                if (name.contains('local') || name.contains('compact') || name.contains('low')) {
                  score -= 50;
                }

                // Gender / Timbre preference: Prioritize Indian Female teacher voices
                if (name.contains('female') || name.contains('cfl') || name.contains('end') || name.contains('ene') || name.contains('hie')) {
                  score += 50;
                } else if (name.contains('male')) {
                  score -= 60;
                }

                if (score > bestScore) {
                  bestScore = score;
                  bestVoice = v;
                }
              }
            }
            if (bestVoice != null) {
              _personaVoiceMap[_persona] = bestVoice;
            }
          }

          if (bestVoice != null) {
            await _flutterTts.setVoice({
              'name': bestVoice['name'],
              'locale': bestVoice['locale'],
            });
          }
        }
      }
    } catch (e) {
      debugPrint('AiTtsService configure voice fallback: $e');
    }
  }

  /// Sets playback speed multiplier (1.0x, 1.25x, 1.5x, 2.0x)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    notifyListeners();

    try {
      if (_usingNeuralEngine) {
        if (kIsWeb) {
          await _webPlayer.setSpeed(_speechRate);
        } else if (_audioHandler != null) {
          await _audioHandler!.internalPlayer.setSpeed(_speechRate);
        }
      }
      final baseRate = kIsWeb ? 0.88 : 0.45;
      await _flutterTts.setSpeechRate(baseRate * _speechRate);
    } catch (_) {}

    if (_state == TtsState.playing && _chunks.isNotEmpty && _currentChunkIndex < _chunks.length) {
      if (!_usingNeuralEngine) {
        _isNavigating = true;
        try {
          await _flutterTts.stop();
        } catch (_) {}
        _isNavigating = false;
        await _speakChunk(_chunks[_currentChunkIndex].spokenText);
      }
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

  // ===========================================================================
  // 🧮 ACADEMIC & LATEX SPOKEN TEXT SANITIZER
  // ===========================================================================

  static (String, int) _extractBracedContent(String s, int startIdx) {
    if (startIdx < 0 || startIdx >= s.length || s[startIdx] != '{') {
      return ('', -1);
    }
    int depth = 0;
    for (int i = startIdx; i < s.length; i++) {
      if (s[i] == '{') {
        depth++;
      } else if (s[i] == '}') {
        depth--;
        if (depth == 0) {
          return (s.substring(startIdx + 1, i), i + 1);
        }
      }
    }
    return ('', -1);
  }

  static String _replaceBalancedFrac(String s) {
    var res = s;
    int limit = 10;
    while (limit > 0) {
      int idx = res.indexOf(r'\frac{');
      if (idx == -1) {
        idx = res.indexOf(r'\frac {');
        if (idx == -1) break;
      }
      int open1 = res.indexOf('{', idx);
      final (num, after1) = _extractBracedContent(res, open1);
      if (after1 == -1) break;
      int open2 = after1;
      while (open2 < res.length && (res[open2] == ' ' || res[open2] == '\t')) {
        open2++;
      }
      if (open2 >= res.length || res[open2] != '{') break;
      final (den, after2) = _extractBracedContent(res, open2);
      if (after2 == -1) break;

      final cleanNum = _replaceBalancedFrac(num);
      final cleanDen = _replaceBalancedFrac(den);
      res = '${res.substring(0, idx)}(${cleanNum.trim()} divided by ${cleanDen.trim()})${res.substring(after2)}';
      limit--;
    }
    return res;
  }

  static String _replaceBalancedSqrt(String s) {
    var res = s;
    int limit = 10;
    while (limit > 0) {
      int idx = res.indexOf(r'\sqrt');
      if (idx == -1) break;
      int afterCmd = idx + 5;
      String rootDegree = '';
      if (afterCmd < res.length && res[afterCmd] == '[') {
        int closeBracket = res.indexOf(']', afterCmd);
        if (closeBracket != -1) {
          rootDegree = res.substring(afterCmd + 1, closeBracket);
          afterCmd = closeBracket + 1;
        }
      }
      while (afterCmd < res.length && (res[afterCmd] == ' ' || res[afterCmd] == '\t')) {
        afterCmd++;
      }
      if (afterCmd < res.length && res[afterCmd] == '{') {
        final (content, afterBrace) = _extractBracedContent(res, afterCmd);
        if (afterBrace != -1) {
          final cleanContent = _replaceBalancedSqrt(content);
          String replacement;
          if (rootDegree == '3' || rootDegree == 'cube') {
            replacement = 'cube root of (${cleanContent.trim()})';
          } else if (rootDegree.isNotEmpty) {
            replacement = '$rootDegree root of (${cleanContent.trim()})';
          } else {
            replacement = 'square root of (${cleanContent.trim()})';
          }
          res = '${res.substring(0, idx)}$replacement${res.substring(afterBrace)}';
          limit--;
          continue;
        }
      }
      res = '${res.substring(0, idx)}square root of ${res.substring(afterCmd)}';
      limit--;
    }
    return res;
  }

  static String _unwrapMacros(String s) {
    var res = s;
    const macros = [
      r'\text{', r'\textbf{', r'\textit{', r'\mathrm{', r'\mathbf{', r'\mathit{',
      r'\operatorname{', r'\cancel{', r'\boxed{', r'\underline{', r'\overline{',
      r'\displaystyle{', r'\large{', r'\huge{', r'\small{', r'\bold{',
    ];
    for (final m in macros) {
      while (true) {
        final idx = res.indexOf(m);
        if (idx == -1) break;
        final openBrace = idx + m.length - 1;
        final (content, after) = _extractBracedContent(res, openBrace);
        if (after == -1) break;
        res = '${res.substring(0, idx)} $content ${res.substring(after)}';
      }
    }
    return res;
  }

  /// Cleans markdown formatting, complex mathematical notation, and LaTeX backslashes
  /// into crystal-clear, sweet, natural spoken English & Hinglish words.
  /// Exactly matches what the student sees on screen with zero leakage of '\' or '$'.
  static String sanitizeTextForSpeech(String text) {
    if (text.trim().isEmpty) return '';
    var s = text;

    // Step 0: Remove Code blocks & JSON diagrams (don't read raw syntax soup)
    s = s.replaceAllMapped(
      RegExp(r'```(?:[a-zA-Z0-9_\-]+)?\n([\s\S]*?)```'),
      (m) => ' Here is the code implementation. ',
    );

    // Step 0.3: 🛡️ STRIP MARKDOWN BLOCKQUOTES (Never say 'greater than' for quotes)
    s = s.replaceAll(RegExp(r'^\s*>+\s*(?:\[[!a-zA-Z_\-]+\])?\s*', multiLine: true), '');

    // Step 0.5: 🎓 PEDAGOGICAL PAUSES & STEP BOUNDARIES (Mimics real human teacher cadence)
    s = s.replaceAllMapped(RegExp(r'\bStep\s*([0-9]+)\s*:\s*', caseSensitive: false), (m) => '. Step ${m.group(1)}. ');
    s = s.replaceAllMapped(RegExp(r'\b(Therefore|Hence|Furthermore|In other words|Notice that|Keep in mind|Remember|Specifically|First|Secondly|Finally)\s*:\s*', caseSensitive: false), (m) => '${m.group(1)}, ');

    // Step 0.8: 📖 ACADEMIC & TEXT ABBREVIATIONS EXPANSION
    s = s.replaceAll(RegExp(r'\b(?:For\s+)?e\.g\.,?\s*|\b(?:For\s+)?eg\.,?\s*', caseSensitive: false), 'for example, ')
         .replaceAll(RegExp(r'\bi\.e\.,?\s*|\bie\.,?\s*', caseSensitive: false), 'that is, ')
         .replaceAll(RegExp(r'\bw\.r\.t\.?\s*|\bwrt\s*', caseSensitive: false), 'with respect to ')
         .replaceAll(RegExp(r'\betc\.\s*|\betc\b', caseSensitive: false), 'etcetera ')
         .replaceAll(RegExp(r'\bvs\.?\s*|\bversus\s*', caseSensitive: false), 'versus ')
         .replaceAll(RegExp(r'\bapprox\b\.?\s*', caseSensitive: false), 'approximately ')
         .replaceAll(RegExp(r'\biff\b', caseSensitive: false), 'if and only if')
         .replaceAll(RegExp(r'\bviz\.?\s*', caseSensitive: false), 'namely ')
         .replaceAll(RegExp(r'\beqn\.?\s*|\beq\.?\s*', caseSensitive: false), 'equation ')
         .replaceAll(RegExp(r'\bfig\.?\s*|\bfigs\.?\s*', caseSensitive: false), 'figure ')
         .replaceAll(RegExp(r'\bsoln\.?\s*|\bsol\.?\s*', caseSensitive: false), 'solution ')
         .replaceAll(RegExp(r'\bmax\.?\s*', caseSensitive: false), 'maximum ')
         .replaceAll(RegExp(r'\bmin\.?\s*', caseSensitive: false), 'minimum ')
         .replaceAll(RegExp(r'\bavg\.?\s*', caseSensitive: false), 'average ')
         .replaceAll(RegExp(r'\bconst\.?\s*', caseSensitive: false), 'constant ')
         .replaceAll(RegExp(r'\btemp\.?\s*', caseSensitive: false), 'temperature ')
         .replaceAll(RegExp(r'\bdiff\.?\s*', caseSensitive: false), 'differentiation ')
         .replaceAll(RegExp(r'\bvol\.?\s*', caseSensitive: false), 'volume ')
         .replaceAll(RegExp(r'\bwt\.?\s*', caseSensitive: false), 'weight ');

    // Step 1: Transform Markdown Tables into clean natural sentences
    s = s.replaceAll(RegExp(r'\|[-:\s|]+\|'), ' ');
    s = s.replaceAll('|', ', ');

    // Step 1.1: 📐 STRIP LATEX ENVIRONMENTS & NEWLINES
    s = s.replaceAll(RegExp(r'\\(?:begin|end)\{[a-zA-Z0-9*]+\}'), '');
    s = s.replaceAll(r'\\', '. ');
    s = s.replaceAll('&=', ' = ');
    s = s.replaceAll('&', ' ');

    // Step 1.2: 📦 UNWRAP LATEX MACROS (\text{...}, \mathrm{...}, \boxed{...}, etc.)
    s = _unwrapMacros(s);

    // Step 1.3: ➗ BALANCED BRACE FRACTIONS & SQUARE ROOTS (zero regex recursion limit)
    s = _replaceBalancedFrac(s);
    s = _replaceBalancedSqrt(s);

    // Step 1.5: 📐 COMMON SIMPLE FRACTIONS & PERCENTAGES
    s = s.replaceAll(RegExp(r'\b1/2\b'), 'one half')
         .replaceAll(RegExp(r'\b1/4\b'), 'one fourth')
         .replaceAll(RegExp(r'\b3/4\b'), 'three fourths')
         .replaceAll(RegExp(r'\b1/3\b'), 'one third')
         .replaceAll(RegExp(r'\b2/3\b'), 'two thirds')
         .replaceAllMapped(RegExp(r'([0-9.]+)\s*%'), (m) => '${m.group(1)} percent');

    // Step 2: Expand Higher-Level Calculus & Math Constructs to natural words before symbol conversion
    s = s.replaceAllMapped(RegExp(r'\\lim_\{([^}]+)\}'), (m) {
      final cond = m.group(1)!
          .replaceAll(r'\to', ' approaches ')
          .replaceAll(r'\rightarrow', ' approaches ')
          .replaceAll('→', ' approaches ');
      return 'limit as $cond of ';
    });
    s = s.replaceAll(r'\lim', 'limit of ');

    s = s.replaceAllMapped(RegExp(r'\\int_\{([^}]+)\}\^\{([^}]+)\}'), (m) => 'definite integral from ${m.group(1)} to ${m.group(2)} of ');
    s = s.replaceAllMapped(RegExp(r'\\int_([0-9a-zA-Z])\^([0-9a-zA-Z])'), (m) => 'definite integral from ${m.group(1)} to ${m.group(2)} of ');
    s = s.replaceAll(r'\iint', 'double integral of ');
    s = s.replaceAll(r'\iiint', 'triple integral of ');
    s = s.replaceAll(r'\oint', 'contour integral of ');
    s = s.replaceAll(r'\int', 'integral of ');

    s = s.replaceAllMapped(RegExp(r'\\sum_\{([^}]+)\}\^\{([^}]+)\}'), (m) => 'summation from ${m.group(1)} to ${m.group(2)} of ');
    s = s.replaceAllMapped(RegExp(r'\\sum_([0-9a-zA-Z])\^([0-9a-zA-Z])'), (m) => 'summation from ${m.group(1)} to ${m.group(2)} of ');
    s = s.replaceAll(r'\sum', 'summation of ');
    s = s.replaceAll(r'\prod', 'product of ');

    s = s.replaceAll(r'\partial', 'partial derivative of ');
    s = s.replaceAll(r'\nabla', 'del ');

    // Trigonometric & Logarithmic Powers
    s = s.replaceAllMapped(RegExp(r'\\ln\s*\(?([^)\s]+)\)?'), (m) => 'natural log of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\log_\{?10\}?\s*\(?([^)\s]+)\)?'), (m) => 'log base 10 of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\log_\{?2\}?\s*\(?([^)\s]+)\)?'), (m) => 'log base 2 of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\sin\^2\s*([a-zA-Z0-9\\]+)'), (m) => 'sine squared of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\cos\^2\s*([a-zA-Z0-9\\]+)'), (m) => 'cosine squared of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\tan\^2\s*([a-zA-Z0-9\\]+)'), (m) => 'tangent squared of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\tan\^\{-1\}\s*\(?([^)\s]+)\)?'), (m) => 'inverse tangent of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\sin\^\{-1\}\s*\(?([^)\s]+)\)?'), (m) => 'inverse sine of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\\cos\^\{-1\}\s*\(?([^)\s]+)\)?'), (m) => 'inverse cosine of ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'10\^\{?(-?[0-9]+)\}?'), (m) => '10 to the power ${m.group(1)} ');

    // Physics Subscript Variables
    s = s.replaceAll(RegExp(r'\bv_0\b|\bv_o\b'), 'v naught')
         .replaceAll(RegExp(r'\bv_i\b'), 'v initial')
         .replaceAll(RegExp(r'\bv_f\b'), 'v final')
         .replaceAll(RegExp(r'\bx_0\b'), 'x naught')
         .replaceAll(RegExp(r'\bt_0\b'), 't naught')
         .replaceAll(RegExp(r'\ba_\{?net\}?\b'), 'a net')
         .replaceAll(RegExp(r'\bF_\{?net\}?\b'), 'F net')
         .replaceAll(RegExp(r'\bm_\{?total\}?\b'), 'total mass')
         .replaceAll(RegExp(r'\bk_\{?B\}?\b'), 'Boltzmann constant k B');

    // Vectors and Unit Vectors
    s = s.replaceAllMapped(RegExp(r'\\vec\{?([a-zA-Z0-9]+)\}?'), (m) => 'vector ${m.group(1)} ');
    s = s.replaceAll(r'\hat{i}', 'unit vector i ');
    s = s.replaceAll(r'\hat{j}', 'unit vector j ');
    s = s.replaceAll(r'\hat{k}', 'unit vector k ');

    // Algorithmic Complexity (Big-O) & Computer Science Terms
    s = s.replaceAllMapped(RegExp(r'O\(\s*(?:\\log|log)\s*N\s*\)', caseSensitive: false), (_) => 'O of log N logarithmic time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*N\s*(?:\\log|log)\s*N\s*\)', caseSensitive: false), (_) => 'O of N log N linearithmic time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*1\s*\)', caseSensitive: false), (_) => 'O of 1 constant time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*N\s*\)', caseSensitive: false), (_) => 'O of N linear time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*N\s*\^?\s*2\s*\)', caseSensitive: false), (_) => 'O of N squared quadratic time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*2\s*\^\s*[nN]\s*\)', caseSensitive: false), (_) => 'O of 2 to the power n exponential time');
    s = s.replaceAllMapped(RegExp(r'O\(\s*[nN]!\s*\)', caseSensitive: false), (_) => 'O of n factorial time');

    // Factorials for general math terms
    s = s.replaceAllMapped(RegExp(r'([0-9a-zA-Z])!'), (m) => '${m.group(1)} factorial');

    // CS Data Structures and Acronyms
    s = s.replaceAllMapped(RegExp(r'\barr\[([a-zA-Z0-9_]+)\]'), (m) => 'array at index ${m.group(1)} ')
         .replaceAllMapped(RegExp(r'\bmatrix\[([a-zA-Z0-9_]+)\]\[([a-zA-Z0-9_]+)\]'), (m) => 'matrix at row ${m.group(1)}, column ${m.group(2)} ')
         .replaceAll(RegExp(r'\bAPI\b'), 'A P I')
         .replaceAll(RegExp(r'\bREST\b'), 'Rest')
         .replaceAll(RegExp(r'\bSDK\b'), 'S D K')
         .replaceAll(RegExp(r'\bCPU\b'), 'C P U')
         .replaceAll(RegExp(r'\bRAM\b'), 'R A M')
         .replaceAll(RegExp(r'\bROM\b'), 'R O M')
         .replaceAll(RegExp(r'\bSQL\b'), 'Sequel')
         .replaceAll(RegExp(r'\bOOP\b'), 'Object Oriented Programming')
         .replaceAll(RegExp(r'\bBFS\b'), 'Breadth First Search, B F S')
         .replaceAll(RegExp(r'\bDFS\b'), 'Depth First Search, D F S')
         .replaceAll(RegExp(r'\bDP\b'), 'Dynamic Programming, D P');

    // Chemical Reaction Arrows & Equilibria
    s = s.replaceAllMapped(RegExp(r'\\xrightarrow\{\\Delta\}', caseSensitive: false), (_) => ' reacts under heat to form ');
    s = s.replaceAllMapped(RegExp(r'\\xrightarrow\{heat\}', caseSensitive: false), (_) => ' reacts under heat to form ');
    s = s.replaceAllMapped(RegExp(r'\\xrightarrow\{h\\nu\}', caseSensitive: false), (_) => ' reacts under ultraviolet light to form ');
    s = s.replaceAllMapped(RegExp(r'\\xrightarrow\{([^}]+)\}', caseSensitive: false), (m) => ' reacts over ${m.group(1)} to form ');
    s = s.replaceAll(r'\rightleftharpoons', ' is in dynamic reversible equilibrium with ')
         .replaceAll('⇌', ' is in dynamic reversible equilibrium with ')
         .replaceAll(r'\rightleftarrows', ' is in dynamic reversible equilibrium with ');

    // Chemical Physical States: (aq), (s), (l), (g)
    s = s.replaceAllMapped(RegExp(r'\((aq|s|l|g)\)', caseSensitive: false), (m) {
      switch (m.group(1)!.toLowerCase()) {
        case 'aq': return ' aqueous ';
        case 's': return ' solid ';
        case 'l': return ' liquid ';
        case 'g': return ' gas ';
        default: return m.group(0)!;
      }
    });

    // Common Chemistry Compounds & Biological Molecules (Natural spoken names)
    s = s.replaceAll(RegExp(r'\bCaCO_?3\b'), 'calcium carbonate')
         .replaceAll(RegExp(r'\bCaO\b'), 'calcium oxide')
         .replaceAll(RegExp(r'\bNaCl\b'), 'sodium chloride')
         .replaceAll(RegExp(r'\bHCl\b'), 'hydrochloric acid')
         .replaceAll(RegExp(r'\bH2SO4\b|\bH_2SO_4\b'), 'sulfuric acid')
         .replaceAll(RegExp(r'\bHNO3\b|\bHNO_3\b'), 'nitric acid')
         .replaceAll(RegExp(r'\bNaOH\b'), 'sodium hydroxide')
         .replaceAll(RegExp(r'\bKOH\b'), 'potassium hydroxide')
         .replaceAll(RegExp(r'\bCH4\b|\bCH_4\b'), 'methane')
         .replaceAll(RegExp(r'\bNH3\b|\bNH_3\b'), 'ammonia')
         .replaceAll(RegExp(r'\bCO[\s_]*2\b', caseSensitive: false), 'carbon dioxide')
         .replaceAll(RegExp(r'\bH[\s_]*2[\s_]*O\b', caseSensitive: false), 'water')
         .replaceAll(RegExp(r'\bATP\b'), 'A T P')
         .replaceAll(RegExp(r'\bDNA\b'), 'D N A')
         .replaceAll(RegExp(r'\bRNA\b'), 'R N A');

    // Physics SI Units & Scientific Dimensions
    s = s.replaceAll(RegExp(r'\b(?:m/s\^?2|m/s²|m\s*s\^?-2)\b'), ' meters per second squared ')
         .replaceAll(RegExp(r'\bm/s\b'), ' meters per second ')
         .replaceAll(RegExp(r'\bkm/h\b'), ' kilometers per hour ')
         .replaceAll(RegExp(r'(?:\\mu|µ|u)\s*F\b'), ' microfarads ')
         .replaceAll(RegExp(r'\bpF\b'), ' picofarads ')
         .replaceAll(RegExp(r'\bnF\b'), ' nanofarads ')
         .replaceAll(RegExp(r'(?:k\\Omega|kΩ)\b'), ' kiloohms ')
         .replaceAll(RegExp(r'(?:M\\Omega|MΩ)\b'), ' megaohms ')
         .replaceAll(RegExp(r'(?:\\Omega|Ω)\b'), ' ohms ')
         .replaceAll(RegExp(r'\bkJ/mol\b'), ' kilojoules per mole ')
         .replaceAll(RegExp(r'\bJ/mol\b'), ' joules per mole ')
         .replaceAll(RegExp(r'\bkcal/mol\b'), ' kilocalories per mole ')
         .replaceAll(RegExp(r'\bN\s*m\b'), ' newton meters ')
         .replaceAll(RegExp(r'\brad/s\b'), ' radians per second ')
         .replaceAll(RegExp(r'\bmol/L\b'), ' moles per liter ')
         .replaceAll(RegExp(r'\bkg/m\^?3\b'), ' kilograms per cubic meter ')
         .replaceAll(RegExp(r'\bg/cm\^?3\b'), ' grams per cubic centimeter ')
         .replaceAll(RegExp(r'°C|\\circ\s*C'), ' degrees Celsius ')
         .replaceAll(RegExp(r'°F|\\circ\s*F'), ' degrees Fahrenheit ')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:W|watts?)\b'), (m) => '${m.group(1)} watts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kW\b'), (m) => '${m.group(1)} kilowatts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*MW\b'), (m) => '${m.group(1)} megawatts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:J|joules?)\b'), (m) => '${m.group(1)} joules')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kJ\b'), (m) => '${m.group(1)} kilojoules')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:N|newtons?)\b'), (m) => '${m.group(1)} newtons')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kN\b'), (m) => '${m.group(1)} kilonewtons')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:Hz|hertz)\b'), (m) => '${m.group(1)} hertz')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kHz\b'), (m) => '${m.group(1)} kilohertz')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*MHz\b'), (m) => '${m.group(1)} megahertz')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*GHz\b'), (m) => '${m.group(1)} gigahertz')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:V|volts?)\b'), (m) => '${m.group(1)} volts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*mV\b'), (m) => '${m.group(1)} millivolts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kV\b'), (m) => '${m.group(1)} kilovolts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:A|amps?|amperes?)\b'), (m) => '${m.group(1)} amperes')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*mA\b'), (m) => '${m.group(1)} milliamperes')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:T|teslas?)\b'), (m) => '${m.group(1)} teslas')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*(?:Pa|pascals?)\b'), (m) => '${m.group(1)} pascals')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kPa\b'), (m) => '${m.group(1)} kilopascals')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*MPa\b'), (m) => '${m.group(1)} megapascals')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*atm\b'), (m) => '${m.group(1)} atmospheres')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*eV\b'), (m) => '${m.group(1)} electron volts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*MeV\b'), (m) => '${m.group(1)} mega electron volts')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*cal\b'), (m) => '${m.group(1)} calories')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kcal\b'), (m) => '${m.group(1)} kilocalories')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*cm\b'), (m) => '${m.group(1)} centimeters')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*mm\b'), (m) => '${m.group(1)} millimeters')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*nm\b'), (m) => '${m.group(1)} nanometers')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*kg\b'), (m) => '${m.group(1)} kilograms')
         .replaceAllMapped(RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\s*mg\b'), (m) => '${m.group(1)} milligrams');

    // Common words with backslash
    s = s.replaceAll(RegExp(r'\\example\b', caseSensitive: false), 'example')
         .replaceAll(RegExp(r'\\cent\b'), 'cents');

    // Step 3: ✨ RUN THROUGH UNIVERSAL FORMATTER (LatexSanitizer.clean)
    // Converts fractions to (a / b), roots to √(x), Greek symbols to Unicode,
    // and UNIVERSALLY strips all raw backslashes and LaTeX formatting!
    s = LatexSanitizer.clean(s);

    // Step 4: Convert the Clean Visible Unicode Symbols into Smooth Spoken Words
    // Fractions from (a / b) -> "a divided by b"
    s = s.replaceAllMapped(RegExp(r'\(([^()]+)\s*/\s*([^()]+)\)'), (m) => '${m.group(1)} divided by ${m.group(2)}');

    // Square roots: √(x) -> "square root of x"
    s = s.replaceAllMapped(RegExp(r'√\(([^()]+)\)'), (m) => 'square root of ${m.group(1)}');
    s = s.replaceAll('√', 'square root of ');

    // Unicode Greek letters to spoken English names
    const unicodeGreek = {
      'α': 'alpha', 'β': 'beta', 'γ': 'gamma', 'Γ': 'Gamma',
      'δ': 'delta', 'Δ': 'delta', 'ε': 'epsilon',
      'ζ': 'zeta', 'η': 'eta', 'θ': 'theta', 'Θ': 'Theta',
      'ι': 'iota', 'κ': 'kappa', 'λ': 'lambda', 'Λ': 'Lambda',
      'μ': 'mu', 'ν': 'nu', 'ξ': 'xi', 'Ξ': 'Xi',
      'π': 'pi', 'Π': 'Pi', 'ρ': 'rho', 'σ': 'sigma', 'Σ': 'Sigma',
      'τ': 'tau', 'υ': 'upsilon', 'ϕ': 'phi', 'φ': 'phi', 'Φ': 'Phi',
      'χ': 'chi', 'ψ': 'psi', 'Ψ': 'Psi', 'ω': 'omega', 'Ω': 'Omega',
    };
    unicodeGreek.forEach((k, v) {
      s = s.replaceAll(k, ' $v ');
    });

    // Unicode Mathematical Operators & Relations
    const unicodeOps = {
      '×': ' multiplied by ',
      '·': ' times ',
      '÷': ' divided by ',
      '±': ' plus or minus ',
      '∓': ' minus or plus ',
      '≤': ' is less than or equal to ',
      '≥': ' is greater than or equal to ',
      '≠': ' is not equal to ',
      '≈': ' is approximately equal to ',
      '≡': ' is equivalent to ',
      '∝': ' is proportional to ',
      '∼': ' is similar to ',
      '∞': ' infinity ',
      '→': ' leads to ',
      '←': ' is from ',
      '⇒': ' which implies that ',
      '⇐': ' is implied by ',
      '⇔': ' if and only if ',
      '∈': ' belongs to ',
      '∉': ' does not belong to ',
      '⊂': ' is a subset of ',
      '⊆': ' is a subset of or equal to ',
      '∪': ' union ',
      '∩': ' intersection ',
      '∴': ' therefore ',
      '∵': ' because ',
      '⊥': ' is perpendicular to ',
      '∥': ' is parallel to ',
      '°': ' degrees ',
      '∂': ' partial derivative of ',
      '∇': ' del ',
    };
    unicodeOps.forEach((k, v) {
      s = s.replaceAll(k, v);
    });

    // Superscripts Unicode: x² -> x squared, x³ -> x cubed
    s = s.replaceAll('²', ' squared ')
         .replaceAll('³', ' cubed ')
         .replaceAll('⁰', ' to the power 0 ')
         .replaceAll('¹', ' to the power 1 ')
         .replaceAll('⁴', ' to the power 4 ')
         .replaceAll('⁵', ' to the power 5 ')
         .replaceAll('⁶', ' to the power 6 ')
         .replaceAll('⁷', ' to the power 7 ')
         .replaceAll('⁸', ' to the power 8 ')
         .replaceAll('⁹', ' to the power 9 ')
         .replaceAll('ⁿ', ' to the power n ');

    // Subscripts Unicode: x₁ -> x 1, y₀ -> y 0, CO₂ -> C O 2, H₂O -> H 2 O
    s = s.replaceAll('₀', ' 0 ')
         .replaceAll('₁', ' 1 ')
         .replaceAll('₂', ' 2 ')
         .replaceAll('₃', ' 3 ')
         .replaceAll('₄', ' 4 ')
         .replaceAll('₅', ' 5 ')
         .replaceAll('₆', ' 6 ')
         .replaceAll('₇', ' 7 ')
         .replaceAll('₈', ' 8 ')
         .replaceAll('₉', ' 9 ');

    // Chemistry formulas: CO2 or H2O
    s = s.replaceAll(RegExp(r'\bCO[\s_]*2\b', caseSensitive: false), 'CO 2')
         .replaceAll(RegExp(r'\bH[\s_]*2[\s_]*O\b', caseSensitive: false), 'H 2 O');

    // Step 5: Clean Markdown Headers, Bold, Italic & Lists
    s = s.replaceAll(RegExp(r'#{1,6}\s*'), '. ');
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'==([^=]+)=='), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'<mark>([\s\S]*?)</mark>', caseSensitive: false), (m) => m.group(1)!);
    s = s.replaceAll('**', '').replaceAll('__', '');
    // Natural human numbered point cadence: "Point 1: ... Point 2: ..."
    s = s.replaceAllMapped(RegExp(r'^\s*([0-9]+)\.\s+', multiLine: true), (m) => '. Point ${m.group(1)}: ');
    s = s.replaceAll(RegExp(r'^[•\-*]\s+', multiLine: true), '. ');

    // Step 6: Convert Visual Emojis into polite human spoken cues
    s = s.replaceAll('💡', '. Pro tip: ')
         .replaceAll('⚠️', '. Watch out, exam trap warning: ')
         .replaceAll('🎯', '. Key exam takeaway: ')
         .replaceAll('🧠', '. Intuition: ')
         .replaceAll('📌', '. Key concept: ')
         .replaceAll('✅', '. Correct: ')
         .replaceAll('❌', '. Misconception: ');

    // Step 7: 🛡️ ZERO LEAKAGE ABSOLUTE GUARDS
    // Positively strip ANY remaining '$', '\', braces '{}', or brackets '[]' so TTS can NEVER say "dollar" or "backslash"!
    s = s.replaceAll(r'$', ' ')
         .replaceAll(r'\', ' ')
         .replaceAll('{', ' ')
         .replaceAll('}', ' ')
         .replaceAll('[', ' ')
         .replaceAll(']', ' ')
         .replaceAll('~', ' ')
         .replaceAll('^', ' to the power of ')
         .replaceAll('_', ' ');

    // Step 8: Normalize spaces and multiple punctuation marks
    s = s.replaceAll(RegExp(r'\s+'), ' ')
         .replaceAll(RegExp(r'\s*,\s*'), ', ')
         .replaceAll(RegExp(r'\.{2,}'), '.')
         .trim();

    return s;
  }

  // ===========================================================================
  // 🔊 AUDIO PLAYBACK & CHUNKING ENGINE
  // ===========================================================================

  /// Speaks a crisp, high-value 20-30 second Audio Note (~200-300 characters).
  /// Generates in ~0.5s with zero server strain, providing instant clarity to students.
  Future<void> speakSummary(String text, {String? precomputedSummary}) async {
    final summary = (precomputedSummary != null && precomputedSummary.trim().isNotEmpty)
        ? precomputedSummary.trim()
        : extractQuickAudioSummary(text);
    if (summary.isEmpty) return;

    await speak(text, precomputedSpokenTranscript: summary, isSummaryMode: true);
  }

  /// Extracts the essential 1-2 sentence core insight for quick voice notes
  static String extractQuickAudioSummary(String text) {
    final clean = sanitizeTextForSpeech(text);
    if (clean.length <= 320) return clean;

    final match = RegExp(r'^.*?[.!?](?:\s+.*?[.!?])?').firstMatch(clean);
    if (match != null && match.group(0) != null && match.group(0)!.trim().length > 30) {
      return match.group(0)!.trim();
    }
    return '${clean.substring(0, 280).trim()}...';
  }

  static final Set<int> _prewarmedHashes = {};

  /// Silently pre-warms / caches audio in the background for a given text so when user presses play, it starts in 0ms.
  void prewarm(String text, {bool isSummary = false}) {
    if (text.trim().isEmpty) return;
    final hash = text.hashCode ^ (isSummary ? 1 : 0);
    if (_prewarmedHashes.contains(hash)) return;
    _prewarmedHashes.add(hash);
    unawaited(_cloudNeuralTts.prewarmAudio(text, isSummary: isSummary));
  }

  /// Speaks the solution aloud using high-fidelity TTS
  /// If precomputedSpokenTranscript is provided by the Go backend, it avoids executing heavy client regex on low-end phones!
  Future<void> speak(String text, {String? precomputedSpokenTranscript, bool isSummaryMode = false}) async {
    final clean = (precomputedSpokenTranscript != null && precomputedSpokenTranscript.trim().isNotEmpty)
        ? precomputedSpokenTranscript.trim()
        : sanitizeTextForSpeech(text);
    if (clean.isEmpty) return;

    unawaited(ensureAudioHandlerInitialized());
    _currentText = text;
    _state = TtsState.playing;
    _currentChunkIndex = 0;

    // ⚡ 0ms Instant Replay: check local memory and disk cache first
    final cacheKey = isSummaryMode ? '${text}_summary' : text;
    final cached = await AiAudioCacheService().getCachedChunks(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _chunks = cached;
    } else {
      _chunks = isSummaryMode
          ? [SpokenChunk(rawText: text, spokenText: clean)]
          : _splitIntoSpokenChunks(text, precomputedSpokenText: clean);
      unawaited(AiAudioCacheService().cacheChunks(cacheKey, _chunks));
    }
    notifyListeners();

    if (_chunks.isNotEmpty) {
      await _speakChunk(_chunks[0].spokenText, isSummaryMode: isSummaryMode);
    } else {
      _state = TtsState.stopped;
      notifyListeners();
    }
  }

  /// Generates the explanation as ONE unified, continuous audio track.
  /// This completely eliminates micro-chunking, stops all awkward pauses,
  /// and delivers 100% fluent, smooth teacher speech without interruption.
  static List<SpokenChunk> _splitIntoSpokenChunks(String text, {String? precomputedSpokenText}) {
    final clean = (precomputedSpokenText != null && precomputedSpokenText.trim().isNotEmpty)
        ? precomputedSpokenText.trim()
        : sanitizeTextForSpeech(text);
    if (clean.isEmpty) return [];

    return [SpokenChunk(rawText: text, spokenText: clean)];
  }

  Future<void> _speakChunk(String chunk, {bool isSummaryMode = false}) async {
    try {
      if (_state != TtsState.playing) return;

      _isLoading = true;
      notifyListeners();

      // 1. Data Saver Mode: If student prefers offline speech to save 100% data
      if (_dataSaverMode) {
        _isLoading = false;
        _usingNeuralEngine = false;
        await _configureSweetVoice(chunk);
        await _flutterTts.speak(chunk);
        notifyListeners();
        return;
      }

      // 2. Online Cloud Voice Engine: Studio Priya Female Voice (hi-IN-SwaraNeural)
      String? neuralAudioPath;
      try {
        neuralAudioPath = await _cloudNeuralTts
            .synthesizeNeuralAudioWithOpt(
              chunk,
              persona: VoicePersona.priya,
              isSummary: isSummaryMode,
            )
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
      } catch (err) {
        debugPrint('Cloud audio attempt notice: $err');
      }

      if (_state != TtsState.playing) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (!kIsWeb && _audioHandler == null) {
        await ensureAudioHandlerInitialized();
      }

      if (neuralAudioPath != null && (kIsWeb || _audioHandler != null)) {
        _usingNeuralEngine = true;

        if (kIsWeb) {
          try {
            _isNavigating = true;
            await _webPlayer.stop(); // Reset processing state to idle to prevent duplicate completed events
            await _webPlayer.setLoopMode(LoopMode.off); // Strict LoopMode.off enforcement
            await _webPlayer.setSpeed(_speechRate);
            await _webPlayer.setUrl(neuralAudioPath);
            _isNavigating = false;
            _isLoading = false;
            notifyListeners();
            await _webPlayer.play();
            return;
          } catch (e) {
            _isNavigating = false;
            debugPrint('Web audio playback notice: $e');
          }
        } else if (_audioHandler != null) {
          // Studio Indian Female voice natural warm pitch
          await _audioHandler!.internalPlayer.setPitch(1.0);
          await _audioHandler!.internalPlayer.setSpeed(_speechRate);

          _isLoading = false;
          notifyListeners();

          await _audioHandler!.playAudioSource(
            neuralAudioPath,
            title: isSummaryMode ? 'StudySilo 30s Audio Note' : 'StudySilo Masterclass',
            subtitle: _chunks[_currentChunkIndex].rawText,
            personaName: _getPersonaDisplayName(),
          );
          return;
        }
      }

      _isLoading = false;
      notifyListeners();

      // 3. Fallback when completely offline / without network
      _usingNeuralEngine = false;
      final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(chunk);
      final chunkLang = hasDevanagari ? 'hi-IN' : 'en-IN';
      try {
        await _flutterTts.setLanguage(chunkLang);
      } catch (_) {}
      await _configureSweetVoice();
      await _flutterTts.speak(chunk);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('AiTtsService speak chunk error: $e');
      if (!_isNavigating) {
        _onChunkCompleted();
      }
    }
  }

  void _onChunkCompleted() {
    // Critical: do not advance if user is actively navigating (skip/prev/jump/replay)
    if (_isNavigating) return;
    if (_state != TtsState.playing) return;

    _isNavigating = true; // State guarding: lock immediately to prevent duplicate re-entrancy
    _currentChunkIndex++;
    if (_currentChunkIndex < _chunks.length) {
      notifyListeners();
      _speakChunk(_chunks[_currentChunkIndex].spokenText);
    } else {
      _state = TtsState.stopped;
      _currentChunkIndex = 0;
      _chunks = [];
      _isNavigating = false;
      notifyListeners();

      // Trigger continuous live talk loop callback if active (with 350ms acoustic room decay delay)
      if (_isLiveTalkMode && onLiveTalkCompleted != null) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_isLiveTalkMode && onLiveTalkCompleted != null) {
            onLiveTalkCompleted!();
          }
        });
      }
    }
  }

  /// Pauses ongoing speech with instantaneous optimistic UI update
  Future<void> pause() async {
    if (_state == TtsState.playing) {
      _state = TtsState.paused;
      notifyListeners();

      if (_usingNeuralEngine) {
        if (kIsWeb) {
          try {
            await _webPlayer.pause();
          } catch (_) {}
        } else if (_audioHandler != null) {
          try {
            await _audioHandler!.pause();
          } catch (_) {}
        }
      } else {
        try {
          await _flutterTts.pause();
        } catch (_) {
          try {
            await _flutterTts.stop();
          } catch (_) {}
        }
      }
    }
  }

  /// Resumes speech from pause with 0ms delay
  Future<void> resume() async {
    if (_state == TtsState.paused) {
      _state = TtsState.playing;
      notifyListeners();

      if (_usingNeuralEngine) {
        if (kIsWeb) {
          try {
            await _webPlayer.play();
            return;
          } catch (_) {}
        } else if (_audioHandler != null) {
          try {
            await _audioHandler!.play();
            return;
          } catch (_) {}
        }
      }

      if (_currentChunkIndex < _chunks.length) {
        await _speakChunk(_chunks[_currentChunkIndex].spokenText);
      } else {
        await stop();
      }
    } else if (_currentText.isNotEmpty) {
      await speak(_currentText);
    }
  }

  /// Immediately halts audio playback and resets player state cleanly
  Future<void> stop() async {
    _isNavigating = true;
    cancelSleepTimer();
    _state = TtsState.stopped;
    _isLoading = false;
    _currentChunkIndex = 0;
    _chunks = [];
    notifyListeners();

    if (kIsWeb) {
      try {
        await _webPlayer.stop();
      } catch (_) {}
    }
    try {
      await _audioHandler?.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isNavigating = false;
  }

  /// Jumps directly to a specific sentence chunk with instant optimistic UI response (<5ms)
  Future<void> jumpToChunk(int index) async {
    if (index < 0 || index >= _chunks.length) return;
    _isNavigating = true;

    // Instant UI update
    _currentChunkIndex = index;
    _state = TtsState.playing;
    notifyListeners();

    try {
      await _audioHandler?.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isNavigating = false;

    await _speakChunk(_chunks[_currentChunkIndex].spokenText);
  }

  /// Skips forward to the next sentence chunk
  Future<void> nextChunk() async {
    if (_chunks.isEmpty) return;
    if (_currentChunkIndex < _chunks.length - 1) {
      await jumpToChunk(_currentChunkIndex + 1);
    } else {
      await stop();
    }
  }

  /// Rewinds to the previous sentence chunk (or restarts current chunk if at 0)
  Future<void> previousChunk() async {
    if (_chunks.isEmpty) return;
    if (_currentChunkIndex > 0) {
      await jumpToChunk(_currentChunkIndex - 1);
    } else {
      await replayCurrentChunk();
    }
  }

  /// Replays the current active sentence chunk from the start
  Future<void> replayCurrentChunk() async {
    if (_chunks.isEmpty || _currentChunkIndex >= _chunks.length) return;
    _isNavigating = true;
    _state = TtsState.playing;
    notifyListeners();

    try {
      await _audioHandler?.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isNavigating = false;

    await _speakChunk(_chunks[_currentChunkIndex].spokenText);
  }

  /// Starts speaking from a specific section or heading within a larger text
  Future<void> speakFromSection(String fullText, String targetSection) async {
    final cleanTarget = sanitizeTextForSpeech(targetSection).toLowerCase().trim();
    if (_currentText == fullText && _chunks.isNotEmpty) {
      for (int i = 0; i < _chunks.length; i++) {
        final chunkSpoken = _chunks[i].spokenText.toLowerCase();
        final chunkRaw = _chunks[i].rawText.toLowerCase();
        if (chunkRaw.contains(targetSection.toLowerCase()) ||
            chunkSpoken.contains(cleanTarget)) {
          await jumpToChunk(i);
          return;
        }
      }
    }

    await speak(fullText);
    if (_chunks.isEmpty) return;
    for (int i = 0; i < _chunks.length; i++) {
      final chunkSpoken = _chunks[i].spokenText.toLowerCase();
      final chunkRaw = _chunks[i].rawText.toLowerCase();
      if (chunkRaw.contains(targetSection.toLowerCase()) ||
          chunkSpoken.contains(cleanTarget)) {
        if (i > 0) {
          await jumpToChunk(i);
        }
        return;
      }
    }
  }
}
