import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../products/repositories/product_repository.dart';

class AiRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<Map<String, dynamic>>> getMerchantBusinessContext() async {
    final productsRepository = ProductRepository();
    final results = await Future.wait([
      productsRepository.getMonthlyProfit(),
      productsRepository.getProductMatrix(),
    ]);
    final monthlyProfit = results[0];
    final productMatrix = results[1];

    List<Map<String, dynamic>> compactProducts(dynamic value) {
      if (value is! List) return const [];
      return value.whereType<Map>().take(5).map((item) {
        final product = Map<String, dynamic>.from(item);
        return <String, dynamic>{
          'name': product['name'],
          'total_sold_qty': product['total_sold_qty'],
          'total_profit': product['total_profit'],
          'unit_profit': product['unit_profit'],
          'profit_margin_pct': product['profit_margin_pct'],
          'current_stock': product['current_stock'],
        };
      }).toList();
    }

    final matrix = productMatrix.data ?? const <String, dynamic>{};
    return ApiResponse(
      success: true,
      data: {
        'as_of': DateTime.now().toIso8601String(),
        'metric_definitions': {
          'total_profit':
              'Recorded gross product profit from POS bills and completed reservations; before operating expenses.',
          'unit_profit':
              'Current selling price minus current cost price; not total sales profit.',
        },
        'data_availability': {
          'monthly_summary': monthlyProfit.success,
          'product_profit_ranking': productMatrix.success,
        },
        'current_month_summary':
            monthlyProfit.success ? monthlyProfit.data : null,
        'top_products_by_total_profit': productMatrix.success
            ? compactProducts(matrix['best_profitable'])
            : const <Map<String, dynamic>>[],
        'lowest_margin_products': productMatrix.success
            ? compactProducts(matrix['worst_profitable'])
            : const <Map<String, dynamic>>[],
        'slow_moving_products': productMatrix.success
            ? compactProducts(matrix['old_dead_stock'])
            : const <Map<String, dynamic>>[],
      },
    );
  }

  // --- Public Categories List ---
  Future<ApiResponse<List<Map<String, dynamic>>>> getCategories() async {
    try {
      final res = await _dio.get(ApiConstants.categories);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['categories'] is List) {
        list = raw['categories'];
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Vision Product Scanner ---
  Future<ApiResponse<Map<String, dynamic>>> scanProduct({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiScanProduct,
        data: {'image_base64': imageBase64, 'mime_type': mimeType},
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Mandi Sourcing & Wholesale Reorder Vision ---
  Future<ApiResponse<Map<String, dynamic>>> scanMandiItem({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiMandiScan,
        data: {'image_base64': imageBase64, 'mime_type': mimeType},
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Handwritten Parchi / Customer List Parser ---
  Future<ApiResponse<Map<String, dynamic>>> parseParchi({
    required String rawText,
    String? imageBase64,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiParseParchi,
        data: {
          'raw_text': rawText.trim(),
          if (imageBase64 != null) 'image_base64': imageBase64,
        },
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Voice-to-Bill Counter Assistant ---
  Future<ApiResponse<Map<String, dynamic>>> voiceBill({
    required String spokenText,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiVoiceBill,
        data: {'spoken_text': spokenText.trim()},
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- WhatsApp & Social Marketing Campaign Generator ---
  Future<ApiResponse<Map<String, dynamic>>> marketingCampaign({
    String festivalName = '',
    String offerDetails = '',
    String targetAudience = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiMarketingCampaign,
        data: {
          'festival_name': festivalName.trim(),
          'offer_details': offerDetails.trim(),
          'target_audience': targetAudience.trim(),
        },
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
