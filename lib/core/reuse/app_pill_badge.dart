import 'package:flutter/material.dart';

/// Centralized Reusable Pill Badge
/// Used across Quizzes, Cognitive Hub, Dashboard, and AI Tutor
/// for topic chips, difficulty levels, streaks, and counter indicators.
class AppPillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isOutlined;

  const AppPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = const Color(0xFF4F46E5),
    this.isDark = false,
    this.onTap,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    this.borderRadius = 8.0,
    this.isOutlined = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgAlpha = isDark ? 0.18 : 0.08;
    final borderAlpha = isDark ? 0.35 : 0.22;

    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: isOutlined
            ? Border.all(color: color.withValues(alpha: borderAlpha), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4.5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: badge,
      );
    }

    return badge;
  }
}
