import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

enum AppIconButtonVariant {
  /// Standard subtle slate background
  standard,

  /// Brand primary light background with primary icon
  primary,

  /// Danger light red background with red icon
  danger,

  /// Outlined border with transparent background
  outline,

  /// Completely transparent ghost touch target
  ghost,
}

enum AppIconButtonSize {
  /// 32x32px, 16px icon (Compact rows, chips, card corners)
  sm,

  /// 40x40px, 19px icon (Standard app bars, toolbars, list tiles)
  md,

  /// 48x48px, 22px icon (Major action buttons, prominent quick controls)
  lg,
}

/// Universal Production-Grade Reusable Icon Button for ShopSilo.
/// Guarantees clean touch boundaries, tooltip support, and tactile feedback.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppIconButtonVariant variant;
  final AppIconButtonSize size;
  final Color? customColor;
  final Color? customIconColor;
  final bool isCircle;
  final double? borderRadius;
  final bool isLoading;
  final int? badgeCount;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AppIconButtonVariant.standard,
    this.size = AppIconButtonSize.md,
    this.customColor,
    this.customIconColor,
    this.isCircle = false,
    this.borderRadius,
    this.isLoading = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isEnabled = onPressed != null && !isLoading;

    final double dim;
    final double iconSize;

    switch (size) {
      case AppIconButtonSize.sm:
        dim = 32.0;
        iconSize = 16.0;
        break;
      case AppIconButtonSize.md:
        dim = 40.0;
        iconSize = 19.0;
        break;
      case AppIconButtonSize.lg:
        dim = 48.0;
        iconSize = 22.0;
        break;
    }

    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case AppIconButtonVariant.standard:
        bgColor = customColor ?? (isDark ? context.colorSurfaceSubtle : context.colorSurfaceSubtle);
        fgColor = customIconColor ?? context.colorTextPrimary;
        break;

      case AppIconButtonVariant.primary:
        bgColor = customColor ?? (isDark ? context.colorPrimaryLight : context.colorPrimaryLight);
        fgColor = customIconColor ?? AppColors.primary;
        break;

      case AppIconButtonVariant.danger:
        bgColor = customColor ?? (isDark ? context.colorErrorLight : context.colorErrorLight);
        fgColor = customIconColor ?? AppColors.error;
        break;

      case AppIconButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = customIconColor ?? context.colorTextPrimary;
        borderSide = BorderSide(color: isDark ? context.colorBorder : AppColors.border, width: 1.2);
        break;

      case AppIconButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = customIconColor ?? context.colorTextPrimary;
        break;
    }

    if (!isEnabled) {
      bgColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04);
      fgColor = isDark ? Colors.white30 : Colors.black26;
      borderSide = BorderSide.none;
    }

    final shape = isCircle
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 10.0),
            side: borderSide,
          );

    Widget iconWidget = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Icon(icon, size: iconSize, color: fgColor);

    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    Widget button = SizedBox(
      width: dim,
      height: dim,
      child: Material(
        color: bgColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: isEnabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: Center(child: iconWidget),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

