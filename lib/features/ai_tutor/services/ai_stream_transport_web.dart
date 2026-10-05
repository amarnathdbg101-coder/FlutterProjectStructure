import 'dart:async';
import 'dart:html' as html;

Future<int> postSse({
  required Uri uri,
  required String body,
  required Map<String, String> headers,
  required void Function(String text) onText,
  Future<dynamic>? cancelFuture,
}) {
  final completer = Completer<int>();
  final request = html.HttpRequest()
    ..open('POST', uri.toString())
    ..responseType = 'text'
    ..timeout = 90000;
  var responseOffset = 0;

  headers.forEach(request.setRequestHeader);

  void emitAvailableText() {
    final responseText = request.responseText ?? '';
    if (responseText.length < responseOffset) responseOffset = 0;
    if (responseText.length == responseOffset) return;

    final delta = responseText.substring(responseOffset);
    responseOffset = responseText.length;
    onText(delta);
  }

  request.onProgress.listen((_) => emitAvailableText());
  request.onLoad.first.then((_) {
    emitAvailableText();
    if (!completer.isCompleted) completer.complete(request.status ?? 0);
  });
  request.onError.first.then((_) {
    if (!completer.isCompleted) completer.completeError(StateError('AI stream network request failed'));
  });
  request.onTimeout.first.then((_) {
    if (!completer.isCompleted) completer.completeError(TimeoutException('AI response stream timed out'));
  });
  cancelFuture?.then((_) {
    request.abort();
    if (!completer.isCompleted) completer.completeError(StateError('AI response stream cancelled'));
  });

  try {
    request.send(body);
  } catch (error) {
    if (!completer.isCompleted) completer.completeError(error);
  }

  return completer.future;
}