import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../products/models/product_model.dart';
import '../models/pos_model.dart';

class PosRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<ProductModel>>> searchProducts(String query) async {
    try {
      final res = await _dio.get(
        ApiConstants.myProducts,
        queryParameters: query.isNotEmpty ? {'search': query} : null,
      );
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map) {
        if (raw['data'] is Map && (raw['data'] as Map)['products'] is List) {
          listData = (raw['data'] as Map)['products'];
        } else if (raw['data'] is List) {
          listData = raw['data'];
        } else if (raw['products'] is List) {
          listData = raw['products'];
        }
      }
      final products = listData.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: products);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProductModel>> scanBarcode(String code) async {
    try {
      final res = await _dio.get('${ApiConstants.scanBarcode}/$code');
      final raw = res.data;
      Map<String, dynamic> item = raw is Map<String, dynamic> ? (raw['product'] ?? raw['data'] ?? raw) : {};
      return ApiResponse(success: true, data: ProductModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<SaleModel>> createSale({
    required String customerPhone,
    required List<PosCartItem> items,
    required double discountAmount,
    required String paymentMethod,
  }) async {
    try {
      final payload = {
        'customer_phone': customerPhone.trim(),
        'items': items.map((i) => i.toJson()).toList(),
        'discount_amount': discountAmount,
        'payment_method': paymentMethod.toLowerCase(),
      };

      final res = await _dio.post(ApiConstants.posSale, data: payload);
      final raw = res.data;
      Map<String, dynamic> billData = raw is Map<String, dynamic> ? (raw['bill'] ?? raw['data'] ?? raw) : {};
      return ApiResponse(success: true, data: SaleModel.fromJson(billData));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Cancel Bill / Void Sale ---
  Future<ApiResponse<bool>> cancelBill(String billNumber, {String reason = ''}) async {
    try {
      await _dio.post(
        ApiConstants.posCancelBill(billNumber),
        data: {'reason': reason.trim()},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Daily POS Summary ---
  Future<ApiResponse<Map<String, dynamic>>> getDailySummary() async {
    try {
      final res = await _dio.get(ApiConstants.posDailySummary);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Scan Barcode or SKU directly ---
  Future<ApiResponse<Map<String, dynamic>>> scanSku(String sku) async {
    try {
      final res = await _dio.get(ApiConstants.posScanSku(sku));
      final data = res.data is Map ? (res.data['product'] ?? res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Receipts & WhatsApp Sharing ---
  Future<ApiResponse<String>> getReceiptPdfUrl(String billNumber) async {
    try {
      final res = await _dio.get(ApiConstants.posReceiptPdf(billNumber));
      final data = res.data is Map ? (res.data['pdf_url'] ?? res.data['url'] ?? '') : '';
      return ApiResponse(success: true, data: data.toString());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getReceiptShareDetails(String billNumber) async {
    try {
      final res = await _dio.get(ApiConstants.posReceiptShare(billNumber));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Day-Close (Z-Report) & Monthly GST Report ---
  Future<ApiResponse<Map<String, dynamic>>> getDayCloseReport() async {
    try {
      final res = await _dio.get(ApiConstants.posDayClose);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getMonthlyGstReport({int? year, int? month}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (month != null) queryParams['month'] = month;
      final res = await _dio.get(ApiConstants.posGstReport, queryParameters: queryParams);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Parked Bills (Hold & Resume Bills) ---
  Future<ApiResponse<Map<String, dynamic>>> parkBill({
    required List<PosCartItem> items,
    String customerPhone = '',
    String notes = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.posPark,
        data: {
          'items': items.map((i) => i.toJson()).toList(),
          'customer_phone': customerPhone.trim(),
          'notes': notes.trim(),
        },
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> listParkedBills() async {
    try {
      final res = await _dio.get(ApiConstants.posPark);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['parked_bills'] is List) {
        list = raw['parked_bills'];
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteParkedBill(String id) async {
    try {
      await _dio.delete(ApiConstants.posParkById(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Weekly Scorecard & Customer History ---
  Future<ApiResponse<Map<String, dynamic>>> getWeeklyScorecard() async {
    try {
      final res = await _dio.get(ApiConstants.posWeeklyScorecard);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCustomerRecentBasket(String phone) async {
    try {
      final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final res = await _dio.get(ApiConstants.posCustomerRecentBasket(clean));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Process In-Store POS Return ---
  Future<ApiResponse<Map<String, dynamic>>> processPosReturn({
    required String billNumber,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    String reason = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.posReturns,
        data: {
          'bill_number': billNumber.trim(),
          'items': items,
          'refund_amount': refundAmount,
          'reason': reason.trim(),
        },
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
