import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const bool isProduction = true;
  static const String productionUrl = 'https://studysilobackend.onrender.com';

  static String get baseUrl {
    if (isProduction) {
      return productionUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (Platform.isAndroid) {
      return 'http://192.168.1.16:8080';
    }
    return 'http://localhost:8080';
  }

  // Health
  static const String health = '/health';
  static const String healthLive = '/health/live';
  static const String healthReady = '/health/ready';

  // Auth
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String profile = '/api/v1/auth/profile';

  // Academic Hierarchy
  static const String courses = '/api/v1/courses';
  static const String folders = '/api/v1/folders';
  static const String notes = '/api/v1/notes';

  // AI Tutor & Study Engines
  static const String aiDoubt = '/api/v1/ai/doubt';
  static const String aiDoubtStream = '/api/v1/ai/doubt/stream';
  static const String aiHistory = '/api/v1/ai/history';
  static const String aiSessions = '/api/v1/ai/sessions';
  static const String aiAnalyzeNotes = '/api/v1/ai/analyze-notes';
  static const String aiDiagram = '/api/v1/ai/diagram';

  // Adaptive Quizzes & Cognitive Profile
  static const String quizzes = '/api/v1/quizzes';
  static const String generateQuiz = '/api/v1/quizzes/generate';
  static const String cognitiveProfile = '/api/v1/profile/cognitive';

  // Offline Delta Sync & PDF Export
  static const String sync = '/api/v1/sync';
  static const String exportPdf = '/api/v1/export/pdf';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
