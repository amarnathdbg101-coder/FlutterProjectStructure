import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

class DashboardStats {
  final double todaySales;
  final int salesCount;
  final double totalUdhar;
  final int udharCustomersCount;
  final int lowStockCount;
  final int catalogCount;

  DashboardStats({
    this.todaySales = 0.0,
    this.salesCount = 0,
    this.totalUdhar = 0.0,
    this.udharCustomersCount = 0,
    this.lowStockCount = 0,
    this.catalogCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'today_sales': todaySales,
    'sales_count': salesCount,
    'total_udhar': totalUdhar,
    'udhar_customers_count': udharCustomersCount,
    'low_stock_count': lowStockCount,
    'catalog_count': catalogCount,
  };

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    todaySales: (json['today_sales'] as num?)?.toDouble() ?? 0.0,
    salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
    totalUdhar: (json['total_udhar'] as num?)?.toDouble() ?? 0.0,
    udharCustomersCount: (json['udhar_customers_count'] as num?)?.toInt() ?? 0,
    lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
    catalogCount: (json['catalog_count'] as num?)?.toInt() ?? 0,
  );
}

class DashboardRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<DashboardStats>> getDashboardStats() async {
    try {
      double todaySales = 0.0;
      int salesCount = 0;
      double totalUdhar = 0.0;
      int udharCustomers = 0;
      int lowStock = 0;
      int catalog = 0;

      // 1. First attempt fast aggregated digest from GoBackend
      bool hasDigest = false;
      try {
        final dashRes = await _dio.get(ApiConstants.shopDashboard);
        final raw = dashRes.data is Map ? dashRes.data : {};
        final digest = raw['digest'] ?? (raw['data'] is Map ? raw['data']['digest'] : null);
        if (digest is Map) {
          todaySales = (digest['today_sales_amount'] as num?)?.toDouble() ?? 0.0;
          salesCount = (digest['today_sales_count'] as num?)?.toInt() ?? 0;
          totalUdhar = (digest['total_khata_udhar'] as num?)?.toDouble() ?? 0.0;
          udharCustomers = (digest['total_khata_customers'] as num?)?.toInt() ?? 0;
          lowStock = (digest['low_stock_count'] as num?)?.toInt() ?? 0;
          hasDigest = true;
        }
      } catch (_) {}

      // Fallback to POS Daily Summary if digest not available
      if (!hasDigest) {
        try {
          final posRes = await _dio.get(ApiConstants.posDailySummary);
          final posData = posRes.data is Map ? posRes.data : {};
          todaySales = (posData['total_sales'] is num)
              ? (posData['total_sales'] as num).toDouble()
              : (posData['total_amount'] is num)
                  ? (posData['total_amount'] as num).toDouble()
                  : 0.0;
          salesCount = (posData['bill_count'] is num)
              ? (posData['bill_count'] as num).toInt()
              : (posData['total_bills'] is num)
                  ? (posData['total_bills'] as num).toInt()
                  : 0;
        } catch (_) {}
      }

      // 2. Fetch Khata Summary
      try {
        final khataRes = await _dio.get(ApiConstants.khataSummary);
        final khataData = khataRes.data is Map ? khataRes.data : {};
        totalUdhar = (khataData['total_market_debt'] is num)
            ? (khataData['total_market_debt'] as num).toDouble()
            : (khataData['total_udhar'] is num)
                ? (khataData['total_udhar'] as num).toDouble()
                : 0.0;
        udharCustomers = (khataData['total_customers'] is num)
            ? (khataData['total_customers'] as num).toInt()
            : (khataData['customer_count'] is num)
                ? (khataData['customer_count'] as num).toInt()
                : 0;
      } catch (_) {}

      // 3. Fetch Low Stock
      try {
        final lowStockRes = await _dio.get(ApiConstants.lowStockAlerts);
        if (lowStockRes.data is List) {
          lowStock = (lowStockRes.data as List).length;
        } else if (lowStockRes.data is Map) {
          final lsMap = lowStockRes.data as Map;
          if (lsMap['data'] is List) {
            lowStock = (lsMap['data'] as List).length;
          } else if (lsMap['data'] is Map && (lsMap['data'] as Map)['items'] is List) {
            lowStock = ((lsMap['data'] as Map)['items'] as List).length;
          } else if (lsMap['items'] is List) {
            lowStock = (lsMap['items'] as List).length;
          }
        }
      } catch (_) {}

      // 4. Fetch Products Count
      try {
        final prodRes = await _dio.get(ApiConstants.myProducts);
        if (prodRes.data is List) {
          catalog = (prodRes.data as List).length;
        } else if (prodRes.data is Map) {
          final pMap = prodRes.data as Map;
          if (pMap['data'] is Map && (pMap['data'] as Map)['total_count'] is num) {
            catalog = ((pMap['data'] as Map)['total_count'] as num).toInt();
          } else if (pMap['data'] is Map && (pMap['data'] as Map)['products'] is List) {
            catalog = ((pMap['data'] as Map)['products'] as List).length;
          } else if (pMap['data'] is List) {
            catalog = (pMap['data'] as List).length;
          } else if (pMap['products'] is List) {
            catalog = (pMap['products'] as List).length;
          }
        }
      } catch (_) {}

      return ApiResponse(
        success: true,
        data: DashboardStats(
          todaySales: todaySales,
          salesCount: salesCount,
          totalUdhar: totalUdhar,
          udharCustomersCount: udharCustomers,
          lowStockCount: lowStock,
          catalogCount: catalog,
        ),
      );
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<String>> getShopQr() async {
    try {
      final res = await _dio.get(ApiConstants.shopQr);
      final data = res.data is Map ? res.data : {};
      final qr = data['qr_code_url'] ?? data['qr'] ?? '';
      return ApiResponse(success: true, data: qr.toString());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Merchant Dashboard & Daily Digest ---
  Future<ApiResponse<Map<String, dynamic>>> getMerchantDashboard() async {
    try {
      final res = await _dio.get(ApiConstants.shopDashboard);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getDailyDigest() async {
    try {
      final res = await _dio.get(ApiConstants.shopDigest);
      final data = res.data is Map ? (res.data['digest'] ?? res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Shop CRUD & Recovery ---
  Future<ApiResponse<Map<String, dynamic>>> createShop(Map<String, dynamic> shopData) async {
    try {
      final res = await _dio.post(ApiConstants.createShop, data: shopData);
      return ApiResponse.fromJson(res.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateMyShop(Map<String, dynamic> updateData) async {
    try {
      final res = await _dio.put(ApiConstants.myShop, data: updateData);
      return ApiResponse.fromJson(res.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteMyShop() async {
    try {
      await _dio.delete(ApiConstants.myShop);
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> restoreMyShop() async {
    try {
      await _dio.post(ApiConstants.restoreShop);
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadShopImages(List<String> filePaths) async {
    try {
      final files = await Future.wait(filePaths.map((p) => MultipartFile.fromFile(p)));
      final formData = FormData.fromMap({'banners': files});
      final res = await _dio.post(ApiConstants.shopImages, data: formData);
      return ApiResponse.fromJson(res.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Shop Staff & Cashier Sub-accounts ---
  Future<ApiResponse<List<Map<String, dynamic>>>> listStaff() async {
    try {
      final res = await _dio.get(ApiConstants.shopStaff);
      final raw = res.data;
      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['staff'] is List) {
        list = raw['staff'];
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      return ApiResponse(success: true, data: list.cast<Map<String, dynamic>>());
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createStaff({
    required String fullName,
    required String phone,
    required String pin,
    String role = 'cashier',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.shopStaff,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'pin': pin.trim(),
          'role': role,
        },
      );
      return ApiResponse.fromJson(res.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put(ApiConstants.staffById(id), data: data);
      return ApiResponse.fromJson(res.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteStaff(String id) async {
    try {
      await _dio.delete(ApiConstants.staffById(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
