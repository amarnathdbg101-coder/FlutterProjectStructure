import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/wholesaler_model.dart';

/// Repository for syncing permanent wholesalers directory with Go backend.
class WholesalerRepository {
  final ApiClient _client = ApiClient();

  Future<ApiResponse<List<WholesalerModel>>> getWholesalers() async {
    final res = await _client.get('/wholesalers');
    if (res.success && res.data != null) {
      final list = (res.data as List)
          .map((item) => WholesalerModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return ApiResponse.completed(list);
    }
    return ApiResponse.error(res.error ?? 'Failed to load wholesalers');
  }

  Future<ApiResponse<WholesalerModel>> createWholesaler(Map<String, dynamic> data) async {
    final res = await _client.post('/wholesalers', data: data);
    if (res.success && res.data != null) {
      return ApiResponse.completed(WholesalerModel.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse.error(res.error ?? 'Failed to register wholesaler');
  }

  Future<ApiResponse<WholesalerModel>> updateWholesaler(String id, Map<String, dynamic> data) async {
    final res = await _client.put('/wholesalers/$id', data: data);
    if (res.success && res.data != null) {
      return ApiResponse.completed(WholesalerModel.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse.error(res.error ?? 'Failed to update wholesaler');
  }

  Future<ApiResponse<void>> deleteWholesaler(String id) async {
    final res = await _client.delete('/wholesalers/$id');
    if (res.success) {
      return ApiResponse.completed(null);
    }
    return ApiResponse.error(res.error ?? 'Failed to delete wholesaler');
  }
}

