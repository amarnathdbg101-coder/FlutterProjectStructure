import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/dashboard/models/shop_model.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import '../../features/products/models/product_model.dart';
import '../../features/khata/models/khata_model.dart';
import '../../features/procurement/models/procurement_model.dart';
import '../../features/analytics/models/analytics_model.dart';
import '../../features/expenses/models/expense_model.dart';
import '../../features/offers/models/offer_model.dart';
import '../../features/pos/models/pos_model.dart';
import '../../features/reservations/models/reservation_model.dart';
import 'token_storage.dart';

/// Centralized High-Performance Local Cache Engine for ShopSilo.
/// Ensures 0ms instant load times by persisting catalog products,
/// store details, dashboard metrics, and offline state to device storage.
class LocalCacheService {
  static const String _keyProducts = 'shopsilo_cache_products';
  static const String _keyProductsTime = 'shopsilo_cache_products_time';
  static const String _keyDashboardStats = 'shopsilo_cache_dash_stats';
  static const String _keyDashboardStatsTime = 'shopsilo_cache_dash_stats_time';
  static const String _keyReservations = 'shopsilo_cache_reservations';
  static const String _keyReservationsTime = 'shopsilo_cache_reservations_time';

  static SharedPreferences? _prefs;

  // In-memory 0ms instant cache stores for Flutter Web & Mobile
  static List<ProductModel>? _memoryProducts;
  static List<KhataCustomerModel>? _memoryKhataCustomers;
  static List<ProcurementItemModel>? _memoryProcurementItems;
  static List<ExpenseModel>? _memoryExpenses;
  static List<OfferModel>? _memoryOffers;
  static List<SaleModel>? _memorySalesHistory;
  static List<ReservationModel>? _memoryReservations;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ==========================================
  // 1. PRODUCTS CATALOG PERSISTENCE (0ms Load)
  // ==========================================

  /// Save full products list to device local storage and in-memory cache
  static Future<void> saveProducts(List<ProductModel> products) async {
    try {
      _memoryProducts = List<ProductModel>.from(products);
      await init();
      final listJson = jsonEncode(products.map((p) => p.toJson()).toList());
      await _prefs!.setString(_keyProducts, listJson);
      await _prefs!.setInt(_keyProductsTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving products to local storage: $e');
    }
  }

  /// Retrieve products synchronously from local storage for 0ms startup
  static List<ProductModel> getProducts() {
    if (_memoryProducts != null && _memoryProducts!.isNotEmpty) {
      return List<ProductModel>.from(_memoryProducts!);
    }
    try {
      final raw = _prefs?.getString(_keyProducts);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryProducts = List<ProductModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading products from local storage: $e');
    }
    return [];
  }

  /// Optimistically insert or update a single product in local cache
  static Future<void> saveSingleProduct(ProductModel product) async {
    try {
      final current = getProducts();
      final index = current.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        current[index] = product;
      } else {
        current.insert(0, product);
      }
      await saveProducts(current);
    } catch (e) {
      debugPrint('[LocalCacheService] Error updating single product cache: $e');
    }
  }

  /// Optimistically remove a product from local cache
  static Future<void> removeProduct(dynamic productId) async {
    try {
      final current = getProducts();
      current.removeWhere((p) => p.id.toString() == productId.toString());
      await saveProducts(current);
    } catch (e) {
      debugPrint('[LocalCacheService] Error deleting single product cache: $e');
    }
  }

  // ==========================================
  // 2. STORE DETAILS PERSISTENCE
  // ==========================================

  /// Save shop model to local cache
  static Future<void> saveShop(ShopModel shop) async {
    await TokenStorage.saveShop(shop.toJson());
  }

  /// Get cached shop model
  static ShopModel? getShop() {
    final map = TokenStorage.getShop();
    if (map != null) {
      try {
        return ShopModel.fromJson(map);
      } catch (e) {
        debugPrint('[LocalCacheService] Error deserializing shop model: $e');
      }
    }
    return null;
  }

  // ==========================================
  // 3. DASHBOARD METRICS PERSISTENCE
  // ==========================================

