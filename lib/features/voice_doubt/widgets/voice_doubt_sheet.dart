import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_doubt_service.dart';
import 'live_ai_talk_overlay_sheet.dart';

/// Modal bottom sheet for Voice Doubt Input (Speech-to-Text).
/// Captures genuine student voice in Hinglish, English, or Hindi via device microphone,
/// provides real-time audio waveform visualizer, speech cleanup,
/// and instant AI doubt submission.
class VoiceDoubtSheet extends StatefulWidget {
  final String? scopeTitle;
  final String? initialPrompt;
  final bool autoStartListening;
  final void Function(String transcribedDoubt)? onAskAi;
  final void Function(String transcribedDoubt)? onPasteToChat;

  const VoiceDoubtSheet({
    super.key,
    this.scopeTitle,
    this.initialPrompt,
    this.autoStartListening = true,
    this.onAskAi,
    this.onPasteToChat,
  });

  static Future<void> show(
    BuildContext context, {
    String? scopeTitle,
    String? initialPrompt,
    bool autoStartListening = true,
    void Function(String transcribedDoubt)? onAskAi,
    void Function(String transcribedDoubt)? onPasteToChat,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceDoubtSheet(
        scopeTitle: scopeTitle,
        initialPrompt: initialPrompt,
        autoStartListening: autoStartListening,
        onAskAi: onAskAi,
        onPasteToChat: onPasteToChat,
      ),
    );
  }

  @override
  State<VoiceDoubtSheet> createState() => _VoiceDoubtSheetState();
}

class _VoiceDoubtSheetState extends State<VoiceDoubtSheet>
    with SingleTickerProviderStateMixin {
  final VoiceDoubtService _voiceService = VoiceDoubtService();
  final TextEditingController _transcriptionController = TextEditingController();

  VoiceDoubtLanguage _selectedLanguage = VoiceDoubtLanguage.hinglish;
  bool _isListening = false;
  String? _errorMessage;
  String _statusMessage = 'Tap mic to speak your doubt';
  late AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      _transcriptionController.text = widget.initialPrompt!.trim();
    }

    if (widget.autoStartListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startListening();
      });
    }
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _transcriptionController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Connecting to microphone...';
      _isListening = true;
    });
    _waveAnimController.repeat(reverse: true);

    final success = await _voiceService.startListening(
      localeId: _selectedLanguage.code,
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _transcriptionController.text = text;
          _statusMessage = 'Listening... Speak your doubt';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _statusMessage = 'Speech captured. Review or tap mic to retry.';
        });
        _waveAnimController.stop();
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Mic access unavailable';
        _errorMessage = 'Could not start microphone. Please check browser microphone permission or try again.';
      });
      _waveAnimController.stop();
    }
  }

  Future<void> _stopListening() async {
    HapticFeedback.lightImpact();
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Tap mic to speak';
        final cleaned = _voiceService.cleanAcademicSpeech(_transcriptionController.text);
        if (cleaned.isNotEmpty) {
          _transcriptionController.text = cleaned;
        }
      });
      _waveAnimController.stop();
    }
  }

  void _submitDoubt() {
    final doubt = _voiceService.cleanAcademicSpeech(_transcriptionController.text);
    if (doubt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or type your doubt first')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    if (widget.onAskAi != null) {
      widget.onAskAi!(doubt);
    }
  }

  void _pasteToChat() {
    final doubt = _voiceService.cleanAcademicSpeech(_transcriptionController.text);
    if (doubt.isEmpty) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    if (widget.onPasteToChat != null) {
      widget.onPasteToChat!(doubt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final popularDoubts = _voiceService.getSuggestedDoubtsForTopic(scopeTitle: widget.scopeTitle);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header with language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice Doubt Assistant',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bol kar question poochhein (Speech-to-Text)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Language Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VoiceDoubtLanguage>(
                      value: _selectedLanguage,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: VoiceDoubtLanguage.values.map((lang) {
                        return DropdownMenuItem(
                          value: lang,
                          child: Text(
                            '${lang.flag} ${lang.label}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (lang) {
                        if (lang != null) {
                          setState(() => _selectedLanguage = lang);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Central Animated Mic Button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF6366F1))
                        .withValues(alpha: 0.4),
                    blurRadius: _isListening ? 22 : 12,
                    spreadRadius: _isListening ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Waveform indicator & status message
          if (_isListening)
            AnimatedBuilder(
              animation: _waveAnimController,
              builder: (context, child) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (i) {
                        final phase = (i * 0.15);
                        final val = sin((_waveAnimController.value * 2 * pi) + phase).abs();
                        final height = 6.0 + (val * 18.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 3.5,
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),

          const SizedBox(height: 12),

          // Transcribed Text Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: TextField(
                controller: _transcriptionController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Speak or type your doubt here...',
                  hintStyle: TextStyle(fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Popular 1-Tap Voice Doubts Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: popularDoubts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final item = popularDoubts[i];
                return ActionChip(
                  label: Text(
                    '${item['icon']} ${item['topic']}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    setState(() {
                      _transcriptionController.text = item['query'] ?? '';
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons: "Paste in Bar" & "Ask AI Tutor"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _transcriptionController.text.trim().isNotEmpty ? _pasteToChat : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Paste in Bar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _transcriptionController.text.trim().isNotEmpty ? _submitDoubt : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Ask AI Tutor Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
