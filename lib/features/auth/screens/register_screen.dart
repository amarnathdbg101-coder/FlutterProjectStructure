import 'package:flutter/material.dart';
import 'login_screen.dart';

/// Clean Redirect/Wrapper for Registration.
/// With 1-Tap Google Authentication, Registration and Login are unified into a
/// single zero-friction 1-click Google onboarding flow.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
