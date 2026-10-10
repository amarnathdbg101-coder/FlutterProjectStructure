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
      }
      final items = listData.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ExpenseModel>> createExpense(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(ApiConstants.expenses, data: data);
      final raw = res.data;
      Map<String, dynamic> item = (raw is Map<String, dynamic>) ? (raw['expense'] ?? raw['data'] ?? raw) : {};
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
