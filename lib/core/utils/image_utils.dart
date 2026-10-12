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

