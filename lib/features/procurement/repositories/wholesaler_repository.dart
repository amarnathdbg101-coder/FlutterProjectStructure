import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/wholesaler_model.dart';

/// Repository for syncing permanent wholesalers directory with Go backend.
class WholesalerRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<WholesalerModel>>> getWholesalers() async {
    try {
      final res = await _dio.get('/wholesalers');
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      }
      final list = listData
          .map((item) => WholesalerModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return ApiResponse(success: true, data: list);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<WholesalerModel>> createWholesaler(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/wholesalers', data: data);
      final raw = res.data;
      final item = (raw is Map<String, dynamic>)
          ? (raw['data'] is Map ? raw['data'] : raw)
          : {};
      return ApiResponse(success: true, data: WholesalerModel.fromJson(Map<String, dynamic>.from(item as Map)));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<WholesalerModel>> updateWholesaler(String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/wholesalers/$id', data: data);
      final raw = res.data;
      final item = (raw is Map<String, dynamic>)
          ? (raw['data'] is Map ? raw['data'] : raw)
          : {};
      return ApiResponse(success: true, data: WholesalerModel.fromJson(Map<String, dynamic>.from(item as Map)));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<void>> deleteWholesaler(String id) async {
    try {
      await _dio.delete('/wholesalers/$id');
      return ApiResponse(success: true, data: null);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
