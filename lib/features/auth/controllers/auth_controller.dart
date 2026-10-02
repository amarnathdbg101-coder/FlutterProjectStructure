import '../../../core/network/base_controller.dart';
import '../../../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthController extends BaseController {
  final AuthRepository _repo = AuthRepository();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => TokenStorage.hasToken();

  Future<bool> login(String email, String password) async {
    setLoading(true);
    clearError();

    final response = await _repo.login(email: email, password: password);
    setLoading(false);

    if (response.success && response.data != null) {
      final token = response.data!['token'] ?? response.data!['access_token'];
      final userData = response.data!['user'];

      if (token != null) {
        String? userId;
        String? name;

        if (userData != null && userData is Map<String, dynamic>) {
          _currentUser = UserModel.fromJson(userData);
          userId = _currentUser!.id.toString();
          name = _currentUser!.name;
        }

        await TokenStorage.saveSession(
          token: token.toString(),
          userId: userId,
          email: email,
          name: name,
        );

        notifyListeners();
        return true;
      }
    }

    setError(response.error ?? 'Invalid email or password');
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    setLoading(true);
    clearError();

    final response = await _repo.register(name: name, email: email, password: password);
    setLoading(false);

    if (response.success) {
      return true;
    }

    setError(response.error ?? 'Registration failed. Try again.');
    return false;
  }

  Future<void> fetchProfile() async {
    if (!isAuthenticated) return;

    final response = await _repo.getProfile();
    if (response.success && response.data != null) {
      _currentUser = response.data;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearSession();
    _currentUser = null;
    notifyListeners();
  }
}
