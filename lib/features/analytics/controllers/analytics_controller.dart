import 'dart:async';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../products/repositories/product_repository.dart';
import '../models/analytics_model.dart';

/// High-performance, 0ms Stale-While-Revalidate Analytics & Profit Controller.
class AnalyticsController extends BaseController {
  final ProductRepository _productRepo = ProductRepository();
  AnalyticsModel? _analytics;

  AnalyticsModel? get analytics => _analytics;

  StreamSubscription<AppCacheEvent>? _posSub;
  StreamSubscription<AppCacheEvent>? _prodSub;
  StreamSubscription<AppCacheEvent>? _expenseSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  AnalyticsController() {
    _hydrateFromLocalCache();
    fetchAnalytics();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    final bus = AppEventBus();
    _posSub = bus.on(AppCacheEventType.posSaleCompleted, (_) => fetchAnalytics());
    _prodSub = bus.on(AppCacheEventType.productsMutated, (_) => fetchAnalytics());
    _expenseSub = bus.on(AppCacheEventType.expenseMutated, (_) => fetchAnalytics());

    _logoutSub = bus.on(AppCacheEventType.authLogout, (_) {
      _analytics = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _prodSub?.cancel();
    _expenseSub?.cancel();
    _logoutSub?.cancel();
    super.dispose();
  }

  void _hydrateFromLocalCache() {
    final cached = LocalCacheService.getAnalytics();
    if (cached != null) {
      _analytics = cached;
      notifyListeners();
    }
  }

  Future<void> fetchAnalytics() async {
    if (_analytics == null) {
      setLoading(true);
    }
    clearError();

    try {
      final profitRes = await _productRepo.getMonthlyProfit();
      final matrixRes = await _productRepo.getProductMatrix();

      setLoading(false);

      final combinedJson = <String, dynamic>{};

      if (profitRes.success && profitRes.data != null) {
        combinedJson.addAll(profitRes.data!);
      }

      if (matrixRes.success && matrixRes.data != null) {
        if (matrixRes.data!['best_profitable'] != null) {
          combinedJson['best_profitable'] = matrixRes.data!['best_profitable'];
        }
        if (matrixRes.data!['top_products'] != null) {
          combinedJson['best_profitable'] = matrixRes.data!['top_products'];
        }
        if (matrixRes.data!['old_dead_stock'] != null) {
          combinedJson['old_dead_stock'] = matrixRes.data!['old_dead_stock'];
        }
        if (matrixRes.data!['slow_moving'] != null) {
          combinedJson['old_dead_stock'] = matrixRes.data!['slow_moving'];
        }
      }

      if (combinedJson.isNotEmpty) {
        _analytics = AnalyticsModel.fromJson(combinedJson);
        await LocalCacheService.saveAnalytics(_analytics!);
        notifyListeners();
        return;
      }
    } catch (_) {
      setLoading(false);
    }

    // Real Zero State when no data or offline cache exists (Zero Fake Data)
    if (_analytics == null) {
      _analytics = AnalyticsModel(
        totalRevenue: 0.0,
        totalCost: 0.0,
        totalExpenses: 0.0,
        netPocketProfit: 0.0,
        averageMarginPct: 0.0,
        totalSalesCount: 0,
        bestProfitable: [],
        deadStock: [],
      );
      notifyListeners();
    }
  }
}
