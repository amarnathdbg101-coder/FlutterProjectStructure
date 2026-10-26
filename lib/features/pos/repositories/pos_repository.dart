import 'dart:convert';
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
      final cleanCode = code.trim();
      // 1. Query shop's own SKU/Barcode scanner endpoint
      final res = await _dio.get(ApiConstants.posScanSku(cleanCode));
      final raw = res.data;
      Map<String, dynamic> item = {};
      if (raw is Map<String, dynamic>) {
        if (raw['data'] is Map<String, dynamic>) {
          final d = raw['data'] as Map<String, dynamic>;
          item = d['product'] is Map<String, dynamic> ? d['product'] as Map<String, dynamic> : d;
        } else if (raw['product'] is Map<String, dynamic>) {
          item = raw['product'] as Map<String, dynamic>;
        } else {
          item = raw;
        }
      }
      if (item.isNotEmpty && item['name'] != null) {
        return ApiResponse(success: true, data: ProductModel.fromJson(item));
      }
      return ApiResponse.failure('Product not found');
    } catch (_) {
      try {
        // 2. Fallback to general barcode database
        final res = await _dio.get('${ApiConstants.scanBarcode}/${code.trim()}');
        final raw = res.data;
        Map<String, dynamic> item = raw is Map<String, dynamic> ? (raw['product'] ?? raw['data'] ?? raw) : {};
        if (item.isNotEmpty && item['name'] != null) {
          return ApiResponse(success: true, data: ProductModel.fromJson(item));
        }
      } catch (e2) {
        return ApiResponse.failure(ApiClient.handleError(e2));
      }
      return ApiResponse.failure('Product not found in inventory');
    }
  }

  Future<ApiResponse<SaleModel>> createSale({
    required String customerPhone,
    String customerName = '',
    required List<PosCartItem> items,
    required double discountAmount,
    required String paymentMethod,
    PosSplitPayment? splitPayments,
    String? idempotencyKey,
  }) async {
    try {
      final payload = {
        'customer_phone': customerPhone.trim(),
        if (customerName.trim().isNotEmpty) 'customer_name': customerName.trim(),
        'items': items.map((i) => i.toJson()).toList(),
        'discount_amount': discountAmount,
        'payment_method': paymentMethod.toLowerCase(),
        if (splitPayments != null) 'split_payments': splitPayments.toJson(),
      };

      final key = idempotencyKey ?? 'pos_${DateTime.now().microsecondsSinceEpoch}';
      final res = await _dio.post(
        ApiConstants.posSale,
        data: payload,
        options: Options(
          headers: {
            'X-Idempotency-Key': key,
          },
        ),
      );
      final raw = res.data;
      Map<String, dynamic> billData = {};
      if (raw is Map<String, dynamic>) {
        if (raw['bill'] is Map<String, dynamic>) {
          billData = raw['bill'] as Map<String, dynamic>;
        } else if (raw['data'] is Map<String, dynamic>) {
          final d = raw['data'] as Map<String, dynamic>;
          billData = (d['bill'] is Map<String, dynamic>) ? d['bill'] as Map<String, dynamic> : d;
        } else {
          billData = raw;
        }
      }
      return ApiResponse(success: true, data: SaleModel.fromJson(billData));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Get Sales History from PostgreSQL ---
  Future<ApiResponse<List<SaleModel>>> getSales({int page = 1, int limit = 50, String date = ''}) async {
    try {
      final res = await _dio.get(
        ApiConstants.posSales,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (date.isNotEmpty) 'date': date,
        },
      );
      final raw = res.data;
      List billsList = [];
      if (raw is Map<String, dynamic>) {
        if (raw['data'] is Map<String, dynamic> && (raw['data'] as Map<String, dynamic>)['bills'] is List) {
          billsList = (raw['data'] as Map<String, dynamic>)['bills'] as List;
        } else if (raw['bills'] is List) {
          billsList = raw['bills'] as List;
        } else if (raw['data'] is List) {
          billsList = raw['data'] as List;
        }
      } else if (raw is List) {
        billsList = raw;
      }

      final sales = billsList
          .whereType<Map>()
          .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResponse(success: true, data: sales);
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
      final res = await _dio.get(
        ApiConstants.posReceiptPdf(billNumber),
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.data is List<int> && (res.data as List<int>).isNotEmpty) {
        final b64 = base64Encode(res.data as List<int>);
        return ApiResponse(success: true, data: 'data:application/pdf;base64,$b64');
      }
      return ApiResponse.failure('Receipt PDF could not be generated');
    } catch (_) {
      try {
        final res = await _dio.get(ApiConstants.posReceiptPdf(billNumber));
        final data = res.data is Map ? (res.data['pdf_url'] ?? res.data['url'] ?? '') : '';
        if (data.toString().isNotEmpty) {
          return ApiResponse(success: true, data: data.toString());
        }
      } catch (e) {
        return ApiResponse.failure(ApiClient.handleError(e));
      }
      return ApiResponse.failure('Receipt PDF unavailable');
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

  // --- Parked Bills (Hold & Resume Bills / Floor Assisted Baskets) ---
  Future<ApiResponse<Map<String, dynamic>>> parkBill({
    String label = '',
    required List<PosCartItem> items,
    double discountAmount = 0.0,
    String customerPhone = '',
    String paymentMethod = 'cash',
    String notes = '',
  }) async {
    try {
      final payload = {
        'label': label.trim().isNotEmpty ? label.trim() : notes.trim(),
        'customer_phone': customerPhone.trim(),
        'items': items.map((i) => i.toJson()).toList(),
        'discount_amount': discountAmount,
        'payment_method': paymentMethod.toLowerCase(),
        if (notes.isNotEmpty) 'notes': notes.trim(),
      };
      final res = await _dio.post(ApiConstants.posPark, data: payload);
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map<String, dynamic>) {
        data = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
      }
      return ApiResponse(success: true, data: data);
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

  Future<ApiResponse<Map<String, dynamic>>> getParkedBill(String idOrToken) async {
    try {
      final res = await _dio.get(ApiConstants.posParkById(idOrToken));
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map<String, dynamic>) {
        data = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
      }
      return ApiResponse(success: true, data: data);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteParkedBill(String idOrToken) async {
    try {
      await _dio.delete(ApiConstants.posParkById(idOrToken));
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
    String refundMode = 'cash',
    String reason = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.posReturns,
        data: {
          'bill_number': billNumber.trim(),
          'items': items,
          'refund_mode': refundMode,
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
