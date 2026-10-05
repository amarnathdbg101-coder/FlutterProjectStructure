import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable animated Voice Record Microphone Button
/// Features active recording pulsing indicator and theme-adaptive colors.
class VoiceRecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const VoiceRecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.size = 22.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    if (widget.isRecording) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_animController.isAnimating) {
      _animController.repeat(reverse: true);
    } else if (!widget.isRecording && _animController.isAnimating) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCol = widget.activeColor ?? Colors.red;
    final inactiveCol = widget.inactiveColor ?? AppColors.primary;
    final defaultTooltip = widget.isRecording
        ? 'Stop Recording Voice Doubt'
        : 'Record Voice Doubt';

    return Tooltip(
      message: widget.tooltip ?? defaultTooltip,
      child: InkWell(
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording
                    ? activeCol.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: widget.isRecording
                    ? Border.all(
                        color: activeCol.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Transform.scale(
                scale: widget.isRecording ? _scaleAnimation.value : 1.0,
                child: Icon(
                  widget.isRecording ? Icons.mic : Icons.mic_none_rounded,
                  color: widget.isRecording ? activeCol : inactiveCol,
                  size: widget.size,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
