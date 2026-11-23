import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

Widget? buildGoogleSignInWebButton({
  required void Function(String idToken) onIdTokenReceived,
  required void Function(String error) onError,
}) {
  return _GoogleWebButton(
    onIdTokenReceived: onIdTokenReceived,
    onError: onError,
  );
}

class _GoogleWebButton extends StatefulWidget {
  final void Function(String idToken) onIdTokenReceived;
  final void Function(String error) onError;

  const _GoogleWebButton({
    required this.onIdTokenReceived,
    required this.onError,
  });

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final idToken = event.user.authentication.idToken;
          if (idToken != null && idToken.isNotEmpty) {
            widget.onIdTokenReceived(idToken);
          } else {
            widget.onError('No ID token received from Google.');
          }
        }
      },
      onError: (err) {
        widget.onError(err.toString());
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      child: web_only.renderButton(
        configuration: web_only.GSIButtonConfiguration(
          theme: web_only.GSIButtonTheme.outline,
          size: web_only.GSIButtonSize.large,
          text: web_only.GSIButtonText.continueWith,
          shape: web_only.GSIButtonShape.rectangular,
          logoAlignment: web_only.GSIButtonLogoAlignment.left,
        ),
      ),
    );
  }
}
