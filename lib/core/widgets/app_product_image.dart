import 'dart:io' show File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/image_utils.dart';

/// Universal responsive, crash-proof Product Image component.
/// Uses CachedNetworkImage for high-speed disk and memory caching (0ms load),
/// safely renders Web Blob URLs, Cloudflare R2 / Backend CDN images, and local files
/// without pixel overflow or platform exceptions on Web, Android, iOS, and Desktop.
class AppProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? backgroundColor;
  final bool expand;

  const AppProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackIconSize = 36,
    this.backgroundColor,
    this.expand = false,
  });

  Widget _buildFallback(BuildContext context, double? w, double? h) {
    Widget fallback = Container(
      width: w,
      height: h,
      color: backgroundColor ?? AppColors.getSurfaceSubtle(context),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: AppColors.getTextMuted(context),
          size: fallbackIconSize,
        ),
      ),
    );

    if (borderRadius != null) {
      fallback = ClipRRect(
        borderRadius: borderRadius!,
        child: fallback,
      );
    }
    return fallback;
  }

  Widget _buildLoading(BuildContext context, double? w, double? h) {
    Widget loading = Container(
      width: w,
      height: h,
      color: backgroundColor ?? AppColors.getSurfaceSubtle(context),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      loading = ClipRRect(
        borderRadius: borderRadius!,
        child: loading,
      );
    }
    return loading;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = expand ? (width ?? double.infinity) : width;
    final effectiveHeight = expand ? (height ?? double.infinity) : height;

    final raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      return _buildFallback(context, effectiveWidth, effectiveHeight);
    }

    Widget imageWidget;

    // 1. Flutter Web Blob URL (e.g. blob:http://localhost:54321/...) or Data URI
    if (raw.startsWith('blob:') || raw.startsWith('data:')) {
      imageWidget = Image.network(
        raw,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _buildLoading(context, effectiveWidth, effectiveHeight);
        },
        errorBuilder: (c, e, s) => _buildFallback(context, effectiveWidth, effectiveHeight),
      );
    }
    // 2. Flutter Web Platform (Google Chrome): Use Image.network with Chrome's native Disk & Memory Cache
    // Eliminates the CachedNetworkImage web disposal/blanking bug when switching routes
    else if (kIsWeb) {
      final formatted = formatImageUrl(raw);
      if (formatted.isNotEmpty) {
        imageWidget = Image.network(
          formatted,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return _buildLoading(context, effectiveWidth, effectiveHeight);
          },
          errorBuilder: (c, e, s) => _buildFallback(context, effectiveWidth, effectiveHeight),
        );
      } else {
        return _buildFallback(context, effectiveWidth, effectiveHeight);
      }
    }
    // 3. Native Mobile / Desktop: Local device cache / filesystem path
    else if (isLocalFilePath(raw)) {
      try {
        final file = File(raw);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            width: effectiveWidth,
            height: effectiveHeight,
            fit: fit,
            alignment: alignment,
            errorBuilder: (c, e, s) => _buildFallback(context, effectiveWidth, effectiveHeight),
          );
        } else {
          return _buildFallback(context, effectiveWidth, effectiveHeight);
        }
      } catch (_) {
        return _buildFallback(context, effectiveWidth, effectiveHeight);
      }
    }
    // 4. Native Mobile (Android/iOS): CachedNetworkImage with local SQLite / disk cache
    else {
      final formatted = formatImageUrl(raw);
      if (formatted.isNotEmpty && !isLocalFilePath(raw)) {
        imageWidget = CachedNetworkImage(
          imageUrl: formatted,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          alignment: alignment,
          memCacheWidth: (effectiveWidth != null && effectiveWidth.isFinite && effectiveWidth > 0)
              ? (effectiveWidth * 2).clamp(100, 1200).toInt()
              : null,
          memCacheHeight: (effectiveHeight != null && effectiveHeight.isFinite && effectiveHeight > 0)
              ? (effectiveHeight * 2).clamp(100, 1200).toInt()
              : null,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (ctx, url) => _buildLoading(context, effectiveWidth, effectiveHeight),
          errorWidget: (ctx, url, error) => _buildFallback(context, effectiveWidth, effectiveHeight),
        );
      } else {
        return _buildFallback(context, effectiveWidth, effectiveHeight);
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
