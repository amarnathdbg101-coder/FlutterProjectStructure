import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

/// Universal Filter & Option Chip Component for ShopSilo.
/// Replaces ad-hoc styled choice chips across POS, Inventory, and Khata.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final IconData? icon;
  final int? count;
  final Color? activeColor;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.count,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final primary = activeColor ?? AppColors.primary;

    final bgColor = isSelected
        ? (isDark ? primary.withValues(alpha: 0.25) : primary.withValues(alpha: 0.12))
        : (isDark ? context.colorSurfaceSubtle : context.colorSurface);

    final textColor = isSelected
        ? primary
        : (isDark ? context.colorTextPrimary : context.colorTextSecondary);

    final borderColor = isSelected
        ? primary
        : (isDark ? context.colorBorder : AppColors.border);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: isSelected ? 1.4 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: textColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

