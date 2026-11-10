import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/pos_features_model.dart';

class PosAdvancedRepository {
  final Dio _dio = ApiClient().dio;

  // 1. Live Margin Floor Check
  Future<ApiResponse<MarginCheckResult>> checkMarginFloor({
    required List<MarginCheckItem> items,
    double billDiscount = 0.0,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.posMarginCheck,
        data: {
          'items': items.map((e) => e.toJson()).toList(),
          'bill_discount': billDiscount,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map<String, dynamic>) {
        data = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
      }
      return ApiResponse(success: true, data: MarginCheckResult.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 1B. Touch Counter Hotkeys
  Future<ApiResponse<List<HotkeyItem>>> getHotkeys() async {
    try {
      final res = await _dio.get(ApiConstants.posHotkeys);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => HotkeyItem.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<HotkeyItem>> createHotkey(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(ApiConstants.posHotkeys, data: payload);
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: HotkeyItem.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteHotkey(String id) async {
    try {
      await _dio.delete(ApiConstants.posHotkeyById(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<HotkeyItem>>> autoPopulateHotkeys() async {
    try {
      final res = await _dio.post(ApiConstants.posHotkeysAutoPopulate);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => HotkeyItem.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 2. Cash Drawer Shift Accountability & Safe Drops
  Future<ApiResponse<CashDrawerSession>> getCurrentDrawerStatus() async {
    try {
      final res = await _dio.get(ApiConstants.drawerCurrent);
      final raw = res.data;
      Map<String, dynamic> data = {};
      if (raw is Map<String, dynamic>) {
        data = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
      }
      return ApiResponse(success: true, data: CashDrawerSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<CashDrawerSession>> openDrawerSession({
    required double openingCash,
    String notes = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.drawerOpen,
        data: {
          'opening_cash': openingCash,
          'notes': notes,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: CashDrawerSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<CashDrawerSession>> closeDrawerSession({
    required double closingCash,
    String notes = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.drawerClose,
        data: {
          'closing_cash': closingCash,
          'notes': notes,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: CashDrawerSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<CashDrawerSession>> recordSafeDrop({
    required double amount,
    String notes = '',
    String envelopeNumber = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.drawerSafeDrop,
        data: {
          'amount': amount,
          'notes': notes,
          'envelope_number': envelopeNumber,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: CashDrawerSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<CashDrawerSession>> recordPettyExpense({
    required double amount,
    required String category,
    String notes = '',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.drawerExpense,
        data: {
          'amount': amount,
          'category': category,
          'notes': notes,
        },
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: CashDrawerSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<CashDrawerSession>>> getDrawerHistory() async {
    try {
      final res = await _dio.get(ApiConstants.drawerHistory);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => CashDrawerSession.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 3. Rush-Hour Scan & Go (Queue Buster)
  Future<ApiResponse<ScanAndGoSession>> verifyScanAndGo(String code) async {
    try {
      final res = await _dio.get(ApiConstants.scanGoVerify(code.trim()));
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: ScanAndGoSession.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> convertScanAndGo(String code) async {
    try {
      final res = await _dio.post(ApiConstants.scanGoConvert(code.trim()));
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: data);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 4. Company Damage Claim Vault & Receiptless Return Lookup
  Future<ApiResponse<DamageClaim>> createDamageClaim(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(ApiConstants.claims, data: payload);
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: DamageClaim.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<DamageClaim>>> listDamageClaims({String? status, String? distributor}) async {
    try {
      final query = <String, dynamic>{};
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (distributor != null && distributor.isNotEmpty) query['distributor'] = distributor;

      final res = await _dio.get(ApiConstants.claims, queryParameters: query.isNotEmpty ? query : null);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => DamageClaim.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<DamageClaim>> updateDamageClaimStatus(String id, String status, {String note = ''}) async {
    try {
      final res = await _dio.patch(
        ApiConstants.claimStatus(id),
        data: {'status': status, 'distributor_note': note},
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: DamageClaim.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<DistributorClaimSummary>> getDistributorClaimSummary(String distributor) async {
    try {
      final res = await _dio.get(
        ApiConstants.claimsDistributorSummary,
        queryParameters: {'distributor': distributor},
      );
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: DistributorClaimSummary.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<ReturnLookupItem>>> lookupReturns({String? phone, String? barcode}) async {
    try {
      final query = <String, dynamic>{};
      if (phone != null && phone.trim().isNotEmpty) query['phone'] = phone.trim();
      if (barcode != null && barcode.trim().isNotEmpty) query['barcode'] = barcode.trim();

      final res = await _dio.get(ApiConstants.posReturnsLookup, queryParameters: query);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => ReturnLookupItem.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 5. Batch Expiry Radar & Near-Expiry Auto-Markdown
  Future<ApiResponse<ProductBatch>> createProductBatch(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(ApiConstants.batches, data: payload);
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: ProductBatch.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<ProductBatch>>> listNearExpiryBatches({int days = 30}) async {
    try {
      final res = await _dio.get(
        ApiConstants.batchesNearExpiry,
        queryParameters: {'days': days},
      );
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      final items = list.map((e) => ProductBatch.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<MarkdownScanResult>> runMarkdownScan() async {
    try {
      final res = await _dio.post(ApiConstants.batchMarkdownScan);
      final raw = res.data;
      Map<String, dynamic> data = raw is Map && raw['data'] is Map ? raw['data'] : (raw is Map ? raw as Map<String, dynamic> : {});
      return ApiResponse(success: true, data: MarkdownScanResult.fromJson(data));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // 7. Chromedp Automated End-of-Day P&L PDF
  Future<ApiResponse<Uint8List>> downloadEndOfDayReportPdfBytes() async {
    try {
      final res = await _dio.get<List<int>>(
        ApiConstants.posDayCloseEodPdf,
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.data != null) {
        return ApiResponse(success: true, data: Uint8List.fromList(res.data!));
      }
      return ApiResponse.failure('Could not download P&L PDF');
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}

