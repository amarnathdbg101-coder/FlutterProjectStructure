import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../localization/language_controller.dart';
import '../../services/voice_input_service.dart';

/// Industrial-Grade Voice Dictation & Search Sheet for ShopSilo Merchants.
/// Features:
/// 1. Prominent animated pulsing mic with concentric audio ripple aura.
/// 2. Real-time live transcript streaming with bold, glare-resistant typography.
/// 3. Instant 1-tap language switch: [ 🇮🇳 हिन्दी | 🇬🇧 English ] directly on sheet.
/// 4. 1-Tap quick retail suggestion chips (Tata Salt, Amul Milk, Fortune Oil, Maggi).
/// 5. Automatic silence commit and instant search execution.
class AppVoiceDictationSheet extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final bool initialIsHindi;

  const AppVoiceDictationSheet({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.hint,
    this.initialIsHindi = false,
  });

  /// Static helper to display the sheet from anywhere across merchant screens
  static Future<String?> show(
    BuildContext context, {
    required TextEditingController controller,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    String? hint,
  }) {
    bool isHindi = false;
    try {
      isHindi = context.isHindi;
    } catch (_) {
      isHindi = false;
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppVoiceDictationSheet(
        controller: controller,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        hint: hint,
        initialIsHindi: isHindi,
      ),
    );
  }

  @override
  State<AppVoiceDictationSheet> createState() => _AppVoiceDictationSheetState();
}

class _AppVoiceDictationSheetState extends State<AppVoiceDictationSheet>
    with SingleTickerProviderStateMixin {
  late bool _isHindiMode;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  String _liveTranscript = '';
  String? _statusError;
  bool _isListening = false;
  Timer? _silenceTimer;

  static const List<String> _hindiSuggestions = [
    'टाटा नमक',
    'अमूल दूध',
    'फॉर्च्यून तेल',
    'मैगी',
    'आशीर्वाद आटा',
    'सर्फ एक्सेल',
  ];

  static const List<String> _englishSuggestions = [
    'Tata Salt',
    'Amul Milk',
    'Fortune Oil',
    'Maggi',
    'Aashirvaad Atta',
    'Surf Excel',
  ];

  @override
  void initState() {
    super.initState();
    _isHindiMode = widget.initialIsHindi;

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.4).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutQuad),
    );

    // Auto-start listening as soon as sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceListening();
    });
  }

  Future<void> _startVoiceListening() async {
    _silenceTimer?.cancel();
    setState(() {
      _statusError = null;
      _liveTranscript = '';
    });

    final voice = AppVoiceInputService.instance;
    final locale = _isHindiMode ? 'hi_IN' : 'en_IN';

    if (!_rippleController.isAnimating) {
      _rippleController.repeat();
    }

    setState(() => _isListening = true);

    final success = await voice.startListening(
      context: context,
      localeId: locale,
      onResult: (words) {
        if (!mounted) return;
        setState(() {
          _liveTranscript = words;
        });

        // Silence auto-commit after 1.5s
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted && _liveTranscript.trim().isNotEmpty) {
            _commitAndClose(_liveTranscript);
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_liveTranscript.trim().isNotEmpty) {
          _commitAndClose(_liveTranscript);
        } else {
          setState(() => _isListening = false);
          _rippleController.stop();
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _statusError = err;
        });
        _rippleController.stop();
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
        _statusError = _isHindiMode
            ? 'वॉइस सेवा प्रारंभ नहीं हो सकी'
            : 'Could not initialize voice service';
      });
      _rippleController.stop();
    }
  }

  void _commitAndClose(String rawText) {
    _silenceTimer?.cancel();
    final clean = AppVoiceInputService.cleanVoiceQuery(rawText);
    final normalized = AppVoiceInputService.retailBilingualMap[clean] ?? clean;

    widget.controller.text = normalized;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );

    widget.onChanged?.call(normalized);
    widget.onSubmitted?.call(normalized);

    Navigator.of(context).pop(normalized);
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _rippleController.dispose();
    AppVoiceInputService.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _isHindiMode ? _hindiSuggestions : _englishSuggestions;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Language Toggle Pills & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Language Switcher Pill
              Container(
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colorBorder),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageTab(
                      label: '🇮🇳 हिन्दी',
                      isSelected: _isHindiMode,
                      onTap: () {
                        if (!_isHindiMode) {
                          setState(() => _isHindiMode = true);
                          _startVoiceListening();
                        }
                      },
                    ),
                    _buildLanguageTab(
                      label: 'English',
                      isSelected: !_isHindiMode,
                      onTap: () {
                        if (_isHindiMode) {
                          setState(() => _isHindiMode = false);
                          _startVoiceListening();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Close button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                color: context.colorTextMuted,
                splashRadius: 20,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Animated Glowing Mic Center
          Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated concentric pulse ring
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: _opacityAnimation.value,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Mic Button
                  GestureDetector(
                    onTap: () {
                      if (_isListening) {
                        AppVoiceInputService.instance.stopListening();
                        setState(() => _isListening = false);
                        _rippleController.stop();
                      } else {
                        _startVoiceListening();
                      }
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? AppColors.primary
                            : (_statusError != null ? AppColors.error : context.colorSurfaceSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: _isListening
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : Colors.black12,
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : (_statusError != null ? Icons.refresh_rounded : Icons.mic_rounded),
                        color: _isListening || _statusError != null
                            ? Colors.white
                            : context.colorTextPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Status subtitle
          Text(
            _statusError != null
                ? _statusError!
                : (_isListening
                    ? (_isHindiMode
                        ? 'सुन रहे हैं... बोलिए (उदा. "टाटा नमक", "अमूल दूध")'
                        : 'Listening... Speak now (e.g. "Tata Salt", "Amul Milk")')
                    : (_isHindiMode ? 'बोलने के लिए माइक दबाएं' : 'Tap mic to speak')),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _statusError != null
                  ? AppColors.error
                  : (_isListening ? AppColors.primary : context.colorTextMuted),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Live Transcript Display Card
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _liveTranscript.isNotEmpty
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : context.colorBorder,
                width: 1.2,
              ),
            ),
            child: Center(
              child: _liveTranscript.isNotEmpty
                  ? Text(
                      '"$_liveTranscript"',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.colorTextPrimary,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      _isHindiMode
                          ? 'उदा. "अमूल दूध", "टाटा नमक", "फॉर्च्यून तेल"...'
                          : 'e.g. "Amul Milk", "Tata Salt", "Fortune Oil"...',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: context.colorTextMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // 1-Tap Quick Retail Suggestion Chips
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                _isHindiMode ? 'त्वरित सुझाव (टैप करें):' : 'Quick Suggestions (tap):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((term) {
              return InkWell(
                onTap: () => _commitAndClose(term),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Text(
                    term,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colorTextPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Search / Commit Button
          if (_liveTranscript.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _commitAndClose(_liveTranscript),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: Text(
                  _isHindiMode ? 'खोजें / भरें' : 'Search / Fill',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.primary : context.colorTextMuted,
          ),
        ),
      ),
    );
  }
}
