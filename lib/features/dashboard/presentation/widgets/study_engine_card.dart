import 'package:flutter/material.dart';

/// Luxury Bento-Style AI Study Engine Card
/// Features distinct accent palette, glowing micro-badge, smooth tap-scale micro-animation,
/// and crisp non-truncated 2-line typography.
class StudyEngineCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final String badge;
  final String? engineId;
  final VoidCallback onTap;
  final bool isDark;

  const StudyEngineCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.badge = '',
    this.engineId,
    required this.onTap,
    this.isDark = false,
  });

  @override
  State<StudyEngineCard> createState() => _StudyEngineCardState();
}

class _StudyEngineCardState extends State<StudyEngineCard> {
  bool _isPressed = false;

  Color get _accentColor {
    final key = (widget.engineId ?? widget.title).toLowerCase();
    if (key.contains('socratic')) {
      return const Color(0xFF6366F1); // Indigo / Violet
    } else if (key.contains('quiz')) {
      return const Color(0xFF10B981); // Emerald / Mint
    } else if (key.contains('map') || key.contains('diagram')) {
      return const Color(0xFF06B6D4); // Cyan / Electric Blue
    } else if (key.contains('hub') || key.contains('cognitive')) {
      return const Color(0xFFF59E0B); // Amber / Warm Orange
    } else if (key.contains('flashcard')) {
      return const Color(0xFFEC4899); // Rose / Fuchsia
    } else if (key.contains('planner')) {
      return const Color(0xFF3B82F6); // Sky / Electric Blue
    }
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = _accentColor;

    final bgColor = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF24324D)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedScale(
      scale: _isPressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Styled Glowing Icon Capsule + Outward Arrow / Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          size: 19,
                          color: accent,
                        ),
                      ),
                    ),
                    if (widget.badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withValues(alpha: isDark ? 0.25 : 0.16),
                          ),
                        ),
                        child: Text(
                          widget.badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 15,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom Info: Title & 2-Line Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
