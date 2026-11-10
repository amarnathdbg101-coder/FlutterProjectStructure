import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/ai_features_model.dart';

class AIServiceRepository {
  final Dio _dio = ApiClient().dio;

  // 1. Photo-to-Inventory OCR Ingestion
  Future<ApiResponse<SupplierInvoiceResponse>> parseSupplierInvoice({
    required String imageBase64,
    String mimeType = 'image/jpeg',
    String distributorHint = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiSupplierInvoice,
        data: {
          'image_base64': imageBase64,
          'mime_type': mimeType,
          if (distributorHint.isNotEmpty) 'distributor_hint': distributorHint,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: SupplierInvoiceResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 2. Real-Time Counter Cross-Sell & Look-Stylist
  Future<ApiResponse<CrossSellResponse>> getCrossSellRecommendations({
    required String scannedProductName,
    String categoryHint = '',
    double price = 0.0,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiCrossSell,
        data: {
          'scanned_product_name': scannedProductName,
          if (categoryHint.isNotEmpty) 'category_hint': categoryHint,
          if (price > 0) 'price': price,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: CrossSellResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 3. Dead-Stock Smart Bundler
  Future<ApiResponse<DeadStockResponse>> getDeadStockBundles({String? shopId}) async {
    try {
      final query = <String, dynamic>{};
      if (shopId != null && shopId.isNotEmpty) query['shop_id'] = shopId;

      final res = await _dio.get(ApiConstants.aiDeadStockBundles, queryParameters: query.isNotEmpty ? query : null);
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: DeadStockResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 4. Respectful Psychology-Based Khata Recovery Nudges
  Future<ApiResponse<RecoveryNudgeResponse>> generateRecoveryNudge({
    required String customerName,
    required String customerPhone,
    required double totalDebt,
    int daysOverdue = 0,
    double dailyMicroAmount = 0.0,
    String shopUPIID = '',
    String shopName = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiRecoveryNudge,
        data: {
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'total_debt': totalDebt,
          'days_overdue': daysOverdue,
          if (dailyMicroAmount > 0) 'daily_micro_amount': dailyMicroAmount,
          if (shopUPIID.isNotEmpty) 'shop_upi_id': shopUPIID,
          if (shopName.isNotEmpty) 'shop_name': shopName,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: RecoveryNudgeResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 5. Voice-to-Bill Assistant
  Future<ApiResponse<VoiceBillResponse>> voiceBill({required String spokenText}) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiVoiceBill,
        data: {'spoken_text': spokenText},
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: VoiceBillResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 6. Festive Marketing Campaign
  Future<ApiResponse<MarketingCampaignResponse>> generateMarketingCampaign({
    String festivalName = '',
    String offerDetails = '',
    String targetAudience = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiMarketingCampaign,
        data: {
          'festival_name': festivalName,
          'offer_details': offerDetails,
          'target_audience': targetAudience,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: MarketingCampaignResponse.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}

