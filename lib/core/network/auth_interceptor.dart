import 'package:dio/dio.dart';
import '../services/ai_language_service.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final aiLang = AILanguageService.getSelectedLanguageSync();
    if (aiLang.isNotEmpty) {
      options.headers['X-AI-Language'] = aiLang;
    }
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid - clear session
      TokenStorage.clearSession();
    }
    super.onError(err, handler);
  }
}
