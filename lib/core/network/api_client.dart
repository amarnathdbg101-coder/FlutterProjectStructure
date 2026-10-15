import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Register Auth Interceptor for automatic Bearer token injection
    dio.interceptors.add(AuthInterceptor());

    // Optional logger interceptor in debug mode
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  static String handleError(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return 'Cloud server so raha tha aur abhi wake up ho raha hai (Render Cold Start). Kripya 10-15 seconds baad dobara try karein!';
      }
      if (statusCode == 429) {
        return 'AI rate limit exceed ho gaya hai. Kripya 1 minute baad try karein ya custom API key use karein.';
      }
      if (statusCode == 401) {
        return 'Session expire ho gaya hai. Kripya dobara login karein.';
      }

      if (error.response?.data != null && error.response?.data is Map) {
        final data = error.response!.data as Map;
        if (data.containsKey('error')) {
          return data['error'].toString();
        }
        if (data.containsKey('message')) {
          return data['message'].toString();
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Server ne response dene me zyada waqt liya (Timeout). Kripya thodi der baad dobara koshish karein.';
        case DioExceptionType.connectionError:
          return 'Backend server se connect nahi ho pa raha hai. Kya server running hai (${ApiConstants.baseUrl})?';
        default:
          final rawMsg = error.message ?? '';
          if (rawMsg.contains('502') || rawMsg.contains('503') || rawMsg.contains('504')) {
            return 'Cloud server so raha tha aur abhi wake up ho raha hai (Render Cold Start). Kripya 10-15 seconds baad dobara try karein!';
          }
          return rawMsg.isNotEmpty ? rawMsg : 'Network error occurred. Kripya dobara koshish karein.';
      }
    }
    final errStr = error.toString();
    if (errStr.contains('502') || errStr.contains('503') || errStr.contains('504')) {
      return 'Cloud server so raha tha aur abhi wake up ho raha hai (Render Cold Start). Kripya 10-15 seconds baad dobara try karein!';
    }
    return errStr;
  }
}
