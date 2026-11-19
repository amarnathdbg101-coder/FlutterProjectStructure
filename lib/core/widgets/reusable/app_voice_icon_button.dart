import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../localization/language_controller.dart';
import '../../services/voice_input_service.dart';
import 'app_voice_dictation_sheet.dart';

/// Reusable 1-Tap Voice Dictation & Auto-Search Mic Button.
/// Supports inline listening with animated pulsing aura, live typing into controller,
/// automated search execution upon 1500ms silence pause, and optional full modal sheet.
class AppVoiceIconButton extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final double size;
  final Color? color;
  final Color? activeColor;
  final bool useModal;
  final bool styledButton;

  const AppVoiceIconButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.size = 20,
    this.color,
    this.activeColor,
    this.useModal = false,
    this.styledButton = true,
  });

  @override
  State<AppVoiceIconButton> createState() => _AppVoiceIconButtonState();
}

class _AppVoiceIconButtonState extends State<AppVoiceIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openDictationSheet(BuildContext context) {
    AppVoiceDictationSheet.show(
      context,
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      hint: widget.hint,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isHindi = false;
    try {
      isHindi = context.isHindi;
    } catch (_) {
      isHindi = false;
    }

    final voiceService = AppVoiceInputService.instance;

    return ListenableBuilder(
      listenable: voiceService,
      builder: (context, _) {
        final isListening = voiceService.isListeningTo(widget.controller);

        if (isListening) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }

        final activeCol = widget.activeColor ?? AppColors.error;
        final idleCol =
            widget.color ??
            (context.isDark ? Colors.white70 : const Color(0xFF475569));

        if (widget.styledButton) {
          return Tooltip(
            message: isListening
                ? (isHindi
                      ? 'सुन रहे हैं... (रोकने के लिए टैप करें)'
                      : 'Listening... (tap to stop)')
                : (isHindi
                      ? 'बोलकर खोजें / लिखें'
                      : 'Voice Search / Dictation'),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onLongPress: () => _openDictationSheet(context),
                onTap: () {
                  if (widget.useModal) {
                    _openDictationSheet(context);
                  } else {
                    voiceService.listenAndFill(
                      context: context,
                      controller: widget.controller,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return SizedBox(
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isListening
                              ? AppColors.error.withValues(alpha: 0.12)
                              : context.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isListening
                                ? AppColors.error.withValues(alpha: 0.45)
                                : context.colorBorder,
                            width: 1.0,
                          ),
                          boxShadow: isListening
                              ? [
                                  BoxShadow(
                                    color: AppColors.error.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: isListening ? _scaleAnimation.value : 1.0,
                            child: Icon(
                              isListening
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_rounded,
                              size: widget.size,
                              color: isListening ? activeCol : idleCol,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: isListening
              ? (isHindi
                    ? 'सुन रहे हैं... (रोकने के लिए टैप करें)'
                    : 'Listening... (tap to stop)')
              : (isHindi ? 'बोलकर खोजें / लिखें' : 'Voice Search / Dictation'),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onLongPress: () => _openDictationSheet(context),
            onTap: () {
              if (widget.useModal) {
                _openDictationSheet(context);
              } else {
                voiceService.listenAndFill(
                  context: context,
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                );
              }
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isListening ? _scaleAnimation.value : 1.0,
                      child: Container(
                        decoration: isListening
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeCol.withValues(alpha: 0.15),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeCol.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              )
                            : null,
                        padding: EdgeInsets.all(isListening ? 3 : 0),
                        child: Icon(
                          isListening
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_rounded,
                          size: widget.size,
                          color: isListening ? activeCol : idleCol,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
