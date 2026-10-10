import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

class AiRepository {
  final Dio _dio = ApiClient().dio;

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

  // --- Merchant AI Copilot (Advisor & Analysis) ---
  Future<ApiResponse<Map<String, dynamic>>> merchantCopilot({
    required String prompt,
    List<Map<String, String>> history = const [],
    String shopData = '',
    String? imageBase64,
  }) async {
    try {
      final payload = <String, dynamic>{
        'prompt': prompt.trim(),
        'history': history,
        'shop_data': shopData,
      };
      if (imageBase64 != null) payload['image_base64'] = imageBase64;

      final res = await _dio.post(ApiConstants.aiMerchantCopilot, data: payload);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
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
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Handwritten Parchi / Customer List Parser ---
  Future<ApiResponse<Map<String, dynamic>>> parseParchi({
    required String imageBase64,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.aiParseParchi,
        data: {'image_base64': imageBase64},
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

  // --- Bargain Assist (Bottom safe selling price for shopkeeper) ---
  Future<ApiResponse<Map<String, dynamic>>> bargainAssist({
    required String productName,
    required double mrp,
    required double costPrice,
    double? askingPrice,
  }) async {
    try {
      final payload = <String, dynamic>{
        'product_name': productName.trim(),
        'mrp': mrp,
        'cost_price': costPrice,
      };
      if (askingPrice != null) payload['asking_price'] = askingPrice;

      final res = await _dio.post(ApiConstants.aiBargainAssist, data: payload);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
