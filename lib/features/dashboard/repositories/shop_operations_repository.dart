import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

class ShopOperationsRepository {
  final Dio _dio = ApiClient().dio;

  // --- 1. In-Store Item Returns & Refunds ---
  Future<ApiResponse<Map<String, dynamic>>> processReturn({
    required String productId,
    required int quantity,
    required double refundAmount,
    required String reason,
    String? reservationId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
        'refund_amount': refundAmount,
        'reason': reason.trim(),
      };
      if (reservationId != null && reservationId.isNotEmpty) {
        payload['reservation_id'] = reservationId;
      }

      final res = await _dio.post(ApiConstants.shopReturns, data: payload);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> listReturns() async {
    try {
      final res = await _dio.get(ApiConstants.shopReturns);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['returns'] is List) {
        list = raw['returns'];
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- 2. VIP Loyalty Offers & Discount Coupons ---
  Future<ApiResponse<Map<String, dynamic>>> createOffer({
    required String title,
    required String discountText,
    String description = '',
    int minPointsRequired = 0,
    int expiresInDays = 30,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.shopOffers,
        data: {
          'title': title.trim(),
          'discount_text': discountText.trim(),
          'description': description.trim(),
          'min_points_required': minPointsRequired,
          'expires_in_days': expiresInDays,
        },
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateOffer(String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put(ApiConstants.shopOfferById(id), data: data);
      final resData = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: resData as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteOffer(String id) async {
    try {
      await _dio.delete(ApiConstants.shopOfferById(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getOfferHistory() async {
    try {
      final res = await _dio.get(ApiConstants.shopOffersHistory);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['history'] is List) {
        list = raw['history'];
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- 3. In-Store Reservations (Shopkeeper Counter Pickup) ---
  Future<ApiResponse<List<Map<String, dynamic>>>> listReservations({String status = ''}) async {
    try {
      final queryParams = status.isNotEmpty ? {'status': status} : null;
      final res = await _dio.get(ApiConstants.shopReservations, queryParameters: queryParams);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        final dataObj = raw['data'] ?? raw;
        if (dataObj is List) {
          list = dataObj;
        } else if (dataObj is Map && dataObj['reservations'] is List) {
          list = dataObj['reservations'];
        } else if (raw['reservations'] is List) {
          list = raw['reservations'];
        }
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyReservation({
    required String pickupCode,
    String? reservationNumber,
  }) async {
    try {
      final payload = <String, dynamic>{'pickup_code': pickupCode.trim()};
      if (reservationNumber != null && reservationNumber.isNotEmpty) {
        payload['reservation_number'] = reservationNumber.trim();
      }

      final res = await _dio.post(ApiConstants.shopReservationVerify, data: payload);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> cancelReservation(String id) async {
    try {
      await _dio.post(ApiConstants.shopReservationCancel(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
