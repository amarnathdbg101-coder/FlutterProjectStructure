import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/__LOWER___model.dart';

class __PASCAL__Repository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<__PASCAL__Model>>> getAll() async {
    try {
      final response = await _dio.get('/api/v1/__PLURAL__');
      return ApiResponse.fromJson(
        response.data,
        (data) => (data as List).map((i) => __PASCAL__Model.fromJson(i as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<__PASCAL__Model>> create(String title, String description) async {
    try {
      final response = await _dio.post(
        '/api/v1/__PLURAL__',
        data: {'title': title, 'description': description},
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => __PASCAL__Model.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<void>> delete(dynamic id) async {
    try {
      final response = await _dio.delete('/api/v1/__PLURAL__/$id');
      return ApiResponse.fromJson(response.data, (_) {});
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
