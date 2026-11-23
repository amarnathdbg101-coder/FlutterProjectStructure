import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/copilot_model.dart';

class CopilotRepository {
  final Dio _dio = ApiClient().dio;

  /// Retrieves today's Morning 3-Action Brief prescriptions.
  Future<ApiResponse<List<DailyPrescriptionModel>>> getDailyPrescriptions() async {
    try {
      final res = await _dio.get(ApiConstants.copilotDailyPrescriptions);
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      }
      final items = listData
          .map((e) => DailyPrescriptionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  /// 1-Tap execution of an actionable prescription card.
  Future<ApiResponse<bool>> executePrescription(String prescriptionId, {String notes = ''}) async {
    try {
      final res = await _dio.post(
        ApiConstants.copilotExecutePrescription(prescriptionId),
        data: {'notes': notes},
      );
      return ApiResponse(success: res.statusCode == 200 || res.statusCode == 201, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  /// Retrieves dead stock summary and monthly carrying cost losses.
  Future<ApiResponse<DeadCapitalSummaryModel>> getDeadCapitalSummary() async {
    try {
      final res = await _dio.get(ApiConstants.copilotDeadCapital);
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map && raw['data'] is Map) {
        data = Map<String, dynamic>.from(raw['data']);
      } else if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      }
      return ApiResponse(success: true, data: DeadCapitalSummaryModel.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  /// Real-time margin-aware negotiation evaluation at counter.
  Future<ApiResponse<BargainEvaluationModel>> evaluateBargain({
    required String productId,
    required double customerOfferedPrice,
    String customerPhone = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.copilotEvaluateBargain,
        data: {
          'product_id': productId,
          'customer_offered_price': customerOfferedPrice,
          'customer_phone': customerPhone.trim(),
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map && raw['data'] is Map) {
        data = Map<String, dynamic>.from(raw['data']);
      } else if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      }
      return ApiResponse(success: true, data: BargainEvaluationModel.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  /// Natural language search for domain-aware substitutes.
  Future<ApiResponse<List<SubstituteRecommendationModel>>> searchSubstitutes({
    required String query,
    String category = '',
    double maxPrice = 0.0,
    String skinType = '',
    String fabric = '',
    String occasion = '',
    int limit = 5,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.copilotSearchSubstitute,
        data: {
          'query': query.trim(),
          'category': category.trim(),
          'max_price': maxPrice,
          'skin_type': skinType.trim(),
          'fabric': fabric.trim(),
          'occasion': occasion.trim(),
          'limit': limit,
        },
      );
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      }
      final items = listData
          .map((e) => SubstituteRecommendationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  /// Triggers on-demand recalculation of ABC-XYZ demand matrix.
  Future<ApiResponse<bool>> triggerRecalculate() async {
    try {
      final res = await _dio.post(ApiConstants.copilotRecalculate);
      return ApiResponse(success: res.statusCode == 200, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
