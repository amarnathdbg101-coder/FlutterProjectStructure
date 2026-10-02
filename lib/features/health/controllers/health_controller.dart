import '../../../core/network/base_controller.dart';
import '../repositories/health_repository.dart';

class HealthController extends BaseController {
  final HealthRepository _repo = HealthRepository();

  bool _isConnected = false;
  String _databaseStatus = 'Unknown';
  String _uptime = '';

  bool get isConnected => _isConnected;
  bool get isChecking => isLoading;
  String get databaseStatus => _databaseStatus;
  String get uptime => _uptime;

  Future<void> checkConnection() async {
    setLoading(true);
    clearError();

    final res = await _repo.checkHealth();
    setLoading(false);

    if (res.success && res.data != null) {
      _isConnected = true;
      _databaseStatus = res.data!['database']?.toString() ?? 'Connected';
      _uptime = res.data!['uptime']?.toString() ?? '';
    } else {
      _isConnected = false;
      _databaseStatus = 'Unreachable';
      setError(res.error ?? 'Could not reach Go backend');
    }
    notifyListeners();
  }
}
