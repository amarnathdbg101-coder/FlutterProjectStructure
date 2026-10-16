import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysilo/core/network/auth_interceptor.dart';
import 'package:studysilo/core/services/ai_language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AILanguageService.init();
  });

  group('AILanguageService Tests', () {
    test('Default language is auto', () {
      expect(AILanguageService.getSelectedLanguageSync(), equals('auto'));
      final opt = AILanguageService.getOption('auto');
      expect(opt.name, contains('Auto'));
      expect(opt.icon, equals('🌐'));
    });

    test('Setting language persists and updates sync getter', () async {
      await AILanguageService.setLanguage('hinglish');
      expect(AILanguageService.getSelectedLanguageSync(), equals('hinglish'));

      final opt = AILanguageService.getOption('hinglish');
      expect(opt.name, equals('Hinglish'));
      expect(opt.icon, equals('🇮🇳'));

      // Test English
      await AILanguageService.setLanguage('english');
      expect(AILanguageService.getSelectedLanguageSync(), equals('english'));

      // Test Hindi
      await AILanguageService.setLanguage('hindi');
      expect(AILanguageService.getSelectedLanguageSync(), equals('hindi'));
    });

    test('Unsupported language falls back to auto safely', () async {
      await AILanguageService.setLanguage('klingon_nonexistent');
      expect(AILanguageService.getSelectedLanguageSync(), equals('auto'));
    });
  });

  group('AuthInterceptor X-AI-Language Header Tests', () {
    test('AuthInterceptor attaches X-AI-Language to Dio RequestOptions', () async {
      await AILanguageService.setLanguage('hinglish');

      final interceptor = AuthInterceptor();
      final options = RequestOptions(path: '/api/v1/mindmaps/generate');
      
      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['X-AI-Language'], equals('hinglish'));
      expect(options.headers['Content-Type'], equals('application/json'));
    });

    test('AuthInterceptor changes header when language changes', () async {
      await AILanguageService.setLanguage('bengali');

      final interceptor = AuthInterceptor();
      final options = RequestOptions(path: '/api/v1/quiz/generate');
      
      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['X-AI-Language'], equals('bengali'));
    });
  });
}
