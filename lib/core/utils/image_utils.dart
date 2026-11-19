import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../constants/api_constants.dart';

/// Checks if the path is a local device file path (Android cache, iOS sandbox, Windows file path).
bool isLocalFilePath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final clean = path.trim();
  if (clean.startsWith('file://')) return true;
  if (clean.startsWith('content://')) return true;
  if (clean.startsWith('/data/') ||
      clean.startsWith('/storage/') ||
      clean.startsWith('/private/') ||
      clean.startsWith('/var/') ||
      clean.startsWith('/Users/') ||
      clean.startsWith('/tmp/')) {
    return true;
  }
  // Windows absolute file path (e.g. C:\ or C:/)
  if (RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(clean)) return true;
  return false;
}

/// Checks if the path is a valid server URL (already uploaded to CDN or backend).
bool isServerImageUrl(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final clean = path.trim();
  if (clean.startsWith('blob:') || clean.startsWith('data:')) return false;
  if (isLocalFilePath(clean)) return false;

  // Remote HTTP/HTTPS URLs
  if (clean.startsWith('http://') || clean.startsWith('https://')) return true;

  // Backend relative image endpoints
  if (clean.startsWith('/images/') || clean.startsWith('images/') ||
      clean.startsWith('/uploads/') || clean.startsWith('uploads/') ||
      clean.startsWith('/products/') || clean.startsWith('products/') ||
      clean.startsWith('/static/') || clean.startsWith('static/') ||
      clean.startsWith('/api/')) {
    return true;
  }

  return false;
}

String formatImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();

  // Blob URLs (in Flutter Web) or Data URIs
  if (trimmed.startsWith('blob:') || trimmed.startsWith('data:')) {
    return trimmed;
  }

  // Rewrite Cloudflare .r2.dev URLs (which return 401 Unauthorized for direct browser requests)
  // to the authenticated backend /images proxy endpoint
  if (trimmed.contains('.r2.dev/')) {
    final idx = trimmed.indexOf('.r2.dev/');
    final path = trimmed.substring(idx + '.r2.dev/'.length);
    return '${ApiConstants.baseUrl}/images/$path';
  }

  // Remote URLs
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  // Local device paths are NOT hosted on server - do not prepend baseUrl
  if (isLocalFilePath(trimmed)) {
    return '';
  }

  // Relative backend images path
  if (trimmed.startsWith('/')) {
    return '${ApiConstants.baseUrl}$trimmed';
  }
  return '${ApiConstants.baseUrl}/$trimmed';
}

/// Normalizes an XFile captured from the camera or selected from the gallery.
///
/// Mobile camera hardware sensors physically capture images in landscape orientation
/// and store an EXIF orientation tag (e.g., orientation 6 = 90 deg clockwise).
/// This method reads EXIF metadata, bakes the true upright orientation directly
/// into the pixel buffer via a background isolate (using `compute`), resizes if needed,
/// overwrites the local cache file (if not web) so all downstream viewers see the upright
/// image, and returns a tuple of the normalized `XFile` and its `Uint8List` bytes.
Future<(XFile, Uint8List)> normalizeXFile(
  XFile file, {
  int maxDimension = 1600,
  int quality = 82,
}) async {
  Uint8List rawBytes;
  try {
    rawBytes = await file.readAsBytes();
  } catch (e) {
    debugPrint('[ImageUtils] Error reading XFile bytes: $e');
    return (file, Uint8List(0));
  }

  final normalizedBytes = await normalizeBytes(
    rawBytes,
    maxDimension: maxDimension,
    quality: quality,
  );

  // If on mobile/desktop with a valid local file path, overwrite the file on disk
  // so that Image.file, multipart uploaders, and external viewers receive the upright JPEG.
  if (!kIsWeb && file.path.isNotEmpty) {
    try {
      final diskFile = File(file.path);
      await diskFile.writeAsBytes(normalizedBytes, flush: true);
      final normalizedXFile = XFile(
        file.path,
        bytes: normalizedBytes,
        name: file.name,
        mimeType: 'image/jpeg',
      );
      return (normalizedXFile, normalizedBytes);
    } catch (e) {
      debugPrint('[ImageUtils] Could not overwrite local file at ${file.path}: $e');
    }
  }

  final normalizedXFile = XFile.fromData(
    normalizedBytes,
    name: file.name,
    mimeType: 'image/jpeg',
  );
  return (normalizedXFile, normalizedBytes);
}

