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
    if (json is Map<String, dynamic>) {
      // Determine success flag
      bool isSuccess = false;
      if (json.containsKey('success')) {
        isSuccess = json['success'] == true;
      } else if (json['status'] == 'success' || json['status'] == 200 || json['status'] == 'ok') {
        isSuccess = true;
      } else if (json.containsKey('access_token') ||
          json.containsKey('token') ||
          json.containsKey('data') ||
          json.containsKey('shop') ||
          json.containsKey('bill') ||
          json.containsKey('items') ||
          json.containsKey('customers') ||
          json.containsKey('expenses') ||
          json.containsKey('id') ||
          json.containsKey('user_id')) {
        isSuccess = true;
      } else if (!json.containsKey('error') && !json.containsKey('errors')) {
        isSuccess = true;
      }

      dynamic payload = json;
      if (json.containsKey('data')) {
        payload = json['data'];
      }

      return ApiResponse<T>(
        success: isSuccess,
        data: payload != null && fromJsonT != null ? fromJsonT(payload) : payload as T?,
        message: json['message']?.toString(),
        error: isSuccess ? json['error']?.toString() : (json['error']?.toString() ?? json['message']?.toString()),
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
