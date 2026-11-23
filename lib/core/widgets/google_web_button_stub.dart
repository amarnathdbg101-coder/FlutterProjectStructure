import 'package:flutter/material.dart';

/// Non-web platforms stub (returns null so custom button is shown)
Widget? buildGoogleSignInWebButton({
  required void Function(String idToken) onIdTokenReceived,
  required void Function(String error) onError,
}) {
  return null;
}
