import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_tts_service.dart';
import '../services/voice_doubt_service.dart';

enum LiveTalkState { listening, thinking, speaking, paused }

/// High-Fidelity 1-on-1 Gemini Live-Style Interactive AI Voice Masterclass Sheet.
/// Features continuous hands-free dialogue, real-time glowing Voice Aura visualizer,
/// persona switching (Priya / Aryan / Mentor), speed controls, and instant tap-to-interrupt.
class LiveAiTalkOverlaySheet extends StatefulWidget {
  final String? scopeTitle;
  final String? initialDoubt;
  final Future<String> Function(String userDoubt)? onProcessDoubt;

  const LiveAiTalkOverlaySheet({
    super.key,
    this.scopeTitle,
    this.initialDoubt,
    this.onProcessDoubt,
  });

  static Future<void> show(
    BuildContext context, {
    String? scopeTitle,
    String? initialDoubt,
    Future<String> Function(String userDoubt)? onProcessDoubt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => LiveAiTalkOverlaySheet(
        scopeTitle: scopeTitle,
        initialDoubt: initialDoubt,
        onProcessDoubt: onProcessDoubt,
      ),
    );
  }

  @override
  State<LiveAiTalkOverlaySheet> createState() => _LiveAiTalkOverlaySheetState();
}

