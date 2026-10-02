import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/storage/token_storage.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    await TokenStorage.init();
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (TokenStorage.hasToken()) {
      context.read<AuthController>().fetchProfile();
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Flutter Starter App',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
