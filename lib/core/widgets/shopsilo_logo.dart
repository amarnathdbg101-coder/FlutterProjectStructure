import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable, production-grade ShopSilo Brand Logo component.
class ShopSiloLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String? subtitle;
  final Color? textColor;
  final Color? iconBgColor;
  final Color? iconColor;

  const ShopSiloLogo({
    super.key,
    this.size = 36,
    this.showText = true,
    this.subtitle,
    this.textColor,
    this.iconBgColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ?? context.colorPrimaryLight;
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveTextColor = textColor ?? context.colorTextPrimary;

    final logoIcon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveIconBg,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: size * 0.58,
        color: effectiveIconColor,
      ),
    );

    if (!showText) return logoIcon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoIcon,
        SizedBox(width: size * 0.28),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ShopSilo',
              style: TextStyle(
                fontSize: size * 0.52,
                fontWeight: FontWeight.w900,
                color: effectiveTextColor,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w500,
                  color: context.colorTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
