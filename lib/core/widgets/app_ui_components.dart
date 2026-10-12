import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/image_utils.dart';

/// Standard, reusable, production-grade Card container.
/// Ensures 100% visual consistency across Light and Dark themes.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: border ?? Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Standardized KPI Statistic Card.
/// Used on Dashboard, POS, Khata, and Expenses for clean, cohesive metrics.
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isAlert;
  final Widget? trailingBadge;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.isAlert = false,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      border: isAlert ? Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 1.2) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isAlert ? context.colorErrorLight : context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isAlert ? AppColors.error : context.colorTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.colorTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isAlert ? AppColors.error : context.colorTextMuted,
                      ),
                    ),
                  ),
                  ?trailingBadge,
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Standard Section Header across all pages.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colorTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Standard Quick Action Tile.
/// Replaces inconsistent rainbow buttons with clean, balanced actions.
class AppActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colorTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.colorTextMuted),
        ],
      ),
    );
  }
}

/// Standard Executive Financial Summary Banner.
/// Replaces loud, harsh gradients with a calm, premium container.
class AppSummaryBanner extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppSummaryBanner({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: context.colorTextSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.colorTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.colorTextMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null && actionLabel != null)
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(110, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Standard Status Badge.
enum AppBadgeType { neutral, success, warning, error, primary }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeType type;

  const AppBadge({
    super.key,
    required this.label,
    this.type = AppBadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case AppBadgeType.success:
        bg = context.colorSuccessLight;
        fg = AppColors.success;
        break;
      case AppBadgeType.warning:
        bg = context.colorWarningLight;
        fg = AppColors.warning;
        break;
      case AppBadgeType.error:
        bg = context.colorErrorLight;
        fg = AppColors.error;
        break;
      case AppBadgeType.primary:
        bg = context.colorPrimaryLight;
        fg = AppColors.primary;
        break;
      case AppBadgeType.neutral:
        bg = context.colorSurfaceSubtle;
        fg = context.colorTextSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Standard, production-grade Avatar component.
/// Seamlessly handles network images with caching, fallback initials, loading state, and edit camera badge.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool isEditable;
  final bool isLoading;
  final VoidCallback? onEditTap;
  final IconData badgeIcon;
  final Color? backgroundColor;
  final Color? textColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.isEditable = false,
    this.isLoading = false,
    this.onEditTap,
    this.badgeIcon = Icons.camera_alt_rounded,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M';
    final size = radius * 2;

    Widget avatarContent;
    final formattedUrl = formatImageUrl(imageUrl);
    if (formattedUrl.isNotEmpty) {
      if (kIsWeb) {
        avatarContent = ClipOval(
          child: Image.network(
            formattedUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return Container(
                width: size,
                height: size,
                color: backgroundColor ?? context.colorPrimaryLight,
                child: Center(
                  child: SizedBox(
                    width: radius * 0.7,
                    height: radius * 0.7,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor ?? AppColors.primary,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (ctx, url, error) => _buildInitials(context, initial, size),
          ),
        );
      } else {
        avatarContent = ClipOval(
          child: CachedNetworkImage(
            imageUrl: formattedUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(
              width: size,
              height: size,
              color: backgroundColor ?? context.colorPrimaryLight,
              child: Center(
                child: SizedBox(
                  width: radius * 0.7,
                  height: radius * 0.7,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor ?? AppColors.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (ctx, url, error) => _buildInitials(context, initial, size),
          ),
        );
      }
    } else {
      avatarContent = _buildInitials(context, initial, size);
    }

    Widget content = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        if (isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Center(
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        if (isEditable && !isLoading)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(radius > 30 ? 6 : 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colorSurface,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                badgeIcon,
                size: radius > 30 ? 14 : 11,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );

    if (onEditTap != null && !isLoading) {
      return InkWell(
        onTap: onEditTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }

  Widget _buildInitials(BuildContext context, String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? context.colorPrimaryLight,
        border: Border.all(
          color: context.colorBorder,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.85,
            fontWeight: FontWeight.bold,
            color: textColor ?? AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Universal Reusable Product Search Bar with 1-Tap Clear & Barcode Scanner Integration.
/// Guarantees 100% design consistency across POS Billing, Inventory, Sales, and Procurement screens.
class AppProductSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onBarcodeScan;
  final bool showBarcodeScanner;
  final bool autoFocus;

  const AppProductSearchBar({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.onBarcodeScan,
    this.showBarcodeScanner = false,
    this.autoFocus = false,
  });

  @override
  State<AppProductSearchBar> createState() => _AppProductSearchBarState();
}

class _AppProductSearchBarState extends State<AppProductSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: context.colorTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autoFocus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Search products...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: context.colorTextMuted,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                if (widget.onChanged != null) widget.onChanged!('');
                if (widget.onClear != null) widget.onClear!();
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 14, color: context.colorTextMuted),
              ),
            ),
          if (widget.showBarcodeScanner && widget.onBarcodeScan != null) ...[
            if (hasText) const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onBarcodeScan,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 19, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


