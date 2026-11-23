import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result object encapsulating Google OAuth response
class GoogleAuthResult {
  final bool success;
  final String? idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  GoogleAuthResult({
    required this.success,
    this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });
}

/// Enterprise Google Sign-In service with Cross-Platform support:
/// - Native Credential Manager on Android
/// - Google Identity Services (GIS) on Web
/// - Seamless Dev Mock fallback on Desktop / Windows without blocking developers
class GoogleAuthService {
  static bool _initialized = false;

  /// Web Client ID (Backend Server Client ID)
  /// Used as serverClientId so Google issues an ID token verified by GoBackend.
  static const String serverClientId =
      '328255141048-v4r4fga1oas928b5imvh9jpbaemrc9a8.apps.googleusercontent.com';

  /// Android Client ID (Linked to com.starter.shopsilo + SHA-1 in Google Cloud Console)
  static const String androidClientId =
      '328255141048-13c1i03pd5iupfalc0pbqg4644bj6uh0.apps.googleusercontent.com';

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        await GoogleSignIn.instance.initialize(
          clientId: serverClientId,
        );
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await GoogleSignIn.instance.initialize(
          serverClientId: serverClientId,
          clientId: androidClientId,
        );
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[GoogleAuthService] Initialize notice: $e');
      _initialized = true;
    }
  }

  /// Triggers 1-Tap Google Sign-In with real Google Account selection
  static Future<GoogleAuthResult> signIn() async {
    try {
      await _ensureInitialized();

      // On Android, iOS, or Web: trigger native Google Sign-In prompt
      if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken != null && idToken.isNotEmpty) {
          return GoogleAuthResult(
            success: true,
            idToken: idToken,
            email: account.email,
            displayName: account.displayName,
            photoUrl: account.photoUrl,
          );
        } else {
          return GoogleAuthResult(
            success: false,
            error: 'Google authentication completed but no ID token was received.',
          );
        }
      }

      // On Windows/Linux desktop:
      // Google Play Services is only available on Android, iOS, and Web.
      return GoogleAuthResult(
        success: false,
        error:
            'Google Sign-In Android aur Chrome Web par supported hai. Real Google Account se test karne ke liye "flutter run -d chrome" ya Android device/emulator use karein.',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('canceled') ||
          errStr.contains('cancelled') ||
          errStr.contains('user_cancel')) {
        return GoogleAuthResult(
          success: false,
          error: 'Sign-in cancelled by user',
        );
      }

      return GoogleAuthResult(
        success: false,
        error: 'Google sign-in error: $e',
      );
    }
  }

  /// Explicit mock login used only in automated offline test environments
  static GoogleAuthResult devMockSignIn() {
    return GoogleAuthResult(
      success: true,
      idToken: 'dev_mock_google_token_123',
      email: 'google.dev@shopme.com',
      displayName: 'Google Dev User',
    );
  }

  /// Disconnect / Sign out from Google session
  static Future<void> signOut() async {
    try {
      if (kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
  }
}
