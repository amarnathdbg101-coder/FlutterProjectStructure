import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Semantic variants for ShopSilo status badges and chips.
enum AppBadgeVariant {
  /// Solid / Light Emerald for Paid, Active, Completed, In-Stock
  success,

  /// Amber / Orange for Low Stock, Due, Pending, Partial, Parked
  warning,

  /// Red / Rose for Out-of-Stock, Overdue, Cancelled, Returned
  danger,

  /// Blue / Cyan for Online UPI, In-Transit, Processing
  info,

  /// Indigo / Purple for Brand, Category, VIP, Admin
  primary,

  /// Slate / Neutral for Cash, General attributes, Size, Color
  neutral,
}

/// Legacy backward compatibility enum for older screens.
enum AppBadgeType { neutral, success, warning, error, primary }

/// Size presets for status badges
enum AppBadgeSize {
  /// Compact height (20px, 10px text): Ideal for table cells, compact tiles
  sm,

  /// Standard height (26px, 11.5px text): Ideal for card headers, detail views
  md,
}

/// Universal Production-Grade Status Badge & Tag Component for ShopSilo.
/// Ensures consistent borders, background opacities, and typography across all screens.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final AppBadgeType? type;
  final AppBadgeSize size;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? customBgColor;
  final Color? customTextColor;
  final Color? customBorderColor;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.type,
    this.size = AppBadgeSize.sm,
    this.icon,
    this.onTap,
    this.customBgColor,
    this.customTextColor,
    this.customBorderColor,
  });

  // --- Ergonomic Factory Constructors for Clean, Expressive UI Code ---

  factory AppBadge.success(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.success, icon: icon, size: size, onTap: onTap);

  factory AppBadge.warning(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.warning, icon: icon, size: size, onTap: onTap);

  factory AppBadge.danger(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.danger, icon: icon, size: size, onTap: onTap);

  factory AppBadge.info(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.info, icon: icon, size: size, onTap: onTap);

  factory AppBadge.primary(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.primary, icon: icon, size: size, onTap: onTap);

  factory AppBadge.neutral(String label, {Key? key, IconData? icon, AppBadgeSize size = AppBadgeSize.sm, VoidCallback? onTap}) =>
      AppBadge(key: key, label: label, variant: AppBadgeVariant.neutral, icon: icon, size: size, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    AppBadgeVariant effectiveVariant = variant;
    if (type != null) {
      switch (type!) {
        case AppBadgeType.success:
          effectiveVariant = AppBadgeVariant.success;
          break;
        case AppBadgeType.warning:
          effectiveVariant = AppBadgeVariant.warning;
          break;
        case AppBadgeType.error:
          effectiveVariant = AppBadgeVariant.danger;
          break;
        case AppBadgeType.primary:
          effectiveVariant = AppBadgeVariant.primary;
          break;
        case AppBadgeType.neutral:
          effectiveVariant = AppBadgeVariant.neutral;
          break;
      }
    }

    // Resolve color styling dynamically based on variant and theme
    Color bg;
    Color text;
    Color border;

    switch (effectiveVariant) {
      case AppBadgeVariant.success:
        bg = isDark ? AppColors.darkSuccessLight : AppColors.successLight;
        text = AppColors.success;
        border = AppColors.success.withValues(alpha: isDark ? 0.4 : 0.25);
        break;

      case AppBadgeVariant.warning:
        bg = isDark ? AppColors.darkWarningLight : AppColors.warningLight;
        text = AppColors.warning;
        border = AppColors.warning.withValues(alpha: isDark ? 0.4 : 0.3);
        break;

      case AppBadgeVariant.danger:
        bg = isDark ? AppColors.darkErrorLight : AppColors.errorLight;
        text = AppColors.error;
        border = AppColors.error.withValues(alpha: isDark ? 0.4 : 0.25);
        break;

      case AppBadgeVariant.info:
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        border = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.4 : 0.25);
        break;

      case AppBadgeVariant.primary:
        bg = isDark ? AppColors.darkPrimaryLight : AppColors.primaryLight;
        text = isDark ? const Color(0xFFA5B4FC) : AppColors.primary;
        border = AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.25);
        break;

      case AppBadgeVariant.neutral:
        bg = context.colorSurfaceSubtle;
        text = context.colorTextSecondary;
        border = context.colorBorder;
        break;
    }

    final effectiveBg = customBgColor ?? bg;
    final effectiveText = customTextColor ?? text;
    final effectiveBorder = customBorderColor ?? border;

    final isSm = size == AppBadgeSize.sm;
    final padding = isSm
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final fontSize = isSm ? 10.5 : 12.0;
    final iconSize = isSm ? 11.0 : 13.5;

    final badgeWidget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: effectiveBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: effectiveText),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: effectiveText,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }
}
