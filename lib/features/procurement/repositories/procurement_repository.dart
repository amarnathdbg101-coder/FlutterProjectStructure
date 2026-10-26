import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/procurement_model.dart';

class ProcurementRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<ProcurementItemModel>>> listProcurementItems() async {
    try {
      final res = await _dio.get(ApiConstants.shopProcurement);
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      } else if (raw is Map && raw['items'] is List) {
        listData = raw['items'];
      }
      final items = listData
          .map((e) => ProcurementItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProcurementItemModel>> createProcurementItem({
    required String name,
    required String qty,
    String category = 'General Store',
    double estimatedPrice = 0.0,
    double actualPrice = 0.0,
    String dealerName = '',
    String dealerPhone = '',
    String notes = '',
  }) async {
    try {
      final payload = {
        'name': name.trim(),
        'qty': qty.trim(),
        'category': category.trim(),
        'estimated_price': estimatedPrice,
        'actual_price': actualPrice,
        'dealer_name': dealerName.trim(),
        'dealer_phone': dealerPhone.trim(),
        'notes': notes.trim(),
      };
      final res = await _dio.post(ApiConstants.shopProcurement, data: payload);
      final raw = res.data;
      Map<String, dynamic> item = (raw is Map<String, dynamic>)
          ? (raw['data'] is Map ? raw['data'] : (raw['item'] ?? raw))
          : {};
      return ApiResponse(success: true, data: ProcurementItemModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProcurementItemModel>> updateProcurementItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final res = await _dio.put(ApiConstants.shopProcurementById(id), data: updates);
      final raw = res.data;
      Map<String, dynamic> item = (raw is Map<String, dynamic>)
          ? (raw['data'] is Map ? raw['data'] : (raw['item'] ?? raw))
          : {};
      return ApiResponse(success: true, data: ProcurementItemModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProcurementItemModel>> toggleProcurementItem(String id) async {
    try {
      final res = await _dio.post(ApiConstants.shopProcurementToggle(id));
      final raw = res.data;
      Map<String, dynamic> item = (raw is Map<String, dynamic>)
          ? (raw['data'] is Map ? raw['data'] : (raw['item'] ?? raw))
          : {};
      return ApiResponse(success: true, data: ProcurementItemModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteProcurementItem(String id) async {
    try {
      await _dio.delete(ApiConstants.shopProcurementById(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> clearCompleted() async {
    try {
      await _dio.post(ApiConstants.shopProcurementClearCompleted);
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
