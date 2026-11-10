import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'app_icon_button.dart';

/// Universal Standardized Bottom Modal Sheet Container for ShopSilo.
/// Ensures consistent top drag handle, header layout, responsive height, and bottom action bars.
class AppModalSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottomActions;
  final VoidCallback? onClose;
  final double? maxHeightFactor;
  final EdgeInsetsGeometry padding;

  const AppModalSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.bottomActions,
    this.onClose,
    this.maxHeightFactor = 0.88,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  /// Static helper to trigger a standard modal sheet with consistent elevation and backdrop
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * (maxHeightFactor ?? 0.88),
        maxWidth: 600,
      ),
      margin: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Pull-Down Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: context.colorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colorTextPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    size: AppIconButtonSize.sm,
                    variant: AppIconButtonVariant.standard,
                    onPressed: onClose ?? () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),

            // 3. Scrollable Child Content
            Flexible(
              child: SingleChildScrollView(
                padding: padding,
                child: child,
              ),
            ),

            // 4. Sticky Bottom Action Bar (if provided)
            if (bottomActions != null) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: context.colorSurface,
                child: bottomActions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

