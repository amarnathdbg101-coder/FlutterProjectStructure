import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../repositories/dashboard_repository.dart';

/// High-performance Dashboard Controller with 0ms load speed.
/// Hydrates metrics immediately from local cache, revalidates silently in background.
class DashboardController extends BaseController {
  final DashboardRepository _repo = DashboardRepository();

  DashboardStats _stats = DashboardStats();
  DashboardStats get stats => _stats;

  String? _qrCodeUrl;
  String? get qrCodeUrl => _qrCodeUrl;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DashboardController() {
    _hydrateFromLocalCache();
  }

  void _hydrateFromLocalCache() {
    final cached = LocalCacheService.getDashboardStats();
    if (cached != null) {
      _stats = cached;
      notifyListeners();
    }
  }

  Future<void> fetchDashboardData({bool silent = false}) async {
    // Only show full loading if we have zero cached metrics
    if (!silent && _stats.todaySales == 0 && _stats.salesCount == 0 && _stats.totalUdhar == 0) {
      setLoading(true);
    } else {
      _isSyncing = true;
      notifyListeners();
    }

    clearError();

    final response = await _repo.getDashboardStats();

    setLoading(false);
    _isSyncing = false;

    if (response.success && response.data != null) {
      _stats = response.data!;
      await LocalCacheService.saveDashboardStats(_stats);
      notifyListeners();
    } else {
      if (!silent) {
        setError(response.error ?? 'Could not refresh dashboard stats');
      }
    }
  }

  Future<void> fetchQrCode() async {
    final response = await _repo.getShopQr();
    if (response.success && response.data != null) {
      _qrCodeUrl = response.data;
      notifyListeners();
    }
  }
}
