import 'package:flutter/material.dart';
import '../services/ai_tts_service.dart';

/// Floating interactive Audio Masterclass Player Bar
class AiAudioPlayerBar extends StatefulWidget {
  final bool isDark;

  const AiAudioPlayerBar({
    super.key,
    required this.isDark,
  });

  @override
  State<AiAudioPlayerBar> createState() => _AiAudioPlayerBarState();
}

class _AiAudioPlayerBarState extends State<AiAudioPlayerBar> {
  final AiTtsService _ttsService = AiTtsService();

  @override
  void initState() {
    super.initState();
    _ttsService.addListener(_onTtsChange);
  }

  @override
  void dispose() {
    _ttsService.removeListener(_onTtsChange);
    super.dispose();
  }

  void _onTtsChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_ttsService.isStopped) return const SizedBox.shrink();

    final isPlaying = _ttsService.isPlaying;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x404F46E5),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulse Sound Wave Icon
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔊 AI Voice Masterclass Reader',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  isPlaying ? 'Reading response out loud...' : 'Paused',
                  style: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),

          // Speed Control Chip
          InkWell(
            onTap: () => _ttsService.cycleSpeechRate(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${_ttsService.speechRate}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Play / Pause Toggle Button
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              if (isPlaying) {
                _ttsService.pause();
              } else {
                _ttsService.resume();
              }
            },
          ),
          const SizedBox(width: 6),

          // Stop / Close Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _ttsService.stop(),
          ),
        ],
      ),
    );
  }
}
