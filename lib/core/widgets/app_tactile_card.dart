import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A premium, responsive tactile card with spring micro-interaction,
/// subtle lighting borders, and optional haptic feedback.
class AppTactileCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;
  final List<BoxShadow>? customShadow;
  final bool enableHaptic;
  final double pressedScale;

  const AppTactileCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16.0,
    this.elevation = 0,
    this.customShadow,
    this.enableHaptic = true,
    this.pressedScale = 0.975,
  });

  @override
  State<AppTactileCard> createState() => _AppTactileCardState();
}

class _AppTactileCardState extends State<AppTactileCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isHovered = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ?? AppColors.getSurface(isDark);
    final borderColor = widget.borderColor ?? AppColors.getBorder(isDark);

    final scale = _isPressed ? widget.pressedScale : (_isHovered ? 1.01 : 1.0);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: widget.margin,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isHovered ? AppColors.primary.withValues(alpha: 0.35) : borderColor,
                width: _isHovered ? 1.2 : 1.0,
              ),
              boxShadow: widget.customShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? (_isHovered ? 0.3 : 0.18) : (_isHovered ? 0.08 : 0.03)),
                      blurRadius: _isHovered ? 14 : 8,
                      offset: Offset(0, _isHovered ? 6 : 2),
                    ),
                  ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
