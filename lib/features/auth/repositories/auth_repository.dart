import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/storage/token_storage.dart';
import '../../dashboard/models/shop_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'email': email.trim(),
          'password': password,
          'role': 'merchant',
        },
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'full_name': fullName.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': 'merchant',
        },
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> staffLogin({
    required String pin,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.staffLogin,
        data: {'pin': pin.trim()},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ShopModel>> getMyShop() async {
    try {
      final response = await _dio.get(ApiConstants.myShop);
      return ApiResponse.fromJson(response.data, (data) {
        if (data is Map) {
          final m = Map<String, dynamic>.from(data);
          final inner = m['shop'] ?? m['data'] ?? m;
          if (inner is Map) {
            return ShopModel.fromJson(Map<String, dynamic>.from(inner));
          }
        }
        return ShopModel(id: '', name: 'Store', slug: '', phone: '', category: '');
      });
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ShopModel>> createShop(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        ApiConstants.createShop,
        data: data,
      );
      final raw = response.data;
      if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        final dataMap = rawMap['data'] ?? rawMap;
        if (dataMap is Map) {
          final m = Map<String, dynamic>.from(dataMap);
          if (m['access_token'] != null) {
            final newJwt = m['access_token'].toString();
            if (newJwt.isNotEmpty) {
              await TokenStorage.saveToken(newJwt);
            }
          }
          final shopMap = m['shop'] ?? m;
          if (shopMap is Map) {
            return ApiResponse(success: true, data: ShopModel.fromJson(Map<String, dynamic>.from(shopMap)));
          }
        }
      }
      return ApiResponse.fromJson(response.data, (d) {
        if (d is Map) {
          final m = Map<String, dynamic>.from(d);
          final inner = m['shop'] ?? m['data'] ?? m;
          if (inner is Map) {
            return ShopModel.fromJson(Map<String, dynamic>.from(inner));
          }
        }
        return ShopModel(id: '', name: 'Store', slug: '', phone: '', category: '');
      });
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ShopModel>> updateShop(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        ApiConstants.myShop,
        data: data,
      );
      return ApiResponse.fromJson(response.data, (d) {
        if (d is Map) {
          final m = Map<String, dynamic>.from(d);
          final inner = m['shop'] ?? m['data'] ?? m;
          if (inner is Map) {
            return ShopModel.fromJson(Map<String, dynamic>.from(inner));
          }
        }
        return ShopModel(id: '', name: 'Store', slug: '', phone: '', category: '');
      });
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ShopModel>> toggleShopStatus(bool isOpen) async {
    try {
      final response = await _dio.patch(
        ApiConstants.updateShopStatus,
        data: {'is_open': isOpen},
      );
      return ApiResponse.fromJson(response.data, (data) {
        final map = (data is Map<String, dynamic>) ? (data['shop'] ?? data['data'] ?? data) : data;
        return ShopModel.fromJson(map as Map<String, dynamic>);
      });
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteShop() async {
    try {
      final response = await _dio.delete(ApiConstants.myShop);
      return ApiResponse.fromJson(response.data, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<ShopModel>> restoreShop() async {
    try {
      final response = await _dio.post(ApiConstants.restoreShop);
      return ApiResponse.fromJson(response.data, (d) {
        final map = (d is Map<String, dynamic>) ? (d['shop'] ?? d['data'] ?? d) : d;
        return ShopModel.fromJson(map as Map<String, dynamic>);
      });
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- OTP Verification (Phone login / registration) ---
  Future<ApiResponse<Map<String, dynamic>>> sendOtp({
    required String phone,
    String channel = 'whatsapp',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.sendOtp,
        data: {'phone': phone.trim(), 'channel': channel},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyOtp,
        data: {'phone': phone.trim(), 'otp': otp.trim()},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Password Management ---
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        ApiConstants.forgotPassword,
        data: {'email': email.trim()},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.resetPassword,
        data: {'token': token.trim(), 'new_password': newPassword},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- Token Refresh ---
  Future<ApiResponse<Map<String, dynamic>>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  // --- User Profile ---
  Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    try {
      final payload = <String, dynamic>{'full_name': fullName.trim()};
      if (phone != null && phone.isNotEmpty) payload['phone'] = phone.trim();
      final response = await _dio.put(ApiConstants.updateProfile, data: payload);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(ApiConstants.userAvatar, data: formData);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadUserAvatar(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final response = await _dio.post(ApiConstants.userAvatar, data: formData);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadShopLogo(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'logo': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final response = await _dio.post(ApiConstants.shopImages, data: formData);
      return ApiResponse.fromJson(response.data, (data) => data as Map<String, dynamic>);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }

  Future<ApiResponse<List<String>>> uploadShopBanners(List<XFile> bannerFiles) async {
    try {
      final multipartFiles = <MultipartFile>[];
      for (final b in bannerFiles.take(2)) {
        final bytes = await b.readAsBytes();
        multipartFiles.add(MultipartFile.fromBytes(bytes, filename: b.name));
      }
      final formData = FormData.fromMap({'banners': multipartFiles}, ListFormat.multi);
      final res = await _dio.post(ApiConstants.shopImages, data: formData);
      final raw = res.data;
      List urls = [];
      if (raw is Map && raw['data'] is Map && raw['data']['banners'] is List) {
        urls = raw['data']['banners'];
      } else if (raw is Map && raw['banners'] is List) {
        urls = raw['banners'];
      } else if (raw is List) {
        urls = raw;
      }
      final parsedUrls = urls.map((e) => e.toString()).toList();
      if (parsedUrls.isEmpty && bannerFiles.isNotEmpty) {
        return ApiResponse.failure('Failed to obtain uploaded banner URLs');
      }
      return ApiResponse(success: true, data: parsedUrls);
    } catch (e) {
      return ApiResponse.failure(ApiClient.handleError(e));
    }
  }
}
