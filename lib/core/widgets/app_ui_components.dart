import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../utils/image_utils.dart';
import 'reusable/app_search_field.dart';

export 'reusable/app_reusable.dart';

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
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
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
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? trailingBadge;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.isAlert = false,
    this.iconColor,
    this.iconBgColor,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = isAlert
        ? context.colorErrorLight
        : (iconBgColor ?? context.colorSurfaceSubtle);
    final effectiveIconColor = isAlert
        ? AppColors.error
        : (iconColor ?? context.colorTextSecondary);

    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      border: isAlert
          ? Border.all(
              color: AppColors.error.withValues(alpha: 0.5),
              width: 1.2,
            )
          : null,
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: effectiveIconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.colorTextPrimary,
                    letterSpacing: -0.4,
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
                        fontWeight: FontWeight.w600,
                        color: isAlert
                            ? AppColors.error
                            : context.colorTextMuted,
                      ),
                    ),
                  ),
                  if (trailingBadge != null) trailingBadge!,
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
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.colorTextPrimary,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Standard, unified Back Arrow Button for AppBars.
/// Smartly pops Navigator if stack exists; otherwise falls back to [fallbackRoute] (default: '/merchant').
class AppBackButton extends StatelessWidget {
  final Color? color;
  final String fallbackRoute;
  final VoidCallback? onCustomBack;

  const AppBackButton({
    super.key,
    this.color,
    this.fallbackRoute = '/merchant',
    this.onCustomBack,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.arrow_back_rounded,
        color: color ?? context.colorTextPrimary,
        size: 22,
      ),
      tooltip: context.isHindi ? 'वापस जाएं' : 'Back',
      onPressed: () {
        if (onCustomBack != null) {
          onCustomBack!();
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(fallbackRoute);
        }
      },
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
  final Color? iconColor;
  final Color? iconBgColor;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ?? context.colorPrimaryLight;
    final effectiveIconColor = iconColor ?? AppColors.primary;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveIconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: effectiveIconColor, size: 20),
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
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: context.colorTextMuted,
          ),
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
                      child: Icon(
                        icon,
                        size: 16,
                        color: context.colorTextSecondary,
                      ),
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
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
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
            errorBuilder: (ctx, url, error) =>
                _buildInitials(context, initial, size),
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
            errorWidget: (ctx, url, error) =>
                _buildInitials(context, initial, size),
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
                border: Border.all(color: context.colorSurface, width: 2),
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
        border: Border.all(color: context.colorBorder, width: 1),
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

/// Product-search alias that preserves the shared search-field appearance.
class AppProductSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autoFocus;
  final bool enableVoice;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  const AppProductSearchBar({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.autoFocus = false,
    this.enableVoice = true,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    var isHindi = false;
    try {
      isHindi = context.isHindi;
    } catch (_) {
      isHindi = false;
    }

    return AppSearchField(
      controller: controller,
      hintText:
          hintText ??
          (isHindi ? 'सामान खोजें...' : 'Search products...'),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onClear: onClear,
      autofocus: autoFocus,
      enableVoice: enableVoice,
      debounceDuration: Duration.zero,
      focusNode: focusNode,
    );
  }
}

/// Universal Production-Grade Shimmer Skeleton Animation Widget.
/// Renders smooth animated gradient placeholder boxes for zero-flicker loading.
class AppShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Shimmer Skeleton List Placeholder
class AppListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const AppListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: itemHeight,
          child: Row(
            children: [
              const AppShimmer(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppShimmer(width: MediaQuery.of(context).size.width * 0.4, height: 14),
                    const SizedBox(height: 8),
                    AppShimmer(width: MediaQuery.of(context).size.width * 0.25, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const AppShimmer(width: 60, height: 18),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer Skeleton Grid Placeholder
class AppGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const AppGridSkeleton({
    super.key,
    this.itemCount = 8,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: AppShimmer(borderRadius: BorderRadius.all(Radius.circular(8)))),
              SizedBox(height: 8),
              AppShimmer(width: 100, height: 12),
              SizedBox(height: 6),
              AppShimmer(width: 60, height: 14),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer Skeleton KPI Stat Card Placeholder
class AppStatCardSkeleton extends StatelessWidget {
  const AppStatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppShimmer(width: 80, height: 12),
              AppShimmer(width: 24, height: 24, borderRadius: BorderRadius.all(Radius.circular(8))),
            ],
          ),
          SizedBox(height: 12),
          AppShimmer(width: 110, height: 22),
          SizedBox(height: 6),
          AppShimmer(width: 70, height: 10),
        ],
      ),
    );
  }
}

/// Smooth cross-fade transition widget for switching between loading skeleton and content
class AppSmoothTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AppSmoothTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: child,
    );
  }
}
