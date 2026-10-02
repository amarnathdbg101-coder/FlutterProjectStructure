import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

class HealthRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<Map<String, dynamic>>> checkHealth() async {
    try {
      final response = await _dio.get(ApiConstants.health);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
