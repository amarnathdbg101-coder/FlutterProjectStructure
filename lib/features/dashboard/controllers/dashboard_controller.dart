import 'dart:async';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../pos/models/pos_model.dart';
import '../repositories/dashboard_repository.dart';

/// High-performance Dashboard Controller with 0ms load speed.
/// Hydrates metrics immediately from local cache, revalidates silently in background,
/// and reacts instantly to all system mutations via Event-Driven Cache Invalidation.
class DashboardController extends BaseController {
  final DashboardRepository _repo = DashboardRepository();

  DashboardStats _stats = DashboardStats();
  DashboardStats get stats => _stats;

  String? _qrCodeUrl;
  String? get qrCodeUrl => _qrCodeUrl;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  StreamSubscription<AppCacheEvent>? _posSub;
  StreamSubscription<AppCacheEvent>? _prodSub;
  StreamSubscription<AppCacheEvent>? _invSub;
  StreamSubscription<AppCacheEvent>? _khataSub;
  StreamSubscription<AppCacheEvent>? _expenseSub;
  StreamSubscription<AppCacheEvent>? _resSub;
  StreamSubscription<AppCacheEvent>? _shopProfileSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  DashboardController() {
    _hydrateFromLocalCache();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    final bus = AppEventBus();

    _posSub = bus.on(AppCacheEventType.posSaleCompleted, (event) {
      if (event.payload is SaleModel) {
        final sale = event.payload as SaleModel;
        final isCredit = sale.paymentMethod == 'khata' || sale.paymentMethod == 'credit';
        _stats = _stats.copyWith(
          todaySales: _stats.todaySales + sale.totalAmount,
          salesCount: _stats.salesCount + 1,
          totalUdhar: isCredit ? _stats.totalUdhar + sale.totalAmount : _stats.totalUdhar,
        );
        LocalCacheService.saveDashboardStats(_stats);
        notifyListeners();
      }
      fetchDashboardData(silent: true);
    });
    _prodSub = bus.on(AppCacheEventType.productsMutated, (_) => fetchDashboardData(silent: true));
    _invSub = bus.on(AppCacheEventType.inventoryMutated, (_) => fetchDashboardData(silent: true));
    _khataSub = bus.on(AppCacheEventType.khataMutated, (_) => fetchDashboardData(silent: true));
    _expenseSub = bus.on(AppCacheEventType.expenseMutated, (_) => fetchDashboardData(silent: true));
    _resSub = bus.on(AppCacheEventType.reservationMutated, (_) => fetchDashboardData(silent: true));
    _shopProfileSub = bus.on(AppCacheEventType.shopProfileUpdated, (_) => fetchDashboardData(silent: true));

    _logoutSub = bus.on(AppCacheEventType.authLogout, (_) {
      _stats = DashboardStats();
      _qrCodeUrl = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _prodSub?.cancel();
    _invSub?.cancel();
    _khataSub?.cancel();
    _expenseSub?.cancel();
    _resSub?.cancel();
    _shopProfileSub?.cancel();
    _logoutSub?.cancel();
    super.dispose();
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
