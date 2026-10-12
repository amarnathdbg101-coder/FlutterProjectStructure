class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
  });

  factory ApiResponse.fromJson(
    dynamic json,
    T Function(dynamic json)? fromJsonT,
  ) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);

      // Determine success flag
      bool isSuccess = false;
      if (map.containsKey('success')) {
        isSuccess = map['success'] == true;
      } else if (map['status'] == 'success' ||
          map['status'] == 200 ||
          map['status'] == 'ok' ||
          map['status'] == true) {
        isSuccess = true;
      } else if (map.containsKey('access_token') ||
          map.containsKey('token') ||
          map.containsKey('data') ||
          map.containsKey('shop') ||
          map.containsKey('bill') ||
          map.containsKey('items') ||
          map.containsKey('customers') ||
          map.containsKey('expenses') ||
          map.containsKey('id') ||
          map.containsKey('user_id')) {
        isSuccess = true;
      } else if (!map.containsKey('error') && !map.containsKey('errors')) {
        isSuccess = true;
      }

      dynamic payload = map;
      if (map.containsKey('data')) {
        payload = map['data'];
      }

      return ApiResponse<T>(
        success: isSuccess,
        data: payload != null && fromJsonT != null ? fromJsonT(payload) : payload as T?,
        message: map['message']?.toString(),
        error: isSuccess
            ? map['error']?.toString()
            : (map['error']?.toString() ?? map['message']?.toString()),
      );
    } else if (json is List && fromJsonT != null) {
      return ApiResponse<T>(
        success: true,
        data: fromJsonT(json),
      );
    }

    return ApiResponse<T>(
      success: true,
      data: json as T?,
    );
  }

  factory ApiResponse.failure(String errorMessage) {
    return ApiResponse<T>(
      success: false,
      error: errorMessage,
    );
  }
}
