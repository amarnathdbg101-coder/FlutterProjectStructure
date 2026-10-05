Future<int> postSse({
  required Uri uri,
  required String body,
  required Map<String, String> headers,
  required void Function(String text) onText,
  Future<dynamic>? cancelFuture,
}) {
  throw UnsupportedError('Use the platform HTTP client for streaming on this platform.');
}