import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/counter_websocket_service.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../dashboard/models/shop_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthController extends BaseController {
  final AuthRepository _repo = AuthRepository();

  UserModel? _currentUser;
  ShopModel? _currentShop;
  List<ShopModel> _managedShops = [];
  bool _isStaff = false;

  UserModel? get currentUser => _currentUser;
  ShopModel? get currentShop => _currentShop;
  ShopModel? get shop => _currentShop;
  List<ShopModel> get managedShops => List.unmodifiable(_managedShops);
  bool get isStaff => _isStaff;
  bool get isAuthenticated => TokenStorage.hasToken();

  @visibleForTesting
  void setShopForTesting(ShopModel? shop) {
    _currentShop = shop;
    if (shop != null) {
      final idx = _managedShops.indexWhere((s) => s.id == shop.id);
      if (idx >= 0) {
        _managedShops[idx] = shop;
      } else {
        _managedShops.add(shop);
      }
    }
    notifyListeners();
  }

  @visibleForTesting
  void setManagedShopsForTesting(List<ShopModel> shops) {
    _managedShops = List.from(shops);
    if (shops.isNotEmpty) {
      _currentShop = shops.first;
    }
    notifyListeners();
  }

  AuthController() {
    _hydrateLocalSession();
  }

  void _hydrateLocalSession() {
    final userJson = TokenStorage.getUser();
    if (userJson != null) {
      _currentUser = UserModel.fromJson(userJson);
    }
    final shopJson = TokenStorage.getShop();
    if (shopJson != null) {
      _currentShop = ShopModel.fromJson(shopJson);
    }
    final staffJson = TokenStorage.getStaff();
    if (staffJson != null) {
      _isStaff = true;
    }

    // Hydrate managed branches / outlets
    final cachedShops = LocalCacheService.getManagedShops();
    if (cachedShops.isNotEmpty) {
      _managedShops = cachedShops;
    } else if (_currentShop != null) {
      _managedShops = [_currentShop!];
    }
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    clearError();

    final response = await _repo.login(email: email, password: password);
    setLoading(false);

    if (response.success && response.data != null) {
      final payload = response.data!;
      final token = payload['access_token'] ?? payload['token'];
      final userData = payload['user'];

      if (token != null) {
        if (userData != null && userData is Map<String, dynamic>) {
          _currentUser = UserModel.fromJson(userData);
        } else {
          _currentUser = UserModel(
            id: '1',
            name: email.split('@').first,
            email: email,
            role: 'merchant',
          );
        }

        // Strict role enforcement: Customers cannot access merchant portal
        if (!_currentUser!.isMerchant) {
          // Check if this user owns a shop before rejecting
          await TokenStorage.saveSession(
            token: token.toString(),
            user: _currentUser?.toJson(),
          );
          final shopRes = await _repo.getMyShop();
          if (shopRes.success && shopRes.data != null && shopRes.data!.id.isNotEmpty) {
            _currentUser = UserModel(
              id: _currentUser!.id,
              name: _currentUser!.name,
              email: _currentUser!.email,
              phone: _currentUser!.phone,
              role: 'merchant',
              createdAt: _currentUser!.createdAt,
            );
          } else {
            setError('This account is registered as a customer and cannot access the merchant partner portal.');
            await TokenStorage.clearSession();
            _currentUser = null;
            notifyListeners();
            return false;
          }
        }

        _isStaff = false;

        await TokenStorage.saveSession(
          token: token.toString(),
          user: _currentUser?.toJson(),
        );

        // Clear any stale shop from prior user and fetch in background
        _currentShop = null;
        await TokenStorage.removeShop();
        fetchShopDetails();
        fetchUserProfile();

        notifyListeners();
        return true;
      }
    }

    setError(response.error ?? 'Invalid email or password');
    return false;
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    setLoading(true);
    clearError();

    final response = await _repo.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );
    setLoading(false);

    if (response.success && response.data != null) {
      final payload = response.data!;
      final token = payload['access_token'] ?? payload['token'];
      final userData = payload['user'];

      if (token != null) {
        if (userData != null && userData is Map<String, dynamic>) {
          final data = Map<String, dynamic>.from(userData);
          data['role'] = 'merchant';
          _currentUser = UserModel.fromJson(data);
        } else {
          _currentUser = UserModel(
            id: '1',
            name: fullName,
            email: email,
            phone: phone,
            role: 'merchant',
          );
        }

        _isStaff = false;

        await TokenStorage.saveSession(
          token: token.toString(),
          user: _currentUser?.toJson(),
        );

        _currentShop = null;
        await TokenStorage.removeShop();

        fetchShopDetails();
        fetchUserProfile();
        notifyListeners();
        return true;
      }
      return true;
    }

    setError(response.error ?? 'Registration failed. Please check details.');
    return false;
  }

  Future<bool> staffLogin(String pin) async {
    setLoading(true);
    clearError();

    final response = await _repo.staffLogin(pin: pin);
    setLoading(false);

    if (response.success && response.data != null) {
      final payload = response.data!;
      final token = payload['access_token'] ?? payload['token'] ?? 'staff_token_${DateTime.now().millisecondsSinceEpoch}';
      _isStaff = true;
      _currentUser = UserModel(
        id: payload['staff_id'] ?? 'staff_1',
        name: payload['staff_name'] ?? 'Cashier Staff',
        email: 'staff@shopsilo.in',
        role: 'staff',
      );

      await TokenStorage.saveSession(
        token: token.toString(),
        user: _currentUser?.toJson(),
      );
      await TokenStorage.saveStaff(payload);

      fetchShopDetails();
      notifyListeners();
      return true;
    }

    setError(response.error ?? 'Invalid 4-digit PIN');
    return false;
  }

  Future<void> fetchShopDetails({bool silent = false}) async {
    final response = await _repo.getMyShop();
    if (response.success && response.data != null && response.data!.id.toString().isNotEmpty) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());

      final idx = _managedShops.indexWhere((s) => s.id == _currentShop!.id);
      if (idx >= 0) {
        _managedShops[idx] = _currentShop!;
      } else {
        _managedShops.insert(0, _currentShop!);
      }
      await LocalCacheService.saveManagedShops(_managedShops);
      notifyListeners();
    } else {
      // Backend returned 404 or empty: This user has not registered a store yet
      _currentShop = null;
      await TokenStorage.removeShop();
      notifyListeners();
    }
  }

  /// Switch active store / outlet in 0ms with instant cache invalidation
  Future<bool> switchShop(String shopId) async {
    final target = _managedShops.firstWhere(
      (s) => s.id == shopId,
      orElse: () => ShopModel(id: '', name: '', slug: '', phone: '', category: ''),
    );
    if (target.id.isEmpty) return false;

    _currentShop = target;
    await TokenStorage.saveShop(_currentShop!.toJson());
    notifyListeners();

    // Broadcast cache invalidation so all screens reload for the switched store
    AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
    return true;
  }

  /// Register a new branch / store outlet under the same merchant account
  Future<bool> registerBranchStore({
    required String name,
    required String address,
    String category = 'General Store',
    String phone = '',
  }) async {
    setLoading(true);
    clearError();

    final payload = {
      'name': name.trim(),
      'address': address.trim(),
      'category': category,
      'phone': phone.isNotEmpty ? phone : (_currentUser?.phone ?? ''),
    };

    final response = await _repo.createShop(payload);
    setLoading(false);

    if (response.success && response.data != null && response.data!.id.toString().isNotEmpty) {
      final newBranch = response.data!;
      _managedShops.removeWhere((s) => s.id == newBranch.id);
      _managedShops.add(newBranch);
      _currentShop = newBranch;

      await TokenStorage.saveShop(_currentShop!.toJson());
      await LocalCacheService.saveManagedShops(_managedShops);
      notifyListeners();

      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    } else {
      // Offline fallback: optimistically create local branch and enqueue background sync
      final branchId = 'branch_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticBranch = ShopModel(
        id: branchId,
        name: name.trim(),
        slug: name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        address: address.trim(),
        category: category,
        phone: phone.isNotEmpty ? phone : (_currentUser?.phone ?? ''),
      );

      _managedShops.removeWhere((s) => s.id == optimisticBranch.id);
      _managedShops.add(optimisticBranch);
      _currentShop = optimisticBranch;

      await TokenStorage.saveShop(_currentShop!.toJson());
      await LocalCacheService.saveManagedShops(_managedShops);
      notifyListeners();

      await OfflineSyncService.instance.enqueue(
        action: SyncActionType.stockAdjust,
        endpoint: ApiConstants.createShop,
        method: 'POST',
        payload: payload,
        title: 'New Branch: ${name.trim()}',
      );

      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    }
  }

  Future<bool> updateShop(Map<String, dynamic> data) async {
    // If shop does not exist yet in database, route directly to createShop!
    if (_currentShop == null || _currentShop!.id.toString().isEmpty) {
      return await createShop(data);
    }

    final original = _currentShop;
    if (_currentShop != null) {
      // Optimistic 0ms local update
      _currentShop = _currentShop!.copyWith(
        name: data['name'] ?? _currentShop!.name,
        description: data['description'] ?? _currentShop!.description,
        address: data['address'] ?? _currentShop!.address,
        city: data['city'] ?? _currentShop!.city,
        pincode: data['pincode'] ?? _currentShop!.pincode,
        latitude: data['latitude'] != null ? (data['latitude'] is num ? (data['latitude'] as num).toDouble() : double.tryParse(data['latitude'].toString())) : _currentShop!.latitude,
        longitude: data['longitude'] != null ? (data['longitude'] is num ? (data['longitude'] as num).toDouble() : double.tryParse(data['longitude'].toString())) : _currentShop!.longitude,
        googleMapsUrl: data['google_maps_url'] ?? _currentShop!.googleMapsUrl,
        phone: data['phone'] ?? _currentShop!.phone,
        whatsappNumber: data['whatsapp_number'] ?? _currentShop!.whatsappNumber,
        category: data['category'] ?? _currentShop!.category,
        upiId: data['upi_id'] ?? _currentShop!.upiId,
        openingTime: data['opening_time'] ?? _currentShop!.openingTime,
        closingTime: data['closing_time'] ?? _currentShop!.closingTime,
        weeklyOff: data['weekly_off'] ?? _currentShop!.weeklyOff,
        isOpen: data['is_open'] ?? _currentShop!.isOpen,
        logoUrl: data['logo_url'] ?? _currentShop!.logoUrl,
        banners: data['banners'] != null ? List<String>.from(data['banners']) : _currentShop!.banners,
      );
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
    }

    setLoading(true);
    clearError();
    final response = await _repo.updateShop(data);
    setLoading(false);
    if (response.success && response.data != null) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    } else {
      // If error indicates shop not found / not registered yet, automatically fallback to createShop!
      final errMsg = (response.error ?? '').toLowerCase();
      if (errMsg.contains('not found') ||
          errMsg.contains('not registered') ||
          errMsg.contains('नहीं मिला') ||
          errMsg.contains('404')) {
        return await createShop(data);
      }
      if (original != null) {
        _currentShop = original;
        await TokenStorage.saveShop(_currentShop!.toJson());
        notifyListeners();
      }
      setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'दुकान विवरण अपडेट करने में विफल' : 'Failed to update store details'));
      return false;
    }
  }

  Future<bool> createShop(Map<String, dynamic> data) async {
    setLoading(true);
    clearError();
    final response = await _repo.createShop(data);
    setLoading(false);
    if (response.success && response.data != null && response.data!.id.toString().isNotEmpty) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(role: 'merchant');
        await TokenStorage.saveUser(_currentUser!.toJson());
      }
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    }
    setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'दुकान बनाने में विफल' : 'Failed to create store'));
    return false;
  }

  Future<bool> updateUserProfile({
    required String fullName,
    String? phone,
  }) async {
    setLoading(true);
    clearError();
    final response = await _repo.updateProfile(fullName: fullName, phone: phone);
    setLoading(false);
    if (response.success && response.data != null) {
      final userMap = response.data!['user'] ?? response.data!;
      if (userMap is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(userMap);
      } else if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: fullName.trim(),
          email: _currentUser!.email,
          phone: phone?.trim() ?? _currentUser!.phone,
          role: _currentUser!.role,
          createdAt: _currentUser!.createdAt,
        );
      }
      if (_currentUser != null) {
        await TokenStorage.saveUser(_currentUser!.toJson());
      }
      notifyListeners();
      return true;
    }
    setError(response.error ?? 'Failed to update owner profile');
    return false;
  }

  Future<void> fetchUserProfile({bool silent = false}) async {
    final response = await _repo.getProfile();
    if (response.success && response.data != null) {
      final userMap = response.data!['user'] ?? response.data!;
      if (userMap is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(userMap);
        await TokenStorage.saveUser(_currentUser!.toJson());
        notifyListeners();
      }
    }
  }

  Future<bool> uploadUserAvatar(XFile file) async {
    setLoading(true);
    clearError();
    final response = await _repo.uploadUserAvatar(file);
    setLoading(false);
    if (response.success && response.data != null) {
      final avatarUrl = response.data!['avatar_url']?.toString();
      if (avatarUrl != null && avatarUrl.isNotEmpty && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
        await TokenStorage.saveUser(_currentUser!.toJson());
      }
      await fetchUserProfile();
      notifyListeners();
      return true;
    }
    setError(response.error ?? 'Failed to upload profile picture');
    return false;
  }

  Future<bool> uploadShopLogo(XFile file) async {
    setLoading(true);
    clearError();
    final response = await _repo.uploadShopLogo(file);
    setLoading(false);
    if (response.success && response.data != null) {
      final logoUrl = response.data!['logo_url']?.toString();
      if (logoUrl != null && logoUrl.isNotEmpty && _currentShop != null) {
        _currentShop = _currentShop!.copyWith(logoUrl: logoUrl);
        await TokenStorage.saveShop(_currentShop!.toJson());
      }
      await fetchShopDetails();
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    }
    setError(response.error ?? 'Failed to upload shop logo');
    return false;
  }

  Future<List<String>> uploadShopBanners(List<XFile> files) async {
    if (files.isEmpty) return [];
    setLoading(true);
    clearError();
    final response = await _repo.uploadShopBanners(files);
    setLoading(false);
    if (response.success && response.data != null) {
      if (_currentShop != null) {
        _currentShop = _currentShop!.copyWith(banners: response.data!);
        await TokenStorage.saveShop(_currentShop!.toJson());
      }
      await fetchShopDetails();
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return response.data!;
    }
    setError(response.error ?? 'Failed to upload shop banner images');
    return [];
  }

  Future<bool> toggleShopStatus(bool isOpen) async {
    if (_currentShop == null) return false;

    // Optimistic update
    final prevStatus = _currentShop!.isOpen;
    _currentShop = _currentShop!.copyWith(isOpen: isOpen);
    notifyListeners();

    final response = await _repo.toggleShopStatus(isOpen);
    if (response.success && response.data != null) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.shopProfileUpdated);
      return true;
    } else {
      // Revert if failed
      _currentShop = _currentShop!.copyWith(isOpen: prevStatus);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteShop() async {
    setLoading(true);
    clearError();
    final response = await _repo.deleteShop();
    setLoading(false);
    if (response.success) {
      if (_currentShop != null) {
        _currentShop = _currentShop!.copyWith(status: 'deleted', isOpen: false);
        await TokenStorage.saveShop(_currentShop!.toJson());
      }
      notifyListeners();
      return true;
    }
    setError(response.error ?? 'Failed to deactivate store');
    return false;
  }

  Future<bool> restoreShop() async {
    setLoading(true);
    clearError();
    final response = await _repo.restoreShop();
    setLoading(false);
    if (response.success && response.data != null) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
      return true;
    }
    setError(response.error ?? 'Failed to restore store');
    return false;
  }

  Future<void> logout() async {
    try {
      CounterWebSocketService.instance.disconnect();
    } catch (_) {}
    await LocalCacheService.clearCache();
    await TokenStorage.clearSession();
    _currentUser = null;
    _currentShop = null;
    _isStaff = false;
    AppEventBus().emit(AppCacheEventType.authLogout);
    notifyListeners();
  }
}
