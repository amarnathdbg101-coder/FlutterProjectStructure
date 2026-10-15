// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using Web SpeechSynthesis API

void speakTextWeb(String text, double rate, void Function() onEnd) {
  try {
    html.window.speechSynthesis?.cancel();

    final utterance = html.SpeechSynthesisUtterance(text);
    utterance.rate = rate;
    utterance.pitch = 1.0;
    utterance.lang = 'en-US';

    utterance.onEnd.listen((_) {
      onEnd();
    });

    utterance.onError.listen((_) {
      onEnd();
    });

    html.window.speechSynthesis?.speak(utterance);
  } catch (_) {
    onEnd();
  }
}

void pauseTextWeb() {
  try {
    html.window.speechSynthesis?.pause();
  } catch (_) {}
}

void resumeTextWeb() {
  try {
    html.window.speechSynthesis?.resume();
  } catch (_) {}
}

void stopTextWeb() {
  try {
    html.window.speechSynthesis?.cancel();
  } catch (_) {}
}
