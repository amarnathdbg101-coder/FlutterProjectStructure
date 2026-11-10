import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

/// Style variants for standard ShopSilo buttons.
enum AppButtonVariant {
  /// Solid primary brand button (Indigo/Blue, white text)
  primary,

  /// Subtle elevated secondary button (Slate/Surface Subtle, primary text)
  secondary,

  /// Clean border outlined button (Transparent bg, themed border)
  outline,

  /// Destructive action button (Red/Rose for Delete, Clear Cart, Discard)
  danger,

  /// Success / Confirmation / WhatsApp button (Emerald / WhatsApp green)
  success,

  /// Warning / Alert action button (Amber for Restock, Returns)
  warning,

  /// Ghost / Flat text button (0 border, 0 elevation, subtle touch)
  ghost,
}

/// Size presets ensuring strict typographic and ergonomic consistency across devices.
enum AppButtonSize {
  /// Compact height (36px): Used in table rows, modals, chip bars, compact cards
  sm,

  /// Standard height (44px): Default for dialog actions, forms, list item actions
  md,

  /// Large CTA height (52px): Used for primary counter checkout, big submit actions
  lg,
}

/// Universal Production-Grade Reusable Button for ShopSilo.
/// Centralizes padding, typography, animations, loading spinners, and haptic feedback.
/// Changes to brand colors, border radius, or heights here instantly reflect across 100% of the app.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isFullWidth;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? customColor;
  final Color? customTextColor;
  final double? borderRadius;
  final double? customWidth;
  final bool enableHaptic;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isFullWidth = false,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.customColor,
    this.customTextColor,
    this.borderRadius,
    this.customWidth,
    this.enableHaptic = true,
  });

  /// Factory helper for primary action buttons
  factory AppButton.primary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool isFullWidth = false,
    bool isLoading = false,
    IconData? icon,
    Color? customColor,
    Color? customTextColor,
    double? borderRadius,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.primary,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      icon: icon,
      customColor: customColor,
      customTextColor: customTextColor,
      borderRadius: borderRadius,
    );
  }

  /// Factory helper for secondary action buttons
  factory AppButton.secondary({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool isFullWidth = false,
    bool isLoading = false,
    IconData? icon,
    Color? customColor,
    Color? customTextColor,
    double? borderRadius,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.secondary,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      icon: icon,
      customColor: customColor,
      customTextColor: customTextColor,
      borderRadius: borderRadius,
    );
  }

  /// Factory helper for 1-tap WhatsApp buttons
  factory AppButton.whatsapp({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool isFullWidth = false,
    bool isLoading = false,
    IconData? icon,
    double? borderRadius,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.success,
      customColor: const Color(0xFF25D366),
      icon: icon ?? Icons.send_rounded,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      borderRadius: borderRadius,
    );
  }

  /// Factory helper for dangerous actions (Delete / Discard)
  factory AppButton.danger({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool isFullWidth = false,
    bool isLoading = false,
    IconData? icon = Icons.delete_outline_rounded,
    Color? customColor,
    double? borderRadius,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.danger,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      customColor: customColor,
      borderRadius: borderRadius,
    );
  }

  /// Factory helper for clean secondary/cancel actions
  factory AppButton.outline({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.md,
    bool isFullWidth = false,
    bool isLoading = false,
    IconData? icon,
    Color? customColor,
    Color? customTextColor,
    double? borderRadius,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.outline,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      isLoading: isLoading,
      customColor: customColor,
      customTextColor: customTextColor,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isEnabled = onPressed != null && !isLoading;

    // 1. Dimensions based on size preset
    final double height;
    final double fontSize;
    final double iconSize;
    final EdgeInsetsGeometry padding;

    switch (size) {
      case AppButtonSize.sm:
        height = 36.0;
        fontSize = 12.0;
        iconSize = 16.0;
        padding = const EdgeInsets.symmetric(horizontal: 12);
        break;
      case AppButtonSize.md:
        height = 44.0;
        fontSize = 13.5;
        iconSize = 18.0;
        padding = const EdgeInsets.symmetric(horizontal: 16);
        break;
      case AppButtonSize.lg:
        height = 52.0;
        fontSize = 15.0;
        iconSize = 20.0;
        padding = const EdgeInsets.symmetric(horizontal: 20);
        break;
    }

    // 2. Color Resolution based on variant
    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = customColor ?? AppColors.primary;
        fgColor = customTextColor ?? Colors.white;
        break;

      case AppButtonVariant.secondary:
        bgColor = customColor ?? (isDark ? context.colorSurfaceSubtle : context.colorPrimaryLight);
        fgColor = customTextColor ?? (isDark ? context.colorTextPrimary : AppColors.primary);
        break;

      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = customTextColor ?? (customColor ?? context.colorTextPrimary);
        borderSide = BorderSide(
          color: customColor ?? (isDark ? context.colorBorder : AppColors.border),
          width: 1.2,
        );
        break;

      case AppButtonVariant.danger:
        bgColor = customColor ?? AppColors.error;
        fgColor = customTextColor ?? Colors.white;
        break;

      case AppButtonVariant.success:
        bgColor = customColor ?? AppColors.success;
        fgColor = customTextColor ?? Colors.white;
        break;

      case AppButtonVariant.warning:
        bgColor = customColor ?? AppColors.warning;
        fgColor = customTextColor ?? Colors.white;
        break;

      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = customTextColor ?? (customColor ?? context.colorTextPrimary);
        break;
    }

    // Disabled state color adjustment
    if (!isEnabled) {
      bgColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
      fgColor = isDark ? Colors.white30 : Colors.black26;
      borderSide = BorderSide.none;
    }

    final radius = BorderRadius.circular(borderRadius ?? 12.0);

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: fgColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fgColor,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );

    return SizedBox(
      width: customWidth ?? (isFullWidth ? double.infinity : null),
      height: height,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: isEnabled
              ? () {
                  if (enableHaptic) {
                    HapticFeedback.lightImpact();
                  }
                  onPressed!();
                }
              : null,
          child: Padding(
            padding: padding,
            child: content,
          ),
        ),
      ),
    );
  }
}

