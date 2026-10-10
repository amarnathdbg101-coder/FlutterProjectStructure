import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../models/product_model.dart';

class ProductRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<List<ProductModel>>> getMyProducts({String search = '', String category = ''}) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': 100,
      };
      if (search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
        queryParams['q'] = search.trim();
      }
      if (category.trim().isNotEmpty && category != 'All' && category != 'All Items') {
        queryParams['category_id'] = category.trim();
      }

      final res = await _dio.get(ApiConstants.products, queryParameters: queryParams);
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }

      List listData = [];
      if (raw is List) {
        listData = raw;
      } else if (raw is Map) {
        final dataField = raw['data'];
        if (dataField is Map && dataField['products'] is List) {
          listData = dataField['products'] as List;
        } else if (dataField is List) {
          listData = dataField;
        } else if (raw['products'] is List) {
          listData = raw['products'] as List;
        } else if (raw['items'] is List) {
          listData = raw['items'] as List;
        }
      }

      final items = <ProductModel>[];
      for (final e in listData) {
        try {
          if (e is Map) {
            items.add(ProductModel.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (_) {}
      }
      return ApiResponse(success: true, data: items);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProductModel>> createProduct(Map<String, dynamic> productData) async {
    try {
      final res = await _dio.post(ApiConstants.createProduct, data: productData);
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      Map<String, dynamic> item = {};
      if (raw is Map) {
        if (raw['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(raw['data'] as Map);
          item = (dataMap['product'] is Map) ? Map<String, dynamic>.from(dataMap['product'] as Map) : dataMap;
        } else if (raw['product'] is Map) {
          item = Map<String, dynamic>.from(raw['product'] as Map);
        } else {
          item = Map<String, dynamic>.from(raw);
        }
      }
      return ApiResponse(success: true, data: ProductModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ProductModel>> updateProduct(dynamic id, Map<String, dynamic> updateData) async {
    try {
      final res = await _dio.put('${ApiConstants.productById}/$id', data: updateData);
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      Map<String, dynamic> item = {};
      if (raw is Map) {
        if (raw['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(raw['data'] as Map);
          item = (dataMap['product'] is Map) ? Map<String, dynamic>.from(dataMap['product'] as Map) : dataMap;
        } else if (raw['product'] is Map) {
          item = Map<String, dynamic>.from(raw['product'] as Map);
        } else {
          item = Map<String, dynamic>.from(raw);
        }
      }
      return ApiResponse(success: true, data: ProductModel.fromJson(item));
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> deleteProduct(dynamic id) async {
    try {
      await _dio.delete('${ApiConstants.productById}/$id');
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> adjustStock({required dynamic productId, required int adjustment, int? lowStockThreshold, String notes = ''}) async {
    try {
      final payload = <String, dynamic>{
        'product_id': productId.toString(),
        'adjustment': adjustment,
      };
      if (lowStockThreshold != null) payload['low_stock_threshold'] = lowStockThreshold;
      if (notes.isNotEmpty) payload['notes'] = notes;

      await _dio.post(ApiConstants.adjustStock, data: payload);
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Product Images Upload ---
  Future<ApiResponse<List<String>>> uploadProductImages(List<String> filePaths) async {
    try {
      final xFiles = filePaths.map((p) => XFile(p)).toList();
      return await uploadProductXFiles(xFiles);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<String>>> uploadProductXFiles(List<XFile> xFiles) async {
    try {
      final multipartFiles = <MultipartFile>[];
      for (final f in xFiles.take(4)) {
        final bytes = await f.readAsBytes();
        var fileName = f.name.trim();
        if (fileName.isEmpty || !fileName.contains('.')) {
          fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_${multipartFiles.length}.jpg';
        }

        final ext = fileName.split('.').last.toLowerCase();
        MediaType mediaType;
        if (ext == 'png') {
          mediaType = MediaType('image', 'png');
        } else if (ext == 'webp') {
          mediaType = MediaType('image', 'webp');
        } else if (ext == 'gif') {
          mediaType = MediaType('image', 'gif');
        } else {
          mediaType = MediaType('image', 'jpeg');
        }

        multipartFiles.add(MultipartFile.fromBytes(bytes, filename: fileName, contentType: mediaType));
      }

      final formData = FormData.fromMap({'images': multipartFiles}, ListFormat.multi);
      final res = await _dio.post(ApiConstants.productImages, data: formData);

      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }

      List urls = [];
      if (raw is List) {
        urls = raw;
      } else if (raw is Map) {
        final data = raw['data'];
        if (data is Map) {
          if (data['images'] is List) {
            urls = data['images'];
          } else if (data['urls'] is List) {
            urls = data['urls'];
          } else if (data['image_url'] != null) {
            urls = [data['image_url']];
          } else if (data['url'] != null) {
            urls = [data['url']];
          }
        } else if (data is List) {
          urls = data;
        } else if (data is String && data.isNotEmpty) {
          urls = [data];
        } else if (raw['images'] is List) {
          urls = raw['images'];
        } else if (raw['urls'] is List) {
          urls = raw['urls'];
        }
      }

      final parsedUrls = urls.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (parsedUrls.isEmpty && xFiles.isNotEmpty) {
        return ApiResponse.failure('Product image upload failed on server');
      }
      return ApiResponse(success: true, data: parsedUrls);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Clearance Markdown ---
  Future<ApiResponse<Map<String, dynamic>>> applyClearanceMarkdown(String id, double discountPercent) async {
    try {
      final res = await _dio.post(
        ApiConstants.productMarkdown(id),
        data: {'discount_percent': discountPercent},
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Bulk Import CSV ---
  Future<ApiResponse<Map<String, dynamic>>> bulkImport(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.post(ApiConstants.productsBulkImport, data: formData);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Low Stock Alerts ---
  Future<ApiResponse<Map<String, dynamic>>> getLowStockAlerts() async {
    try {
      final res = await _dio.get(ApiConstants.lowStockAlerts);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<bool>> dismissStockAlert(String id) async {
    try {
      await _dio.post(ApiConstants.dismissStockAlert(id));
      return ApiResponse(success: true, data: true);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Demand Watchlist & Wholesale Restock ---
  Future<ApiResponse<Map<String, dynamic>>> getDemandWatchlist() async {
    try {
      final res = await _dio.get(ApiConstants.demandWatchlist);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getSupplierReorderWhatsApp() async {
    try {
      final res = await _dio.get(ApiConstants.supplierReorderWhatsapp);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> generateCustomProcurementPdf({
    String title = 'Procurement Order',
    required List<Map<String, String>> items,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.procurementPdf,
        data: {'title': title, 'items': items},
      );
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Shop Analytics & Monthly Profit ---
  Future<ApiResponse<Map<String, dynamic>>> getMonthlyProfit({int? year, int? month}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (month != null) queryParams['month'] = month;
      final res = await _dio.get(ApiConstants.analyticsProfit, queryParameters: queryParams);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getProductMatrix() async {
    try {
      final res = await _dio.get(ApiConstants.analyticsProducts);
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      return ApiResponse(success: true, data: data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
