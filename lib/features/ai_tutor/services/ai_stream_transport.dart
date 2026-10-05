import 'ai_stream_transport_stub.dart'
    if (dart.library.html) 'ai_stream_transport_web.dart' as platform;

Future<int> postSse({
  required Uri uri,
  required String body,
  required Map<String, String> headers,
  required void Function(String text) onText,
  Future<dynamic>? cancelFuture,
}) {
  return platform.postSse(uri: uri, body: body, headers: headers, onText: onText, cancelFuture: cancelFuture);
}