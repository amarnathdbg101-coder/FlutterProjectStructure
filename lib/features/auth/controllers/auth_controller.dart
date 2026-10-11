import 'package:image_picker/image_picker.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/counter_websocket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../dashboard/models/shop_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthController extends BaseController {
  final AuthRepository _repo = AuthRepository();

  UserModel? _currentUser;
  ShopModel? _currentShop;
  bool _isStaff = false;

  UserModel? get currentUser => _currentUser;
  ShopModel? get currentShop => _currentShop;
  bool get isStaff => _isStaff;
  bool get isAuthenticated => TokenStorage.hasToken();

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

        // Fetch Shop details and user profile in background
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
    if (response.success && response.data != null) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
    }
  }

  Future<bool> updateShop(Map<String, dynamic> data) async {
    final original = _currentShop;
    if (_currentShop != null) {
      // Optimistic 0ms local update
      _currentShop = _currentShop!.copyWith(
        name: data['name'] ?? _currentShop!.name,
        description: data['description'] ?? _currentShop!.description,
        address: data['address'] ?? _currentShop!.address,
        city: data['city'] ?? _currentShop!.city,
        pincode: data['pincode'] ?? _currentShop!.pincode,
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
      return true;
    } else {
      if (original != null) {
        _currentShop = original;
        await TokenStorage.saveShop(_currentShop!.toJson());
        notifyListeners();
      }
      setError(response.error ?? 'Failed to update store details');
      return false;
    }
  }

  Future<bool> createShop(Map<String, dynamic> data) async {
    setLoading(true);
    clearError();
    final response = await _repo.createShop(data);
    setLoading(false);
    if (response.success && response.data != null) {
      _currentShop = response.data;
      await TokenStorage.saveShop(_currentShop!.toJson());
      notifyListeners();
      return true;
    }
    setError(response.error ?? 'Failed to create store');
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
    if (response.success && response.data != null && response.data!.isNotEmpty) {
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
    await TokenStorage.clearSession();
    _currentUser = null;
    _currentShop = null;
    _isStaff = false;
    notifyListeners();
  }
}
