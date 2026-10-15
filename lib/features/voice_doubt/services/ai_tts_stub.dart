/// Stub implementation for non-web platforms (Android, iOS, Windows, macOS, Linux)
library;

void speakTextWeb(String text, double rate, void Function() onEnd) {
  // Native non-web TTS stub - completes immediately
  onEnd();
}

void pauseTextWeb() {}

void resumeTextWeb() {}

void stopTextWeb() {}
