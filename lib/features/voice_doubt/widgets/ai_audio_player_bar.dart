import 'package:flutter/material.dart';
import '../services/ai_tts_service.dart';

/// Floating interactive Audio Masterclass Player Bar with Real-Time Waveform Equalizer
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
  double? _dragValue;

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

  void _showSentenceSelectorSheet(BuildContext context) {
    final chunks = _ttsService.chunks;
    if (chunks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.queue_music_rounded, color: Color(0xFF6366F1), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jump to Sentence (${chunks.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: chunks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final isCurrent = index == _ttsService.currentChunkIndex;
                    final chunk = chunks[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrent
                            ? const Color(0xFF6366F1)
                            : (widget.isDark ? Colors.white12 : Colors.black12),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : (widget.isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                      title: Text(
                        chunk.spokenText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? const Color(0xFF6366F1)
                              : (widget.isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.volume_up_rounded, color: Color(0xFF6366F1), size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _ttsService.jumpToChunk(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlayerOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1B4B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Audio & Device Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Voice Persona Selector
                  Text('Voice Persona', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPersonaChip('Priya Ma\'am', VoicePersona.priya, setSheetState),
                        const SizedBox(width: 8),
                        _buildPersonaChip('Dr. Aryan', VoicePersona.aryan, setSheetState),
                        const SizedBox(width: 8),
                        _buildPersonaChip('AI Mentor', VoicePersona.mentor, setSheetState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sleep Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sleep Timer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : const Color(0xFF1E293B))),
                            Text(
                              _ttsService.sleepTimerMinutes != null
                                  ? 'Auto-stop in ${_ttsService.sleepTimerMinutes}m'
                                  : 'Turn off audio automatically',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSleepChip(10, setSheetState),
                            const SizedBox(width: 6),
                            _buildSleepChip(20, setSheetState),
                            const SizedBox(width: 6),
                            _buildSleepChip(30, setSheetState),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Data & Battery Saver Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Data & Battery Saver', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : const Color(0xFF1E293B))),
                    subtitle: Text('Uses 0KB internet & minimal battery via offline engine', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    value: _ttsService.isDataSaverMode,
                    activeTrackColor: const Color(0xFF6366F1),
                    activeThumbColor: Colors.white,
                    onChanged: (val) {
                      _ttsService.toggleDataSaverMode();
                      setSheetState(() {});
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPersonaChip(String label, VoicePersona p, StateSetter setSheetState) {
    final isSelected = _ttsService.persona == p;
    return InkWell(
      onTap: () {
        _ttsService.setPersona(p);
        setSheetState(() {});
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : (widget.isDark ? Colors.white12 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildSleepChip(int mins, StateSetter setSheetState) {
    final isSelected = _ttsService.sleepTimerMinutes == mins;
    return InkWell(
      onTap: () {
        if (isSelected) {
          _ttsService.cancelSleepTimer();
        } else {
          _ttsService.setSleepTimer(mins);
        }
        setSheetState(() {});
        setState(() {});
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : (widget.isDark ? Colors.white12 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${mins}m',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ttsService.isStopped) return const SizedBox.shrink();

    final isPlaying = _ttsService.isPlaying;
    final activeChunkIndex = (_dragValue?.round() ?? _ttsService.currentChunkIndex).clamp(
      0,
      _ttsService.totalChunks > 0 ? _ttsService.totalChunks - 1 : 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x404F46E5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header (Equalizer, Title, Persona chip, Chunk badge) & Secondary Actions (Speed, Settings, Close)
          Row(
            children: [
              // Animated Live Waveform Sound Equalizer
              Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _LiveWaveformVisualizer(
                    isPlaying: isPlaying,
                    barColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Title, Persona & Chunk count (FittedBox ensures ZERO overflow on any device width)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AI Tutor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () {
                          final next = _ttsService.persona == VoicePersona.priya
                              ? VoicePersona.aryan
                              : VoicePersona.priya;
                          _ttsService.setPersona(next);
                        },
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _ttsService.persona == VoicePersona.priya ? '👩 Priya' : '👨 Aryan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_ttsService.totalChunks > 0) ...[
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: () => _showSentenceSelectorSheet(context),
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${activeChunkIndex + 1}/${_ttsService.totalChunks}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 1),
                                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Header Action Controls (Speed, Settings, Close)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed Control Chip (1.0x / 1.25x / 1.5x / 2.0x)
                  InkWell(
                    onTap: () => _ttsService.cycleSpeechRate(),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_ttsService.speechRate}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),

                  // Audio Settings & Sleep Timer Sheet Button (⚙️)
                  IconButton(
                    icon: Icon(
                      _ttsService.sleepTimerMinutes != null ? Icons.timer_rounded : Icons.tune_rounded,
                      color: _ttsService.sleepTimerMinutes != null ? const Color(0xFFFDE047) : Colors.white,
                      size: 15,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Voice settings & timer',
                    onPressed: () => _showPlayerOptionsSheet(context),
                  ),
                  const SizedBox(width: 1),

                  // Stop / Close Button (✕)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 15),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close audio player',
                    onPressed: () => _ttsService.stop(),
                  ),
                ],
              ),
            ],
          ),

          // Row 1.5: Currently Spoken Sentence (Full Width, Ellipsis)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              _dragValue != null
                  ? (_ttsService.chunks.isNotEmpty
                      ? _ttsService.chunks[activeChunkIndex].spokenText
                      : '')
                  : (isPlaying
                      ? (_ttsService.currentSpokenChunk.isNotEmpty
                          ? _ttsService.currentSpokenChunk
                          : 'Reading response out loud...')
                      : 'Audio paused • Tap play to continue'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 9.5,
                fontStyle: (isPlaying || _dragValue != null) ? FontStyle.normal : FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Row 2: Transport Playback Controls & Interactive Scrubber Bar
          Row(
            children: [
              // Previous Sentence (⏮️)
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 19),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous sentence',
                onPressed: _ttsService.hasPreviousChunk ? () => _ttsService.previousChunk() : null,
              ),
              const SizedBox(width: 2),

              // Play / Pause Toggle Button (⏯️)
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
                tooltip: isPlaying ? 'Pause' : 'Play',
                onPressed: () {
                  if (isPlaying) {
                    _ttsService.pause();
                  } else {
                    _ttsService.resume();
                  }
                },
              ),
              const SizedBox(width: 2),

              // Next Sentence (⏭️)
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 19),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                visualDensity: VisualDensity.compact,
                tooltip: 'Next sentence',
                onPressed: _ttsService.hasNextChunk ? () => _ttsService.nextChunk() : null,
              ),
              const SizedBox(width: 2),

              // Replay Current Sentence Button (↺)
              IconButton(
                icon: const Icon(Icons.replay_rounded, color: Colors.white, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                visualDensity: VisualDensity.compact,
                tooltip: 'Replay current sentence',
                onPressed: () => _ttsService.replayCurrentChunk(),
              ),
              const SizedBox(width: 6),

              // Interactive Sentence Progress Scrubber or Linear Indicator
              Expanded(
                child: _ttsService.totalChunks > 1
                    ? SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                          activeTrackColor: const Color(0xFF34D399),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                          thumbColor: Colors.white,
                          overlayColor: const Color(0x3334D399),
                        ),
                        child: Slider(
                          value: (_dragValue ?? _ttsService.currentChunkIndex.toDouble()).clamp(
                                0.0,
                                (_ttsService.totalChunks - 1).clamp(0, 9999).toDouble(),
                              ),
                          min: 0.0,
                          max: (_ttsService.totalChunks - 1).clamp(0, 9999).toDouble(),
                          divisions: _ttsService.totalChunks > 1 ? _ttsService.totalChunks - 1 : 1,
                          onChanged: (val) {
                            setState(() {
                              _dragValue = val;
                            });
                          },
                          onChangeEnd: (val) {
                            setState(() {
                              _dragValue = null;
                            });
                            _ttsService.jumpToChunk(val.round());
                          },
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _ttsService.progress,
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dynamic 5-bar live harmonic audio waveform visualizer
class _LiveWaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color barColor;

  const _LiveWaveformVisualizer({
    required this.isPlaying,
    this.barColor = Colors.white,
  });

  @override
  State<_LiveWaveformVisualizer> createState() => _LiveWaveformVisualizerState();
}

class _LiveWaveformVisualizerState extends State<_LiveWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _LiveWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        // 5 distinct harmonic bar heights
        final heights = [
          5.0 + (val * 10.0),
          10.0 + ((1.0 - val) * 8.0),
          4.0 + (val * 14.0),
          8.0 + ((1.0 - val) * 10.0),
          5.0 + (val * 7.0),
        ];

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              final h = widget.isPlaying ? heights[index] : 4.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 0.8),
                width: 2.0,
                height: h,
                decoration: BoxDecoration(
                  color: widget.barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
