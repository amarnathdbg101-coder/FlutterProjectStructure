import 'dart:io';
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
  int maxDimension = 1280,
  int quality = 85,
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
    if (params.maxDimension > 0 &&
        (upright.width > params.maxDimension || upright.height > params.maxDimension)) {
      if (upright.width >= upright.height) {
        upright = img.copyResize(upright, width: params.maxDimension);
      } else {
        upright = img.copyResize(upright, height: params.maxDimension);
      }
    }

    final encoded = img.encodeJpg(upright, quality: params.quality);
    return Uint8List.fromList(encoded);
  } catch (e) {
    return params.rawBytes;
  }
}

/// Bakes EXIF orientation into raw image bytes and optionally downscales it.
/// Executes in a background isolate to keep Flutter's UI running smoothly at 60fps.
Future<Uint8List> normalizeBytes(
  Uint8List rawBytes, {
  int maxDimension = 1280,
  int quality = 85,
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
