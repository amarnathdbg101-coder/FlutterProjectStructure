import 'dart:convert';
import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_response.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String _englishNetworkError =
      "Can't connect to ShopSilo right now. Check server or network availability and try again.";
  static const String _hindiNetworkError =
      'ShopSilo से अभी कनेक्ट नहीं हो पा रहा है। सर्वर या नेटवर्क उपलब्ध होने पर फिर प्रयास करें।';

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
      final res = await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
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
          if (!data.contains('<html') &&
              !data.contains('<!DOCTYPE') &&
              data.length < 300) {
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
                ? 'अनुरोध पहले से प्रक्रिया में है (सिंगल-फ़्लाइट लॉक) या डुप्लिकेट है। कृपया कुछ पल प्रतीक्षा करें।'
                : 'Request is already being processed or duplicated. Please wait a moment.';
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
          default:
            return statusCode >= 500
                ? (isHindi
                      ? 'शॉपसाइलो सर्वर पर अस्थायी समस्या है। कृपया थोड़ी देर बाद पुनः प्रयास करें।'
                      : 'ShopSilo is temporarily unavailable. Please try again shortly.')
                : (isHindi
                      ? 'अनुरोध पूरा नहीं हो सका। कृपया विवरण जांचकर फिर प्रयास करें।'
                      : 'The request could not be completed. Please check the details and try again.');
        }
      }

      // 4. Network / Dio Exception Type Fallbacks
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return _networkErrorMessage(isHindi: isHindi);
        case DioExceptionType.cancel:
          return isHindi
              ? 'अनुरोध रद्द कर दिया गया।'
              : 'Request was cancelled.';
        default:
          final details = error.error?.toString() ?? error.message ?? '';
          return _sanitizeErrorMessage(details, isHindi: isHindi);
      }
    }

    // 5. Handle generic Dart errors / exceptions
    return _sanitizeErrorMessage(error.toString(), isHindi: isHindi);
  }

  static bool isNetworkErrorMessage(String message) {
    final normalized = message.trim();
    return normalized == _englishNetworkError ||
        normalized == _hindiNetworkError;
  }

  static String _networkErrorMessage({required bool isHindi}) =>
      isHindi ? _hindiNetworkError : _englishNetworkError;

  /// Sanitizes SQL/PostgreSQL exceptions, technical stack dumps, and raw errors
  /// into crystal-clear merchant friendly messages. Zero technical jargon leaks to UI.
  static String _sanitizeErrorMessage(String raw, {required bool isHindi}) {
    var cleaned = raw.trim();

    // 0. Parse JSON if string is wrapped in JSON e.g. {"error": "..."} or {"message": "..."}
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map) {
          final extracted = decoded['error'] ?? decoded['message'] ?? decoded['msg'];
          if (extracted != null) {
            cleaned = extracted.toString().trim();
          }
        }
      } catch (_) {}
    }

    final lower = cleaned.toLowerCase();

    // 1. Network, Socket, DNS, Handshake, Connection Errors
    if (lower.contains('socketexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('certificateexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection error') ||
        lower.contains('connection closed') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('network request failed') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('broken pipe') ||
        lower.contains('software caused connection abort') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('failed to fetch')) {
      return _networkErrorMessage(isHindi: isHindi);
    }

    // 2. Server Errors (500, 502, 503, 504, Bad Gateway, Internal Server Error)
    if (lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout') ||
        lower.contains('service unavailable') ||
        lower.contains('status code of 500') ||
        lower.contains('status code of 502') ||
        lower.contains('status code of 503') ||
        lower.contains('status code of 504') ||
        lower.contains('500 internal') ||
        lower.contains('502 bad gateway') ||
        lower.contains('503 service') ||
        lower.contains('504 gateway')) {
      return isHindi
          ? 'सर्वर पर अस्थायी समस्या है। कृपया कुछ पलों में पुनः प्रयास करें।'
          : 'Server is temporarily unavailable. Please try again shortly.';
    }

    // 3. Database: Unique constraint collisions (Barcode, SKU, Phone, Email)
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

    // 4. Database: Foreign key violation / Dependent records
    if (lower.contains('foreign key constraint') ||
        lower.contains('violates foreign key')) {
      return isHindi
          ? 'इस रिकॉर्ड से जुड़े अन्य डेटा होने के कारण इसे नहीं हटाया जा सकता।'
          : 'Cannot complete this action because other active records depend on it.';
    }

    // 5. Database: Record not found / SQL no rows
    if (lower.contains('sql: no rows') ||
        lower.contains('record not found') ||
        lower.contains('404 not found') ||
        lower.contains('item not found')) {
      return isHindi
          ? 'अनुरोधित रिकॉर्ड नहीं मिला।'
          : 'The requested record was not found.';
    }

    // 6. Database: Text length exceeded
    if (lower.contains('value too long')) {
      return isHindi
          ? 'दर्ज किया गया विवरण बहुत लंबा है। कृपया छोटा नाम या टेक्स्ट दर्ज करें।'
          : 'Entered text is too long. Please shorten your input.';
    }

    // 7. Database: Not null violation
    if (lower.contains('violates not-null constraint') ||
        lower.contains('null value in column') ||
        lower.contains('missing required')) {
      return isHindi
          ? 'कुछ आवश्यक जानकारी छूट गई है। कृपया सभी अनिवार्य फ़ील्ड भरें।'
          : 'Required details are missing. Please complete all required fields.';
    }

    // 8. Rate limiting / BotGuard
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return isHindi
          ? 'बहुत अधिक अनुरोध। कृपया 1 मिनट प्रतीक्षा करें और फिर प्रयास करें।'
          : 'Too many requests. Please wait a minute and try again.';
    }

    // 9. Session / Auth tokens
    if (lower.contains('token expired') ||
        lower.contains('signature is invalid') ||
        lower.contains('jwt') ||
        lower.contains('unauthorized') ||
        lower.contains('401 unauthorized')) {
      return isHindi
          ? 'लॉगिन सत्र समाप्त हो गया। कृपया दोबारा लॉगिन करें।'
          : 'Your session has expired. Please log in again.';
    }

    // 10. HTML / Cloudflare error pages
    if (cleaned.contains('<html') ||
        cleaned.contains('<!doctype') ||
        cleaned.contains('<div') ||
        cleaned.contains('<title>')) {
      return isHindi
          ? 'शॉपसाइलो सर्वर अस्थायी रूप से अनुपलब्ध है। कृपया थोड़ी देर बाद पुनः प्रयास करें।'
          : 'ShopSilo server is temporarily unavailable. Please try again shortly.';
    }

    // 11. Dart Framework Technical Exceptions (Formatting, Parsing, Type, Null, State, StackTraces)
    if (lower.contains('formatexception') ||
        lower.contains('typeerror') ||
        lower.contains('is not a subtype of') ||
        lower.contains('null check operator') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('lateinitializationerror') ||
        lower.contains('rangeerror') ||
        lower.contains('stateerror') ||
        lower.contains('bad state') ||
        lower.contains('assertionerror') ||
        lower.contains('unhandled exception') ||
        lower.contains('dioexception') ||
        lower.contains('httpexception') ||
        lower.contains('platformexception') ||
        lower.contains('missingpluginexception') ||
        lower.contains('errno =') ||
        lower.contains('pq:') ||
        lower.contains('gorm:') ||
        lower.contains('sql:') ||
        lower.contains('stacktrace') ||
        lower.contains('package:')) {
      return isHindi
          ? 'डेटा लोड करने में अस्थायी समस्या हुई। कृपया दोबारा प्रयास करें।'
          : 'Could not load data. Please try again.';
    }

    // Strip "Exception: " or "Error: " prefix
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length).trim();
    }
    if (cleaned.startsWith('Error: ')) {
      cleaned = cleaned.substring('Error: '.length).trim();
    }

    // 12. Final Guard: If message contains code symbols, brackets, or is excessively long
    if (cleaned.contains('{') ||
        cleaned.contains('}') ||
        cleaned.contains('<') ||
        cleaned.contains('>') ||
        cleaned.length > 150) {
      return isHindi
          ? 'कुछ तकनीकी समस्या हुई। कृपया दोबारा प्रयास करें।'
          : 'Something went wrong. Please try again.';
    }

    return cleaned;
  }
}
