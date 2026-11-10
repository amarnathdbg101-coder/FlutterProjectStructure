import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// Production Auth & Network Resilience Interceptor
/// 1. Injects Bearer token automatically on authenticated routes
/// 2. Injects Idempotency-Key headers for all mutating requests (POST/PUT/PATCH/DELETE)
/// 3. Transparently refreshes expired JWT tokens on HTTP 401 and replays the failed request
class AuthInterceptor extends Interceptor {
  static bool _isRefreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (options.data is FormData) {
      options.headers.remove('Content-Type');
    } else {
      options.headers['Content-Type'] = 'application/json';
    }
    options.headers['Accept'] = 'application/json';

    // Auto-generate Idempotency-Key for mutating HTTP verbs (POST, PUT, PATCH, DELETE)
    // Ensures GoBackend go-idempotency middleware deduplicates accidental double taps and network retries
    final method = options.method.toUpperCase();
    if (const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)) {
      if (!options.headers.containsKey('X-Idempotency-Key') &&
          !options.headers.containsKey('Idempotency-Key')) {
        final randomSuffix = (DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
        final idempKey = 'idemp_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';
        options.headers['X-Idempotency-Key'] = idempKey;
        options.headers['Idempotency-Key'] = idempKey;
      }
    }

    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Check if error is 401 Unauthorized and not an auth endpoint itself
    final isAuthEndpoint = path.contains('/auth/refresh') ||
        path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/staff-login') ||
        path.contains('/auth/send-otp') ||
        path.contains('/auth/verify-otp');

    if (statusCode == 401 && !isAuthEndpoint && !_isRefreshing) {
      final tokenToRefresh = TokenStorage.getRefreshToken() ?? TokenStorage.getToken();
      if (tokenToRefresh != null && tokenToRefresh.isNotEmpty) {
        _isRefreshing = true;
        try {
          final refreshDio = Dio(
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

          final res = await refreshDio.post(
            ApiConstants.refreshToken,
            data: {'refresh_token': tokenToRefresh},
          );

          if (res.statusCode == 200 && res.data != null) {
            String? newAccessToken;
            final raw = res.data;
            if (raw is Map) {
              if (raw['data'] is Map && raw['data']['access_token'] != null) {
                newAccessToken = raw['data']['access_token'].toString();
              } else if (raw['access_token'] != null) {
                newAccessToken = raw['access_token'].toString();
              }
            }

            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              await TokenStorage.saveToken(newAccessToken);
              _isRefreshing = false;

              // Replay original request with refreshed access token
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await refreshDio.fetch(opts);
              return handler.resolve(retryResponse);
            }
          }
        } catch (_) {
          // Token refresh attempt failed
        } finally {
          _isRefreshing = false;
        }
      }

      // If token refresh was impossible or failed, clear session
      await TokenStorage.clearSession();
    }

    super.onError(err, handler);
  }
}