class _LiveAiTalkOverlaySheetState extends State<LiveAiTalkOverlaySheet>
    with TickerProviderStateMixin {
  final AiTtsService _ttsService = AiTtsService();
  final VoiceDoubtService _voiceService = VoiceDoubtService();

  late AnimationController _auraAnimController;
  late AnimationController _pulseController;

  LiveTalkState _state = LiveTalkState.listening;
  String _userSpeech = '';
  String _aiTranscript = '';
  String _statusText = 'Listening... Speak your doubt';
  VoicePersona _selectedPersona = VoicePersona.priya;

  @override
  void initState() {
    super.initState();
    _selectedPersona = _ttsService.persona;

    _auraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _ttsService.addListener(_onTtsStateChanged);

    // Wire continuous Live Talk loop callback
    _ttsService.setLiveTalkMode(true, onCompleted: () {
      if (mounted) {
        _startListeningLoop();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDoubt != null && widget.initialDoubt!.trim().isNotEmpty) {
        _handleUserQuerySubmitted(widget.initialDoubt!.trim());
      } else {
        _startListeningLoop();
      }
    });
  }

  @override
  void dispose() {
    _ttsService.removeListener(_onTtsStateChanged);
    _ttsService.setLiveTalkMode(false);
    _voiceService.stopListening();
    _userSpeech = '';
    _auraAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (!mounted) return;
    if (_ttsService.isPlaying && _state != LiveTalkState.speaking) {
      setState(() {
        _state = LiveTalkState.speaking;
        _statusText = '${_getPersonaTitle(_selectedPersona)} is explaining...';
      });
    }
  }

  String _getPersonaTitle([VoicePersona? persona]) {
    return 'Priya Ma\'am';
  }

  List<Color> _getAuraColors([VoicePersona? persona]) {
    return const [Color(0xFFEC4899), Color(0xFF10B981)];
  }

  Future<void> _startListeningLoop() async {
    if (!mounted) return;
    HapticFeedback.selectionClick();

    setState(() {
      _state = LiveTalkState.listening;
      _userSpeech = '';
      _statusText = 'Listening... Speak your doubt';
    });

    final success = await _voiceService.startListening(
      localeId: 'hi_IN',
      onResult: (text) {
        if (!mounted) return;
        // Instant Mic Buffer Guard: Never capture speech if AI is already thinking or speaking
        if (_state != LiveTalkState.listening) return;
        setState(() {
          _userSpeech = text;
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_userSpeech.trim().isNotEmpty) {
          final query = _userSpeech.trim();
          _userSpeech = ''; // Zeroed immediately!
          _handleUserQuerySubmitted(query);
        } else if (_state == LiveTalkState.listening) {
          setState(() {
            _statusText = 'Tap mic to continue conversation';
          });
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _statusText = 'Tap mic button to speak';
      });
    }
  }

  Future<void> _handleUserQuerySubmitted(String query) async {
    // 1. Immediately kill microphone input so AI audio is never captured
    await _voiceService.stopListening();
    if (!mounted) return;

    // 2. Instant Mic Buffer Clearing (ChatGPT / ElevenLabs standard)
    setState(() {
      _userSpeech = '';
      _state = LiveTalkState.thinking;
      _statusText = '${_getPersonaTitle(_selectedPersona)} is analyzing...';
    });

    try {
      String response = '';
      if (widget.onProcessDoubt != null) {
        response = await widget.onProcessDoubt!(query);
      } else {
        // Fallback default explanation generator if offline
        response = 'Here is the step-by-step concept analysis for "$query". Key concept is active recall and formula application.';
      }

      if (!mounted) return;
      setState(() {
        _aiTranscript = response;
        _state = LiveTalkState.speaking;
        _statusText = '${_getPersonaTitle(_selectedPersona)} is explaining...';
      });

      await _ttsService.speak(response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Connection error. Tap to retry.';
        _state = LiveTalkState.listening;
      });
    }
  }

  Future<void> _interruptAndSpeak() async {
    HapticFeedback.mediumImpact();
    await _ttsService.stop();
    _userSpeech = '';
    await _startListeningLoop();
  }

  Future<void> _changePersona(VoicePersona persona) async {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPersona = persona;
    });
    await _ttsService.setPersona(persona);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getAuraColors(_selectedPersona);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.first.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.first.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.first,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '1-on-1 Gemini Live Talk',
                          style: TextStyle(
                            color: colors.first,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      _ttsService.stop();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Persona Selector Chip (Female Studio Voice)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPersonaChip(VoicePersona.priya, '🌸 Priya Ma\'am'),
                ],
              ),
            ),

            const Spacer(),

            // Glowing Voice Aura Ripple Center Representation
            GestureDetector(
              onTap: _state == LiveTalkState.speaking ? _interruptAndSpeak : _startListeningLoop,
              child: AnimatedBuilder(
                animation: Listenable.merge([_auraAnimController, _pulseController]),
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  final auraAngle = _auraAnimController.value * 2 * pi;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Glowing Ripples
                      Transform.rotate(
                        angle: auraAngle,
                        child: Container(
                          width: 220 * scale,
                          height: 220 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                colors.first.withOpacity(0.35),
                                colors.last.withOpacity(0.35),
                                colors.first.withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 170 * scale,
                        height: 170 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _state == LiveTalkState.speaking
                              ? Icons.graphic_eq
                              : _state == LiveTalkState.thinking
                                  ? Icons.auto_awesome
                                  : Icons.mic,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Status & Dynamic Transcript
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_userSpeech.isNotEmpty && _state == LiveTalkState.listening)
                    Text(
                      '"$_userSpeech"',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (_aiTranscript.isNotEmpty && _state == LiveTalkState.speaking)
                    Text(
                      _ttsService.currentSpokenChunk.isNotEmpty
                          ? '"${_ttsService.currentSpokenChunk}"'
                          : '"$_aiTranscript"',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.first,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Action Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Speed Cycle
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_ttsService.speechRate}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onPressed: () {
                      _ttsService.cycleSpeechRate();
                      setState(() {});
                    },
                  ),

                  // Mic / Interrupt Button
                  FloatingActionButton.large(
                    heroTag: 'live_talk_mic_btn',
                    backgroundColor: _state == LiveTalkState.speaking
                        ? Colors.amber.shade700
                        : colors.first,
                    onPressed: _state == LiveTalkState.speaking
                        ? _interruptAndSpeak
                        : _startListeningLoop,
                    child: Icon(
                      _state == LiveTalkState.speaking ? Icons.front_hand : Icons.mic,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),

                  // End Call Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                    onPressed: () {
                      _ttsService.stop();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaChip(VoicePersona persona, String label) {
    final isSelected = _selectedPersona == persona;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: _getAuraColors(persona).first,
      backgroundColor: Colors.white.withOpacity(0.08),
      onSelected: (_) => _changePersona(persona),
    );
  }
}