  /// Save aggregated dashboard stats to local cache
  static Future<void> saveDashboardStats(DashboardStats stats) async {
    try {
      await init();
      await _prefs!.setString(_keyDashboardStats, jsonEncode(stats.toJson()));
      await _prefs!.setInt(_keyDashboardStatsTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving dashboard stats: $e');
    }
  }

  /// Retrieve cached dashboard stats for 0ms initial dashboard render
  static DashboardStats? getDashboardStats() {
    try {
      final raw = _prefs?.getString(_keyDashboardStats);
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return DashboardStats.fromJson(map);
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading dashboard stats: $e');
    }
    return null;
  }

  // ==========================================
  // 4. KHATA & CUSTOMER LEDGER PERSISTENCE
  // ==========================================
  static const String _keyKhataCustomers = 'shopsilo_cache_khata_customers';
  static const String _keyKhataCustomersTime = 'shopsilo_cache_khata_customers_time';
  static const String _keyKhataSummary = 'shopsilo_cache_khata_summary';

  /// Save Khata customers list to device local storage
  static Future<void> saveKhataCustomers(List<KhataCustomerModel> customers) async {
    try {
      _memoryKhataCustomers = List<KhataCustomerModel>.from(customers);
      await init();
      final listJson = jsonEncode(customers.map((c) => c.toJson()).toList());
      await _prefs!.setString(_keyKhataCustomers, listJson);
      await _prefs!.setInt(_keyKhataCustomersTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving khata customers: $e');
    }
  }

  /// Retrieve Khata customers synchronously from local storage for 0ms startup
  static List<KhataCustomerModel> getKhataCustomers() {
    if (_memoryKhataCustomers != null && _memoryKhataCustomers!.isNotEmpty) {
      return List<KhataCustomerModel>.from(_memoryKhataCustomers!);
    }
    try {
      final raw = _prefs?.getString(_keyKhataCustomers);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => KhataCustomerModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryKhataCustomers = List<KhataCustomerModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading khata customers: $e');
    }
    return [];
  }

  /// Save aggregated khata summary to local cache
  static Future<void> saveKhataSummary(KhataSummaryModel summary) async {
    try {
      await init();
      await _prefs!.setString(_keyKhataSummary, jsonEncode(summary.toJson()));
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving khata summary: $e');
    }
  }

  /// Retrieve cached khata summary
  static KhataSummaryModel? getKhataSummary() {
    try {
      final raw = _prefs?.getString(_keyKhataSummary);
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return KhataSummaryModel.fromJson(map);
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading khata summary: $e');
    }
    return null;
  }

  // ==========================================
  // 5. MANDI PROCUREMENT PERSISTENCE
  // ==========================================
  static const String _keyProcurement = 'shopsilo_cache_procurement';

  /// Save Mandi procurement items list to device local storage
  static Future<void> saveProcurementItems(List<ProcurementItemModel> items) async {
    try {
      _memoryProcurementItems = List<ProcurementItemModel>.from(items);
      await init();
      final listJson = jsonEncode(items.map((i) => i.toJson()).toList());
      await _prefs!.setString(_keyProcurement, listJson);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving procurement items: $e');
    }
  }

  /// Retrieve Mandi procurement items synchronously from local storage for 0ms startup
  static List<ProcurementItemModel> getProcurementItems() {
    if (_memoryProcurementItems != null && _memoryProcurementItems!.isNotEmpty) {
      return List<ProcurementItemModel>.from(_memoryProcurementItems!);
    }
    try {
      final raw = _prefs?.getString(_keyProcurement);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => ProcurementItemModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryProcurementItems = List<ProcurementItemModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading procurement items: $e');
    }
    return [];
  }

  // ==========================================
  // 6. MUNAFA & ANALYTICS PERSISTENCE
  // ==========================================
  static const String _keyAnalytics = 'shopsilo_cache_analytics';

  /// Save Analytics model to local cache
  static Future<void> saveAnalytics(AnalyticsModel analytics) async {
    try {
      await init();
      await _prefs!.setString(_keyAnalytics, jsonEncode(analytics.toJson()));
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving analytics: $e');
    }
  }

  /// Retrieve cached Analytics model
  static AnalyticsModel? getAnalytics() {
    try {
      final raw = _prefs?.getString(_keyAnalytics);
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return AnalyticsModel.fromJson(map);
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading analytics: $e');
    }
    return null;
  }

  // ==========================================
  // 7. EXPENSES PERSISTENCE
  // ==========================================
  static const String _keyExpenses = 'shopsilo_cache_expenses';

  /// Save Expenses list to device local storage
  static Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    try {
      _memoryExpenses = List<ExpenseModel>.from(expenses);
      await init();
      final listJson = jsonEncode(expenses.map((e) => e.toJson()).toList());
      await _prefs!.setString(_keyExpenses, listJson);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving expenses: $e');
    }
  }

  /// Retrieve cached Expenses list synchronously
  static List<ExpenseModel> getExpenses() {
    if (_memoryExpenses != null && _memoryExpenses!.isNotEmpty) {
      return List<ExpenseModel>.from(_memoryExpenses!);
    }
    try {
      final raw = _prefs?.getString(_keyExpenses);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => ExpenseModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryExpenses = List<ExpenseModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading expenses: $e');
    }
    return [];
  }

  // ==========================================
  // 8. OFFERS & PROMOTIONS PERSISTENCE
  // ==========================================
  static const String _keyOffers = 'shopsilo_cache_offers';

  /// Save Offers list to device local storage
  static Future<void> saveOffers(List<OfferModel> offers) async {
    try {
      _memoryOffers = List<OfferModel>.from(offers);
      await init();
      final listJson = jsonEncode(offers.map((o) => o.toJson()).toList());
      await _prefs!.setString(_keyOffers, listJson);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving offers: $e');
    }
  }

  /// Retrieve cached Offers list
  static List<OfferModel> getOffers() {
    if (_memoryOffers != null && _memoryOffers!.isNotEmpty) {
      return List<OfferModel>.from(_memoryOffers!);
    }
    try {
      final raw = _prefs?.getString(_keyOffers);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => OfferModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryOffers = List<OfferModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading offers: $e');
    }
    return [];
  }

  // ==========================================
  // 9. TODAY'S 24-HOUR SALES PERSISTENCE
  // ==========================================
  static const String _keySalesHistory = 'shopsilo_cache_sales_history';

  /// Save completed POS sale to device storage history
  static Future<void> saveCompletedSale(SaleModel sale) async {
    try {
      await init();
      final current = getSalesHistory();
      current.insert(0, sale);
      // Keep sales from last 48 hours max
      final cutoff = DateTime.now().subtract(const Duration(hours: 48));
      final filtered = current.where((s) => s.createdAt.isAfter(cutoff)).toList();
      final listJson = jsonEncode(filtered.map((s) => s.toJson()).toList());
      await _prefs!.setString(_keySalesHistory, listJson);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving sale to history: $e');
    }
  }

  /// Get sales history
  static List<SaleModel> getSalesHistory() {
    if (_memorySalesHistory != null && _memorySalesHistory!.isNotEmpty) {
      return List<SaleModel>.from(_memorySalesHistory!);
    }
    try {
      final raw = _prefs?.getString(_keySalesHistory);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => SaleModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memorySalesHistory = List<SaleModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading sales history: $e');
    }
    return [];
  }

  /// Save full list of sales fetched from backend
  static Future<void> saveSalesList(List<SaleModel> sales) async {
    try {
      _memorySalesHistory = List<SaleModel>.from(sales);
      await init();
      final listJson = jsonEncode(sales.map((s) => s.toJson()).toList());
      await _prefs!.setString(_keySalesHistory, listJson);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving sales list: $e');
    }
  }

  /// Get sales completed within the last 24 hours
  static List<SaleModel> get24HourSales() {
    final history = getSalesHistory();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return history.where((s) => s.createdAt.isAfter(cutoff)).toList();
  }

  // ==========================================
  // 10. RESERVATIONS & PICKUP ORDERS PERSISTENCE
  // ==========================================

  /// Save Reservations list to device local storage and in-memory cache
  static Future<void> saveReservations(List<ReservationModel> reservations) async {
    try {
      _memoryReservations = List<ReservationModel>.from(reservations);
      await init();
      final listJson = jsonEncode(reservations.map((r) => r.toJson()).toList());
      await _prefs!.setString(_keyReservations, listJson);
      await _prefs!.setInt(_keyReservationsTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[LocalCacheService] Error saving reservations to cache: $e');
    }
  }

  /// Retrieve Reservations list synchronously from cache for 0ms startup
  static List<ReservationModel> getReservations() {
    if (_memoryReservations != null && _memoryReservations!.isNotEmpty) {
      return List<ReservationModel>.from(_memoryReservations!);
    }
    try {
      final raw = _prefs?.getString(_keyReservations);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((item) => ReservationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) {
          _memoryReservations = List<ReservationModel>.from(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error reading reservations from cache: $e');
    }
    return [];
  }

  // ==========================================
  // 11. CACHE FRESHNESS & TARGETED INVALIDATION
  // ==========================================

  /// Check whether cached data is fresh within the threshold
  static bool isCacheFresh(String key, {Duration maxAge = const Duration(minutes: 5)}) {
    final timestamp = _prefs?.getInt(key);
    if (timestamp == null) return false;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cachedAt) < maxAge;
  }

  static bool isProductsCacheFresh({Duration maxAge = const Duration(minutes: 5)}) {
    return isCacheFresh(_keyProductsTime, maxAge: maxAge);
  }

  static bool isReservationsCacheFresh({Duration maxAge = const Duration(minutes: 5)}) {
    return isCacheFresh(_keyReservationsTime, maxAge: maxAge);
  }

  static bool isKhataCacheFresh({Duration maxAge = const Duration(minutes: 5)}) {
    return isCacheFresh(_keyKhataCustomersTime, maxAge: maxAge);
  }

  static bool isDashboardStatsFresh({Duration maxAge = const Duration(minutes: 5)}) {
    return isCacheFresh(_keyDashboardStatsTime, maxAge: maxAge);
  }

  /// Invalidate products catalog cache
  static void invalidateProducts() {
    _memoryProducts = null;
    _prefs?.remove(_keyProductsTime);
  }

  /// Invalidate dashboard stats cache
  static void invalidateDashboardStats() {
    _prefs?.remove(_keyDashboardStats);
    _prefs?.remove(_keyDashboardStatsTime);
  }

  /// Invalidate khata customers and summary cache
  static void invalidateKhata() {
    _memoryKhataCustomers = null;
    _prefs?.remove(_keyKhataCustomers);
    _prefs?.remove(_keyKhataCustomersTime);
    _prefs?.remove(_keyKhataSummary);
  }

  /// Invalidate expenses cache
  static void invalidateExpenses() {
    _memoryExpenses = null;
    _prefs?.remove(_keyExpenses);
  }

  /// Invalidate offers cache
  static void invalidateOffers() {
    _memoryOffers = null;
    _prefs?.remove(_keyOffers);
  }

  /// Invalidate reservations cache
  static void invalidateReservations() {
    _memoryReservations = null;
    _prefs?.remove(_keyReservations);
    _prefs?.remove(_keyReservationsTime);
  }

  /// Invalidate analytics cache
  static void invalidateAnalytics() {
    _prefs?.remove(_keyAnalytics);
  }

  /// Wipe ALL caches (in-memory & persistent storage) on user logout
  static Future<void> clearCache() async {
    // 1. Wipe all in-memory static caches immediately
    _memoryProducts = null;
    _memoryKhataCustomers = null;
    _memoryProcurementItems = null;
    _memoryExpenses = null;
    _memoryOffers = null;
    _memorySalesHistory = null;
    _memoryReservations = null;

    // 2. Wipe all persistent storage keys from device
    await init();
    if (_prefs != null) {
      await _prefs!.remove(_keyProducts);
      await _prefs!.remove(_keyProductsTime);
      await _prefs!.remove(_keyDashboardStats);
      await _prefs!.remove(_keyDashboardStatsTime);
      await _prefs!.remove(_keyKhataCustomers);
      await _prefs!.remove(_keyKhataCustomersTime);
      await _prefs!.remove(_keyKhataSummary);
      await _prefs!.remove(_keyProcurement);
      await _prefs!.remove(_keyAnalytics);
      await _prefs!.remove(_keyExpenses);
      await _prefs!.remove(_keyOffers);
      await _prefs!.remove(_keySalesHistory);
      await _prefs!.remove(_keyReservations);
      await _prefs!.remove(_keyReservationsTime);
    }
  }
}
