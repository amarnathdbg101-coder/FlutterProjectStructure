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
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'],
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory ApiResponse.failure(String errorMessage) {
    return ApiResponse<T>(
      success: false,
      error: errorMessage,
    );
  }
}
