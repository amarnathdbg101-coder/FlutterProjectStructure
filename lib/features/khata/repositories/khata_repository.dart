import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/khata_model.dart';

class KhataRepository {
  final Dio _dio = ApiClient().dio;

  /// Normalizes any input phone number (e.g., +919876543210, 09876543210) to a clean 10-digit number.
  static String normalizePhone(String mobile) {
    final clean = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length > 10) {
      return clean.substring(clean.length - 10);
    }
    return clean;
  }

  Future<ApiResponse<List<KhataCustomerModel>>> getCustomers({String search = ''}) async {
    try {
      final queryParams = search.isNotEmpty ? {'search': search} : null;
      final res = await _dio.get(ApiConstants.khata, queryParameters: queryParams);
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['customers'] is List) {
        listData = raw['customers'];
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      }
      final customers = listData.map((e) => KhataCustomerModel.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: customers);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<KhataTransactionModel>>> getCustomerStatement(String mobile) async {
    try {
      final clean = normalizePhone(mobile);
      final res = await _dio.get('${ApiConstants.khata}/$clean/statement');
      final raw = res.data;
      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map && raw['transactions'] is List) {
        listData = raw['transactions'];
      } else if (raw is Map && raw['data'] is List) {
        listData = raw['data'];
      }
      final txs = listData.map((e) => KhataTransactionModel.fromJson(e as Map<String, dynamic>)).toList();
      return ApiResponse(success: true, data: txs);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> recordCredit({
    required String customerName,
    required String mobile,
    required double amount,
    String notes = '',
    String billNumber = '',
  }) async {
    try {
      final clean = normalizePhone(mobile);
      await _dio.post(
        ApiConstants.khata,
        data: {
          'customer_name': customerName.trim(),
          'customer_mobile': clean,
          'amount': amount,
          'notes': notes.trim(),
          'bill_number': billNumber.trim(),
        },
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> recordPayment({
    required String mobile,
    required String customerName,
    required double amount,
    String paymentMode = 'cash',
    String notes = '',
  }) async {
    try {
      final clean = normalizePhone(mobile);
      await _dio.post(
        ApiConstants.khataRecordPayment(clean),
        data: {
          'customer_name': customerName.trim(),
          'amount': amount,
          'payment_mode': paymentMode.toLowerCase(),
          'notes': notes.trim(),
        },
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Summary & Aging Report ---
  Future<ApiResponse<Map<String, dynamic>>> getSummary() async {
    try {
      final res = await _dio.get(ApiConstants.khataSummary);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAgingReport() async {
    try {
      final res = await _dio.get(ApiConstants.khataAging);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Reminders & Statement Sharing ---
  Future<ApiResponse<Map<String, dynamic>>> getPaymentReminder(String mobile) async {
    try {
      final clean = normalizePhone(mobile);
      final res = await _dio.get(ApiConstants.khataPaymentReminder(clean));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<String>> getStatementPdfUrl(String mobile) async {
    try {
      final clean = normalizePhone(mobile);
      final res = await _dio.get(
        ApiConstants.khataStatementPdf(clean),
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.data is List<int> && (res.data as List<int>).isNotEmpty) {
        final b64 = base64Encode(res.data as List<int>);
        return ApiResponse(success: true, data: 'data:application/pdf;base64,$b64');
      }
      return ApiResponse.failure('Statement PDF could not be generated');
    } catch (_) {
      try {
        final clean = normalizePhone(mobile);
        final res = await _dio.get(ApiConstants.khataStatementPdf(clean));
        final data = res.data is Map ? (res.data['pdf_url'] ?? res.data['url'] ?? '') : '';
        if (data.toString().isNotEmpty) {
          return ApiResponse(success: true, data: data.toString());
        }
      } catch (e) {
        return ApiResponse.failure(ApiClient.handleError(e));
      }
      return ApiResponse.failure('Statement PDF unavailable');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStatementShare(String mobile) async {
    try {
      final clean = normalizePhone(mobile);
      final res = await _dio.get(ApiConstants.khataStatementShare(clean));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Credit Limit Management ---
  Future<ApiResponse<bool>> updateCreditLimit(String mobile, double creditLimit) async {
    try {
      final clean = normalizePhone(mobile);
      await _dio.put(
        ApiConstants.khataCreditLimit(clean),
        data: {'credit_limit': creditLimit},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Account Closure & OTP Protection ---
  Future<ApiResponse<Map<String, dynamic>>> requestClosure(String khataId) async {
    try {
      final res = await _dio.post(ApiConstants.khataRequestClosure(khataId));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> verifyClosureOtp(String khataId, String otp) async {
    try {
      await _dio.post(
        ApiConstants.khataVerifyClosureOtp(khataId),
        data: {'otp': otp.trim()},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Reverse Transaction & Dispute Resolution ---
  Future<ApiResponse<bool>> reverseTransaction(String khataId, String txId, {String reason = ''}) async {
    try {
      await _dio.post(
        ApiConstants.khataReverseTx(khataId, txId),
        data: {'reason': reason.trim()},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> resolveDispute(String khataId, String txId, {required String resolution}) async {
    try {
      await _dio.post(
        ApiConstants.khataResolveDispute(khataId, txId),
        data: {'resolution': resolution.trim()},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Promise-to-Pay Date & Trust Score ---
  Future<ApiResponse<bool>> setPromiseToPay(String khataId, String promiseDate) async {
    try {
      await _dio.post(
        ApiConstants.khataPromiseDate(khataId),
        data: {'promise_date': promiseDate.trim()},
      );
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCustomerTrustScore(String mobile) async {
    try {
      final clean = normalizePhone(mobile);
      final res = await _dio.get(ApiConstants.khataTrustScore(clean));
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
