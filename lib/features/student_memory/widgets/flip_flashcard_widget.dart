import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';
import '../models/flashcard_model.dart';

/// 3D Flip Card Widget with smooth 180-degree Y-axis matrix transformation
class FlipFlashcardWidget extends StatefulWidget {
  final FlashcardModel flashcard;
  final bool isDark;
  final VoidCallback? onFlipped;

  const FlipFlashcardWidget({
    super.key,
    required this.flashcard,
    required this.isDark,
    this.onFlipped,
  });

  @override
  State<FlipFlashcardWidget> createState() => _FlipFlashcardWidgetState();
}

class _FlipFlashcardWidgetState extends State<FlipFlashcardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _animation.addListener(() {
      if (_animation.value >= 0.5 && _showFront) {
        setState(() => _showFront = false);
      } else if (_animation.value < 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_controller.isAnimating) return;
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    if (widget.onFlipped != null) widget.onFlipped!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective depth
          ..rotateY(angle);

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: _flipCard,
            child: _showFront
                ? _buildFrontCard(isDark)
                : Transform(
                    transform: Matrix4.identity()..rotateY(math.pi), // mirror flip content
                    alignment: Alignment.center,
                    child: _buildBackCard(isDark),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFrontCard(bool isDark) {
    return Container(
      width: double.infinity,
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6366F1),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.flashcard.topic,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.style_rounded, size: 20, color: Color(0xFF6366F1)),
            ],
          ),

          // Question Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  widget.flashcard.questionFront,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),

          // Flip Hint Footer
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap card to reveal answer 🔄',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(bool isDark) {
    return Container(
      width: double.infinity,
      height: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B192C) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F10B981),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Correct Concept & Solution',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.flip_to_front_rounded, size: 18, color: Color(0xFF10B981)),
            ],
          ),

          // Answer Content with KaTeX / Markdown
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FormattedAiText(
                  text: widget.flashcard.answerBack,
                  isDark: isDark,
                  baseFontSize: 13,
                ),
              ),
            ),
          ),

          // Flip Back Footer
          const Center(
            child: Text(
              'Tap card to flip back 🔄',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
