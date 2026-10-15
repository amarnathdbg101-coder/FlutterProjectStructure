import 'ai_tts_stub.dart'
    if (dart.library.html) 'ai_tts_web.dart' as platform;

void speakTextWeb(String text, double rate, void Function() onEnd) {
  platform.speakTextWeb(text, rate, onEnd);
}

void pauseTextWeb() {
  platform.pauseTextWeb();
}

void resumeTextWeb() {
  platform.resumeTextWeb();
}

void stopTextWeb() {
  platform.stopTextWeb();
}
