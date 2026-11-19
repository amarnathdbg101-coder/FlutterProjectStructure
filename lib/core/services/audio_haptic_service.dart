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

  /// Trigger medium haptic pulse and click sound on successful sale, payment, or expense record
  static void success() {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Trigger subtle selection feedback on tab change or filter chip tap
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Trigger heavy haptic feedback on delete or reverse entry action
  static void delete() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Trigger subtle haptic warning on unknown barcode or stock alert
  static void warning() {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Trigger urgent alert chime and heavy tactile pulses on new incoming pickup reservation
  static void orderAlert() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      Future.delayed(const Duration(milliseconds: 180), () {
        HapticFeedback.heavyImpact();
      });
    } catch (_) {}
  }
}