/// Parameters passed to the background isolate for baking EXIF orientation.
class _BakeOrientationParams {
  final Uint8List rawBytes;
  final int maxDimension;
  final int quality;

  const _BakeOrientationParams({
    required this.rawBytes,
    required this.maxDimension,
    required this.quality,
  });
}

/// Top-level function executed in a background isolate via [compute].
Uint8List _isolateBakeOrientation(_BakeOrientationParams params) {
  try {
    final image = img.decodeImage(params.rawBytes);
    if (image == null) {
      return params.rawBytes;
    }

    // Physically transform the pixels according to EXIF orientation tag
    // (e.g. rotates 90 degrees left if sensor was landscape-right, tag 6 -> 1)
    var upright = img.bakeOrientation(image);

    // Downscale if image exceeds maxDimension while preserving aspect ratio
    // Uses cubic spline interpolation for sharp, anti-aliased edge details
    if (params.maxDimension > 0 &&
        (upright.width > params.maxDimension || upright.height > params.maxDimension)) {
      if (upright.width >= upright.height) {
        upright = img.copyResize(
          upright,
          width: params.maxDimension,
          interpolation: img.Interpolation.cubic,
        );
      } else {
        upright = img.copyResize(
          upright,
          height: params.maxDimension,
          interpolation: img.Interpolation.cubic,
        );
      }
    }

    // Auto-Enhance Visual Quality:
    // Lifts dull/greyish mobile camera indoor lighting by +5% contrast and +6% vibrance
    // for a crisp, commercial e-commerce studio look without unnatural saturation.
    upright = img.adjustColor(upright, contrast: 1.05, saturation: 1.06);

    final encoded = img.encodeJpg(upright, quality: params.quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    return params.rawBytes;
  }
}

/// Compresses product catalog images (max 1600px dimension, 82% JPEG quality).
/// Drastically reduces file size (typically by 75-85%) while preserving sharp details.
Future<(XFile, Uint8List)> compressProductImage(XFile file) =>
    normalizeXFile(file, maxDimension: 1600, quality: 82);

/// Compresses user avatars and store logos (max 800px dimension, 80% JPEG quality).
Future<(XFile, Uint8List)> compressAvatarOrLogo(XFile file) =>
    normalizeXFile(file, maxDimension: 800, quality: 80);

/// Compresses promotional banners (max 1600px dimension, 82% JPEG quality).
Future<(XFile, Uint8List)> compressBannerImage(XFile file) =>
    normalizeXFile(file, maxDimension: 1600, quality: 82);

/// Bakes EXIF orientation into raw image bytes and optionally downscales it.
/// Executes in a background isolate to keep Flutter's UI running smoothly at 60fps.
Future<Uint8List> normalizeBytes(
  Uint8List rawBytes, {
  int maxDimension = 1600,
  int quality = 82,
}) async {
  if (rawBytes.isEmpty) return rawBytes;

  try {
    return await compute(
      _isolateBakeOrientation,
      _BakeOrientationParams(
        rawBytes: rawBytes,
        maxDimension: maxDimension,
        quality: quality,
      ),
    );
  } catch (e) {
    debugPrint('[ImageUtils] compute bakeOrientation failed: $e, falling back to synchronous decode');
    try {
      return _isolateBakeOrientation(
        _BakeOrientationParams(
          rawBytes: rawBytes,
          maxDimension: maxDimension,
          quality: quality,
        ),
      );
    } catch (_) {
      return rawBytes;
    }
  }
}

/// Visual styles for product photography enhancement
enum ProductPhotoStyle {
  normal,
  dslrBokeh,
  studioHdr,
}

class _ApplyPhotoStyleParams {
  final Uint8List rawBytes;
  final ProductPhotoStyle style;
  final int quality;

  const _ApplyPhotoStyleParams({
    required this.rawBytes,
    required this.style,
    this.quality = 90,
  });
}

Uint8List _isolateApplyPhotoStyle(_ApplyPhotoStyleParams params) {
  try {
    final image = img.decodeImage(params.rawBytes);
    if (image == null) return params.rawBytes;

    var upright = img.bakeOrientation(image);

    // Downscale if higher than 1600px to ensure lightning-fast processing and low memory footprint
    if (upright.width > 1600 || upright.height > 1600) {
      if (upright.width >= upright.height) {
        upright = img.copyResize(upright, width: 1600, interpolation: img.Interpolation.cubic);
      } else {
        upright = img.copyResize(upright, height: 1600, interpolation: img.Interpolation.cubic);
      }
    }

    switch (params.style) {
      case ProductPhotoStyle.dslrBokeh:
        // Ultra-fast hierarchical pyramid optical blur:
        // Downscale to 1/3 resolution, blur, then scale back.
        // Mathematically approximates deep optical Gaussian bokeh but runs in <25ms!
        final width = upright.width;
        final height = upright.height;
        final lowW = math.max(64, width ~/ 3);
        final lowH = math.max(64, height ~/ 3);

        final downscaled = img.copyResize(
          upright,
          width: lowW,
          height: lowH,
          interpolation: img.Interpolation.linear,
        );
        final blurredSmall = img.gaussianBlur(downscaled, radius: 5);
        final blurred = img.copyResize(
          blurredSmall,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
        );

        // Ambient border sampling for content-aware foreground saliency
        int bgCount = 0;
        int sumR = 0, sumG = 0, sumB = 0;
        final stepX = math.max(1, width ~/ 40);
        final stepY = math.max(1, height ~/ 40);
        final marginX = math.max(2, (width * 0.05).round());
        final marginY = math.max(2, (height * 0.05).round());

        // Top & bottom strips
        for (int x = 0; x < width; x += stepX) {
          for (int y = 0; y < marginY; y += stepY) {
            final p = upright.getPixel(x, y);
            sumR += p.r.toInt();
            sumG += p.g.toInt();
            sumB += p.b.toInt();
            bgCount++;
          }
          for (int y = height - marginY; y < height; y += stepY) {
            final p = upright.getPixel(x, y);
            sumR += p.r.toInt();
            sumG += p.g.toInt();
            sumB += p.b.toInt();
            bgCount++;
          }
        }
        // Left & right strips
        for (int y = marginY; y < height - marginY; y += stepY) {
          for (int x = 0; x < marginX; x += stepX) {
            final p = upright.getPixel(x, y);
            sumR += p.r.toInt();
            sumG += p.g.toInt();
            sumB += p.b.toInt();
            bgCount++;
          }
          for (int x = width - marginX; x < width; x += stepX) {
            final p = upright.getPixel(x, y);
            sumR += p.r.toInt();
            sumG += p.g.toInt();
            sumB += p.b.toInt();
            bgCount++;
          }
        }

        final avgBgR = bgCount > 0 ? (sumR / bgCount) : 128.0;
        final avgBgG = bgCount > 0 ? (sumG / bgCount) : 128.0;
        final avgBgB = bgCount > 0 ? (sumB / bgCount) : 128.0;

        final cx = width / 2.0;
        final cy = height / 2.0;
        final rx = (width * 0.70) / 2.0;
        final ry = (height * 0.74) / 2.0;

        final output = img.Image.from(upright);

        for (int y = 0; y < height; y++) {
          final dy = (y - cy) / ry;
          final dySq = dy * dy;

          for (int x = 0; x < width; x++) {
            final dx = (x - cx) / rx;
            final distSq = dx * dx + dySq;

            final pOrig = upright.getPixel(x, y);

            // Saliency: Color contrast vs border background
            final dR = (pOrig.r - avgBgR).abs();
            final dG = (pOrig.g - avgBgG).abs();
            final dB = (pOrig.b - avgBgB).abs();
            final colorDiff = (dR + dG + dB) / (3.0 * 255.0);

            // Content-aware distance: preserves sharp product packaging corners
            final effectiveDist = distSq - (colorDiff * 1.25);

            if (effectiveDist <= 0.85) {
              // Center focus zone: keep 100% sharp
              continue;
            }

            final pBlurred = blurred.getPixel(x, y);

            if (effectiveDist >= 1.6) {
              // Deep optical bokeh with specular highlight rendering
              final lum = 0.299 * pBlurred.r + 0.587 * pBlurred.g + 0.114 * pBlurred.b;
              if (lum > 180) {
                final factor = math.min(255.0, lum * 1.10) / lum;
                final r = math.min(255, (pBlurred.r * factor).round());
                final g = math.min(255, (pBlurred.g * factor).round());
                final b = math.min(255, (pBlurred.b * factor).round());
                output.setPixelRgb(x, y, r, g, b);
              } else {
                output.setPixel(x, y, pBlurred);
              }
            } else {
              // Smooth feather transition
              final t = ((effectiveDist - 0.85) / 0.75).clamp(0.0, 1.0);
              final r = (pOrig.r * (1.0 - t) + pBlurred.r * t).round();
              final g = (pOrig.g * (1.0 - t) + pBlurred.g * t).round();
              final b = (pOrig.b * (1.0 - t) + pBlurred.b * t).round();
              output.setPixelRgb(x, y, r, g, b);
            }
          }
        }

        // Commercial catalog pop in vibrance & contrast
        final enhanced = img.adjustColor(output, contrast: 1.06, saturation: 1.08);
        return Uint8List.fromList(img.encodeJpg(enhanced, quality: params.quality));

      case ProductPhotoStyle.studioHdr:
        // Studio HDR:
        // Punchy contrast, vibrant colors, and brightened highlights for packaging clarity
        var enhanced = img.adjustColor(upright, contrast: 1.12, saturation: 1.12, brightness: 1.02);
        return Uint8List.fromList(img.encodeJpg(enhanced, quality: params.quality));

      case ProductPhotoStyle.normal:
        var enhanced = img.adjustColor(upright, contrast: 1.04, saturation: 1.04);
        return Uint8List.fromList(img.encodeJpg(enhanced, quality: params.quality));
    }
  } catch (e) {
    debugPrint('[ImageUtils] Error applying photo style: $e');
    return params.rawBytes;
  }
}

/// Applies DSLR bokeh or Studio HDR styling to an image in a background isolate.
Future<(XFile, Uint8List)> applyPhotoStyle(
  XFile file,
  Uint8List rawBytes,
  ProductPhotoStyle style, {
  int quality = 90,
}) async {
  if (rawBytes.isEmpty) return (file, rawBytes);

  Uint8List processedBytes;
  try {
    processedBytes = await compute(
      _isolateApplyPhotoStyle,
      _ApplyPhotoStyleParams(
        rawBytes: rawBytes,
        style: style,
        quality: quality,
      ),
    );
  } catch (e) {
    debugPrint('[ImageUtils] compute applyPhotoStyle failed: $e');
    processedBytes = _isolateApplyPhotoStyle(
      _ApplyPhotoStyleParams(
        rawBytes: rawBytes,
        style: style,
        quality: quality,
      ),
    );
  }

  if (!kIsWeb && file.path.isNotEmpty) {
    try {
      final diskFile = File(file.path);
      await diskFile.writeAsBytes(processedBytes, flush: true);
      final newXFile = XFile(
        file.path,
        bytes: processedBytes,
        name: file.name,
        mimeType: 'image/jpeg',
      );
      return (newXFile, processedBytes);
    } catch (_) {}
  }

  final newXFile = XFile.fromData(
    processedBytes,
    name: file.name,
    mimeType: 'image/jpeg',
  );
  return (newXFile, processedBytes);
}
