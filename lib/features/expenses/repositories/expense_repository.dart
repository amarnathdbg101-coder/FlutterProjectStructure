import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<ExpenseModel>>> listExpenses() async {
    try {
      final res = await _dio.get(ApiConstants.expenses);
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['expenses'] is List) {
        listData = raw['expenses'];
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      } else if (raw is Map && raw['data'] is Map && raw['data']['expenses'] is List) {
        listData = raw['data']['expenses'];
      }
      final items = listData
          .whereType<Map>()
          .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ExpenseModel>> createExpense(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(ApiConstants.expenses, data: data);
      final raw = res.data;
      Map<String, dynamic> item = {};
      if (raw is Map) {
        final inner = raw['expense'] ?? raw['data'] ?? raw;
        if (inner is Map) {
          item = Map<String, dynamic>.from(inner);
        }
      }
      return ApiResponse(success: true, data: ExpenseModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteExpense(dynamic id) async {
    try {
      await _dio.delete('${ApiConstants.expenses}/$id');
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
