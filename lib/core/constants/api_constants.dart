import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // ⚡ 1-Click Environment Switcher:
  // Set isProduction to true when deploying backend to Render / Railway / AWS / VPS.
  static const bool isProduction = false;
  static const String productionUrl = 'https://api.myproductionapp.com';

  static String get baseUrl {
    if (isProduction) {
      return productionUrl;
    }
    // Web safe check:
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Android Emulator requires 'http://10.0.2.2:8080' to talk to host PC
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    // Windows Desktop, macOS, Linux
    return 'http://localhost:8080';
  }

  // API Endpoints (matching Go Backend routes)
  static const String health = '/health';
  static const String healthLive = '/health/live';
  static const String healthReady = '/health/ready';

  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String profile = '/api/v1/auth/profile';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
