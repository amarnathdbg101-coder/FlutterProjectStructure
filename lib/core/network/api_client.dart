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
          return 'Connection timed out. Check your backend server.';
        case DioExceptionType.connectionError:
          return 'Cannot connect to backend. Is Go server running at ${ApiConstants.baseUrl}?';
        default:
          return error.message ?? 'An unexpected network error occurred.';
      }
    }
    return error.toString();
  }
}
