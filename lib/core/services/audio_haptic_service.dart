import 'package:flutter/services.dart';

/// Lightweight, zero-dependency tactile & haptic feedback helper for scanner guns and POS counter billing.
class AppAudioHapticFeedback {
  /// Trigger crisp tactile haptic pulse and click feedback on successful barcode scan
  static void scanSuccess() {
    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Trigger subtle haptic warning on unknown barcode or stock alert
  static void warning() {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
