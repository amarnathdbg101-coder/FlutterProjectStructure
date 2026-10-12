import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_response.dart';
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
  }

  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await dio.get(path, queryParameters: queryParameters);
      return ApiResponse.fromJson(res.data, (d) => d);
    } catch (e) {
      return ApiResponse.failure(handleError(e));
    }
  }

  Future<ApiResponse<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await dio.post(path, data: data, queryParameters: queryParameters);
      return ApiResponse.fromJson(res.data, (d) => d);
    } catch (e) {
      return ApiResponse.failure(handleError(e));
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Converts any technical, database, network, or server exception into
  /// clean, user-friendly, and actionable English or Hindi messages.
  static String handleError(dynamic error) {
    final isHindi = TokenStorage.getLanguage() == 'hi';

    if (error is DioException) {
      // 1. Check HTTP Status Code from Response
      final statusCode = error.response?.statusCode;

      // 2. Extract server-provided error message
      String? serverMsg;
      if (error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map) {
          if (data.containsKey('error') && data['error'] != null) {
            serverMsg = data['error'].toString();
          } else if (data.containsKey('message') && data['message'] != null) {
            serverMsg = data['message'].toString();
          } else if (data.containsKey('msg') && data['msg'] != null) {
            serverMsg = data['msg'].toString();
          }
        } else if (data is String && data.isNotEmpty) {
          // Ignore raw HTML pages (such as Cloudflare 502/504 errors)
          if (!data.contains('<html') && !data.contains('<!DOCTYPE') && data.length < 300) {
            serverMsg = data.trim();
          }
        }
      }

      // If server returned a meaningful message, sanitize database/technical internals
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return _sanitizeErrorMessage(serverMsg, isHindi: isHindi);
      }

      // 3. Fallback based on HTTP status code
      if (statusCode != null) {
        switch (statusCode) {
          case 400:
            return isHindi
                ? 'अमान्य अनुरोध। कृपया भरे गए विवरण की पुनः जांच करें।'
                : 'Invalid request. Please verify the entered details.';
          case 401:
            return isHindi
                ? 'आपका लॉगिन सत्र समाप्त हो गया है। कृपया पुनः लॉगिन करें।'
                : 'Your login session has expired. Please sign in again.';
          case 403:
            return isHindi
                ? 'इस कार्रवाई की अनुमति नहीं है। केवल अधिकृत मर्चेंट ही इसे कर सकते हैं।'
                : 'Access denied. You do not have permission to perform this action.';
          case 404:
            return isHindi
                ? 'अनुरोधित आइटम या डेटा सर्वर पर नहीं मिला।'
                : 'The requested item or record could not be found.';
          case 409:
            return isHindi
                ? 'यह आइटम या रिकॉर्ड पहले से मौजूद है।'
                : 'A record with these details already exists in your store.';
          case 422:
            return isHindi
                ? 'दर्ज किया गया डेटा अमान्य है। कृपया सभी फ़ील्ड सही से भरें।'
                : 'Validation error. Please verify the entered data.';
          case 429:
            return isHindi
                ? 'बहुत अधिक अनुरोध किए गए। कृपया 1 मिनट बाद पुनः प्रयास करें।'
                : 'Too many requests. Please wait a minute and try again.';
          case 500:
          case 502:
          case 503:
          case 504:
            return isHindi
                ? 'शॉपसाइलो सर्वर पर अस्थायी समस्या है। कृपया कुछ ही पलों में पुनः प्रयास करें।'
                : 'ShopSilo server is temporarily unavailable. Please try again shortly.';
        }
      }

      // 4. Network / Dio Exception Type Fallbacks
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return isHindi
              ? 'सर्वर से कनेक्ट होने में समय समाप्त हो गया। कृपया अपना इंटरनेट कनेक्शन जांचें।'
              : 'Connection timed out. Please check your internet connection.';
        case DioExceptionType.connectionError:
          return isHindi
              ? 'इंटरनेट या सर्वर से कनेक्शन नहीं बन पा रहा है। कृपया इंटरनेट जांचें।'
              : 'Cannot connect to ShopSilo server. Please verify your internet connection.';
        case DioExceptionType.cancel:
          return isHindi ? 'अनुरोध रद्द कर दिया गया।' : 'Request was cancelled.';
        default:
          final msg = error.message ?? '';
          if (msg.contains('SocketException') ||
              msg.contains('Connection refused') ||
              msg.contains('Network is unreachable')) {
            return isHindi
                ? 'इंटरनेट कनेक्शन उपलब्ध नहीं है। कृपया वाई-फाई या मोबाइल डेटा जांचें।'
                : 'No internet connection. Please verify your Wi-Fi or mobile data.';
          }
          return isHindi
              ? 'अस्थायी नेटवर्क समस्या उत्पन्न हुई। कृपया पुनः प्रयास करें।'
              : 'A network error occurred. Please try again.';
      }
    }

    // 5. Handle generic Dart errors / exceptions
    return _sanitizeErrorMessage(error.toString(), isHindi: isHindi);
  }

  /// Sanitizes SQL/PostgreSQL exceptions, technical stack dumps, and raw errors
  /// into crystal-clear merchant friendly messages.
  static String _sanitizeErrorMessage(String raw, {required bool isHindi}) {
    final lower = raw.toLowerCase();

    // Database: Unique constraint collisions
    if (lower.contains('duplicate key') || lower.contains('unique constraint')) {
      if (lower.contains('barcode')) {
        return isHindi
            ? 'इस बारकोड वाला सामान आपकी इन्वेंटरी में पहले से मौजूद है।'
            : 'A product with this barcode already exists in your catalog.';
      }
      if (lower.contains('sku')) {
        return isHindi
            ? 'इस SKU वाला सामान आपकी दुकान में पहले से मौजूद है।'
            : 'A product with this SKU already exists in your catalog.';
      }
      if (lower.contains('phone') || lower.contains('mobile')) {
        return isHindi
            ? 'यह मोबाइल नंबर पहले से पंजीकृत है।'
            : 'This mobile number is already registered.';
      }
      if (lower.contains('email')) {
        return isHindi
            ? 'यह ईमेल आईडी पहले से पंजीकृत है।'
            : 'This email address is already registered.';
      }
      return isHindi
          ? 'इस जानकारी वाला रिकॉर्ड पहले से मौजूद है।'
          : 'A record with these unique details already exists.';
    }

    // Database: Foreign key violation
    if (lower.contains('foreign key constraint') || lower.contains('violates foreign key')) {
      return isHindi
          ? 'इस रिकॉर्ड से जुड़े अन्य डेटा होने के कारण इसे नहीं हटाया जा सकता।'
          : 'Cannot complete this action because other active records depend on it.';
    }

    // Database: Record not found / SQL no rows
    if (lower.contains('sql: no rows') || lower.contains('record not found')) {
      return isHindi
          ? 'अनुरोधित रिकॉर्ड नहीं मिला।'
          : 'The requested record was not found.';
    }

    // Database: Text length exceeded
    if (lower.contains('value too long')) {
      return isHindi
          ? 'दर्ज किया गया विवरण बहुत लंबा है। कृपया छोटा नाम या टेक्स्ट दर्ज करें।'
          : 'Entered text is too long. Please shorten your input.';
    }

    // Database: Not null violation
    if (lower.contains('violates not-null constraint') || lower.contains('null value in column')) {
      return isHindi
          ? 'कुछ आवश्यक जानकारी छूट गई है। कृपया सभी अनिवार्य फ़ील्ड भरें।'
          : 'Required details are missing. Please complete all required fields.';
    }

    // Rate limiting / BotGuard
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return isHindi
          ? 'बहुत अधिक अनुरोध। कृपया 1 मिनट प्रतीक्षा करें और फिर प्रयास करें।'
          : 'Too many requests. Please wait a minute and try again.';
    }

    // Session / Auth tokens
    if (lower.contains('token expired') || lower.contains('signature is invalid') || lower.contains('jwt')) {
      return isHindi
          ? 'लॉगिन सत्र समाप्त हो गया। कृपया दोबारा लॉगिन करें।'
          : 'Your session has expired. Please log in again.';
    }

    // HTML / Cloudflare error pages
    if (raw.contains('<html') || raw.contains('<!doctype') || raw.contains('<div') || raw.contains('<title>')) {
      return isHindi
          ? 'शॉपसाइलो सर्वर अस्थायी रूप से अनुपलब्ध है। कृपया थोड़ी देर बाद पुनः प्रयास करें।'
          : 'ShopSilo server is temporarily unavailable. Please try again shortly.';
    }

    // Socket exceptions
    if (lower.contains('socketexception') || lower.contains('connection refused') || lower.contains('network is unreachable')) {
      return isHindi
          ? 'इंटरनेट कनेक्शन नहीं मिला। कृपया इंटरनेट चालू करें।'
          : 'No internet connection. Please check your network and retry.';
    }

    // Strip "Exception: " prefix if present
    var cleaned = raw;
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    }

    return cleaned;
  }
}
