import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {'name': name, 'email': email, 'password': password},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<UserModel>> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      return ApiResponse.fromJson(
        response.data,
        (data) => UserModel.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
