import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../pos/models/pos_features_model.dart';

class KhataMicroPlanRepository {
  final Dio _dio = ApiClient().dio;

  // 6. Khata Daily Micro-Installments
  Future<ApiResponse<KhataMicroPlan>> createMicroPlan({
    required String customerPhone,
    required String customerName,
    required double totalDebt,
    required double dailyAmount,
    int targetDays = 30,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.khataMicroPlans,
        data: {
          'customer_phone': customerPhone,
          'customer_name': customerName,
          'total_debt': totalDebt,
          'daily_amount': dailyAmount,
          'target_days': targetDays,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: KhataMicroPlan.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<KhataMicroPlan>> recordPayment({
    required String planId,
    required double amount,
    String paymentMethod = 'CASH',
    String notes = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.khataMicroPlanPay(planId),
        data: {
          'amount': amount,
          'payment_method': paymentMethod,
          'notes': notes,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: KhataMicroPlan.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<KhataMicroPlan>> getPlanById(String planId) async {
    try {
      final res = await _dio.get(ApiConstants.khataMicroPlanById(planId));
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: KhataMicroPlan.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<KhataMicroPlan>>> listPlans({String? customerPhone}) async {
    try {
      final query = <String, dynamic>{};
      if (customerPhone != null && customerPhone.isNotEmpty) {
        query['phone'] = customerPhone;
      }
      final res = await _dio.get(
        ApiConstants.khataMicroPlans,
        queryParameters: query.isNotEmpty ? query : null,
      );
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => KhataMicroPlan.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}

