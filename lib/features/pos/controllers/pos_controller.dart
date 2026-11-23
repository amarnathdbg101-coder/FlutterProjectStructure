import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/audio_haptic_service.dart';
import '../../../core/services/counter_websocket_service.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../products/models/product_model.dart';
import '../../products/repositories/product_repository.dart';
import '../models/pos_model.dart';
import '../repositories/pos_repository.dart';
import '../repositories/pos_advanced_repository.dart';
import '../models/pos_features_model.dart';
import '../services/thermal_receipt_pdf_service.dart';
import '../services/esc_pos_service.dart';

class PosController extends BaseController {
  final PosRepository _repo;

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  // ⚡ In-Memory (RAM) O(1) Fast Lookup Index for Barcodes & SKUs
  final Map<String, ProductModel> _barcodeIndex = {};

  void _rebuildBarcodeIndex() {
    _barcodeIndex.clear();
    for (final p in _products) {
      final barcode = p.barcode.trim().toLowerCase();
      if (barcode.isNotEmpty) {
        _barcodeIndex[barcode] = p;
      }
      final sku = p.sku.trim().toLowerCase();
      if (sku.isNotEmpty && !_barcodeIndex.containsKey(sku)) {
        _barcodeIndex[sku] = p;
      }
    }
  }

  final List<PosCartItem> _cart = [];
  List<PosCartItem> get cart => List.unmodifiable(_cart);

  final List<PosHeldBill> _heldBills = [];
  List<PosHeldBill> get heldBills => List.unmodifiable(_heldBills);

  // --- Real-time Floor Assisted Selling & Parallel Active Baskets ---
  String _currentActiveToken = 'T-01';
  String get currentActiveToken => _currentActiveToken;

  List<PosParkedBill> _activeBaskets = [];
  List<PosParkedBill> get activeBaskets => List.unmodifiable(_activeBaskets);

  bool _isLoadingBaskets = false;
  bool get isLoadingBaskets => _isLoadingBaskets;
  bool _isCompletingSale = false;
  bool get isCompletingSale => _isCompletingSale;
  Future<void>? _catalogLoadInFlight;

  Timer? _autoSyncDebounce;
  bool _isSyncingToServer = false;
  StreamSubscription? _posParkedSub;

  String _customerPhone = '';
  String get customerPhone => _customerPhone;

  String _customerName = '';
  String get customerName => _customerName;

  String _paymentMethod = 'cash';
  String get paymentMethod => _paymentMethod;

  double _discount = 0.0;
  double get discount => _discount;

  double _cashTendered = 0.0;
  double get cashTendered => _cashTendered;

  SaleModel? _lastCompletedSale;
  SaleModel? get lastCompletedSale => _lastCompletedSale;

  // ⚡ Zero-Click Rush Hour Auto-Print Mode
  bool _autoPrintEnabled = false;
  bool get autoPrintEnabled => _autoPrintEnabled;

  /// Toggles Zero-Click auto-print mode and persists state across app sessions
  Future<void> toggleAutoPrint() async {
    _autoPrintEnabled = !_autoPrintEnabled;
    await LocalCacheService.setAutoPrintEnabled(_autoPrintEnabled);
    notifyListeners();
  }

  int get totalItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _cart.fold(0.0, (sum, item) => sum + item.total);

  double get grandTotal {
    final total = subtotal - _discount;
    return total > 0 ? total : 0.0;
  }

  double get changeDue {
    if (_paymentMethod != 'cash') return 0.0;
    final diff = _cashTendered - grandTotal;
    return diff > 0 ? diff : 0.0;
  }

  /// Total estimated cost price of items in active cart
  double get cartCostTotal {
    return _cart.fold(0.0, (sum, item) {
      final cp = item.product.costPrice;
      return sum + (cp > 0 ? (cp * item.quantity) : (item.product.price * 0.8 * item.quantity));
    });
  }

  /// Estimated gross profit on active cart
  double get cartGrossProfit {
    if (_cart.isEmpty) return 0.0;
    return grandTotal - cartCostTotal;
  }

  /// Estimated gross profit margin percentage on active cart
  double get cartProfitMarginPct {
    if (grandTotal <= 0 || _cart.isEmpty) return 0.0;
    return (cartGrossProfit / grandTotal) * 100;
  }

  /// Detects if current discount exceeds gross profit (Loss warning)
  bool get isDiscountLossWarning {
    if (_discount <= 0 || _cart.isEmpty) return false;
    final profitBeforeDiscount = subtotal - cartCostTotal;
    return _discount > profitBeforeDiscount;
  }

  /// Cash shortage when customer gives less than grand total in cash mode
  double get cashShortage {
    if (_paymentMethod != 'cash') return 0.0;
    if (_cashTendered <= 0) return 0.0;
    final diff = grandTotal - _cashTendered;
    return diff > 0 ? diff : 0.0;
  }

  double _splitCashAmount = 0.0;
  double get splitCashAmount => _splitCashAmount;

  double get splitUpiAmount {
    final diff = grandTotal - _splitCashAmount;
    return diff > 0 ? diff : 0.0;
  }

  void setSplitCashAmount(double val) {
    if (_isCompletingSale) return;
    if (!val.isFinite || val < 0 || val > grandTotal) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'नकद राशि बिल की कुल राशि से अधिक नहीं हो सकती'
            : 'Cash portion cannot exceed the bill total',
      );
      return;
    }
    _splitCashAmount = val;
    notifyListeners();
  }

  /// Generates dynamic, realistic cash tendered suggestions based on Indian currency denominations
  List<double> getSmartCashSuggestions() {
    final total = grandTotal;
    if (total <= 0) return [];

    final Set<double> suggestions = {};

    // 1. Exact amount
    suggestions.add(total);

    // 2. Next nearest Round 50
    final next50 = (total / 50).ceil() * 50.0;
    if (next50 > total) suggestions.add(next50);

    // 3. Next nearest Round 100
    final next100 = (total / 100).ceil() * 100.0;
    if (next100 > total) suggestions.add(next100);

    // 4. Standard Indian currency notes
    for (final note in [100.0, 200.0, 500.0, 1000.0, 2000.0]) {
      if (note > total) {
        suggestions.add(note);
      }
    }

    // 5. If total > 500, suggest next 500 steps
    if (total > 500) {
      final next500 = (total / 500).ceil() * 500.0;
      if (next500 > total) suggestions.add(next500);
      final nextNext500 = next500 + 500.0;
      if (nextNext500 > total) suggestions.add(nextNext500);
    }

    final list = suggestions.toList()..sort();
    return list.take(5).toList();
  }

  List<SaleModel> _serverSales = [];
  List<SaleModel> get serverSales => _serverSales;

  // --- High-Performance Memoized Sales & P&L Metrics Cache ---
  PosSalesMetrics? _cached24hMetrics;
  PosSalesMetrics? _cached10dMetrics;

  /// Invalidates in-memory metrics cache on new sale, cancellation, or backend sync
  void invalidateSalesMetricsCache() {
    _cached24hMetrics = null;
    _cached10dMetrics = null;
  }

  /// High-performance, single-pass aggregated P&L and Sales metrics.
  /// Memoized in-memory so UI rebuilds cost 0ms CPU time.
  PosSalesMetrics getSalesMetrics({int windowDays = 1, double storeExpenses = 0.0}) {
    if (windowDays == 1 && _cached24hMetrics != null) {
      return _cached24hMetrics!;
    }
    if (windowDays == 10 && _cached10dMetrics != null) {
      return _cached10dMetrics!;
    }

    final maxAge = windowDays == 1 ? const Duration(hours: 24) : const Duration(days: 10);
    final allSales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get10DaySales();
    final cutoff = DateTime.now().subtract(maxAge);

    final recentSales = allSales.where((s) => s.createdAt.isAfter(cutoff)).toList();
    recentSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double totalRevenue = 0.0;
    double totalCogs = 0.0;
    double cashRevenue = 0.0;
    double upiRevenue = 0.0;
    double khataRevenue = 0.0;
    int totalUnitsSold = 0;

    final List<SoldProductTimelineItem> timeSortedItems = [];
    final Map<String, Map<String, dynamic>> aggregatedRanking = {};

    for (final sale in recentSales) {
      totalRevenue += sale.totalAmount;
      final method = sale.paymentMethod.toLowerCase();
      if (sale.splitPayments != null) {
        cashRevenue += sale.splitPayments!.cashAmount;
        upiRevenue += sale.splitPayments!.onlineAmount;
        khataRevenue += sale.splitPayments!.khataAmount;
      } else if (method == 'cash') {
        cashRevenue += sale.totalAmount;
      } else if (method == 'upi' || method == 'online') {
        upiRevenue += sale.totalAmount;
      } else if (method == 'khata' || method == 'credit' || method == 'udhar') {
        khataRevenue += sale.totalAmount;
      } else {
        cashRevenue += sale.totalAmount;
      }

      for (final cartItem in sale.items) {
        final pName = cartItem.product.name.trim().isNotEmpty ? cartItem.product.name.trim() : 'Product';
        final qty = cartItem.quantity;
        final unitPrice = cartItem.customPrice;
        final itemTotal = cartItem.total;
        final cost = cartItem.product.costPrice > 0 ? cartItem.product.costPrice : (unitPrice * 0.75);

        totalUnitsSold += qty;
        totalCogs += cost * qty;

        timeSortedItems.add(
          SoldProductTimelineItem(
            productName: pName,
            productSku: cartItem.product.sku,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: itemTotal,
            paymentMethod: sale.paymentMethod,
            soldAt: sale.createdAt,
            billNumber: sale.billNumber ?? '',
            customerPhone: sale.customerPhone,
          ),
        );

        if (aggregatedRanking.containsKey(pName)) {
          aggregatedRanking[pName]!['qty'] = (aggregatedRanking[pName]!['qty'] as int) + qty;
          aggregatedRanking[pName]!['quantity'] = (aggregatedRanking[pName]!['quantity'] as int) + qty;
          aggregatedRanking[pName]!['total'] = (aggregatedRanking[pName]!['total'] as double) + itemTotal;
          aggregatedRanking[pName]!['total_revenue'] = (aggregatedRanking[pName]!['total_revenue'] as double) + itemTotal;
        } else {
          aggregatedRanking[pName] = {
            'name': pName,
            'qty': qty,
            'quantity': qty,
            'unit_price': unitPrice,
            'total': itemTotal,
            'total_revenue': itemTotal,
          };
        }
      }
    }

    timeSortedItems.sort((a, b) => b.soldAt.compareTo(a.soldAt));

    final productRanking = aggregatedRanking.values.toList();
    productRanking.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    final grossProfit = totalRevenue - totalCogs;
    final proratedExpenses = windowDays == 1 ? (storeExpenses / 30.0) : (storeExpenses / 3.0);
    final effectiveExpenses = proratedExpenses > 0 ? proratedExpenses : 0.0;
    final netProfit = grossProfit - effectiveExpenses;
    final marginPct = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100).clamp(-100.0, 100.0) : 0.0;

    final metrics = PosSalesMetrics(
      totalRevenue: totalRevenue,
      totalCogs: totalCogs,
      grossProfit: grossProfit,
      netProfit: netProfit,
      marginPct: marginPct,
      totalBills: recentSales.length,
      totalUnitsSold: totalUnitsSold,
      cashRevenue: cashRevenue,
      upiRevenue: upiRevenue,
      khataRevenue: khataRevenue,
      recentSales: recentSales,
      timeSortedItems: timeSortedItems,
      productRanking: productRanking,
    );

    if (windowDays == 1) {
      _cached24hMetrics = metrics;
    } else {
      _cached10dMetrics = metrics;
    }

    return metrics;
  }

  /// 24-Hour Sales Analytics Summary (Products Sold in last 24 hours)
  double get today24hRevenue => getSalesMetrics(windowDays: 1).totalRevenue;

  int get today24hBillCount => getSalesMetrics(windowDays: 1).totalBills;

  /// 10-Day Sales Analytics Summary
  double get total10DayRevenue => getSalesMetrics(windowDays: 10).totalRevenue;

  int get total10DayBillCount => getSalesMetrics(windowDays: 10).totalBills;

  /// Get all individual sold items within the 10-day retention window, strictly sorted chronologically (newest first)
  List<SoldProductTimelineItem> getTimeSortedSoldItems({Duration maxAge = const Duration(days: 10)}) {
    final windowDays = maxAge.inHours <= 24 ? 1 : 10;
    return getSalesMetrics(windowDays: windowDays).timeSortedItems;
  }

  /// Aggregated summary of sold products (ranking by total revenue) for a given duration (default 10 days or 24h)
  List<Map<String, dynamic>> getSoldProductsSummary({Duration maxAge = const Duration(days: 10)}) {
    final windowDays = maxAge.inHours <= 24 ? 1 : 10;
    return getSalesMetrics(windowDays: windowDays).productRanking;
  }

  List<Map<String, dynamic>> get24HourSoldProductsSummary() {
    return getSoldProductsSummary(maxAge: const Duration(hours: 24));
  }

  // --- Speed-Optimized Quick Selling: Frequently Sold & Recent Products ---
  final List<String> _recentProductIds = [];
  List<String> get recentProductIds => List.unmodifiable(_recentProductIds);

  void recordRecentProduct(String productId) {
    if (productId.isEmpty || productId.startsWith('custom_')) return;
    _recentProductIds.remove(productId);
    _recentProductIds.insert(0, productId);
    if (_recentProductIds.length > 20) {
      _recentProductIds.removeLast();
    }
  }

  /// 8-10 Frequently Sold products aggregated from past 24h & confirmed sales
  List<ProductModel> get frequentlySoldProducts {
    final sales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get24HourSales();
    final Map<String, int> qtyMap = {};
    final Map<String, ProductModel> modelMap = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        final p = item.product;
        if (p.id.isNotEmpty && !p.id.startsWith('custom_')) {
          qtyMap[p.id] = (qtyMap[p.id] ?? 0) + item.quantity;
          modelMap[p.id] = p;
        }
      }
    }

    final sortedIds = qtyMap.keys.toList()
      ..sort((a, b) => (qtyMap[b] ?? 0).compareTo(qtyMap[a] ?? 0));

    final List<ProductModel> results = [];
    final Set<String> seen = {};

    for (final id in sortedIds) {
      final catalogMatch = _products.firstWhere(
        (cp) => cp.id == id,
        orElse: () => modelMap[id] ?? ProductModel(id: '', name: '', price: 0, stock: 0, category: ''),
      );
      if (catalogMatch.id.isNotEmpty && !seen.contains(catalogMatch.id)) {
        results.add(catalogMatch);
        seen.add(catalogMatch.id);
        if (results.length >= 10) break;
      }
    }

    // Fallback: If not enough sold items, populate from catalog
    if (results.length < 10) {
      for (final p in _products) {
        if (!seen.contains(p.id)) {
          results.add(p);
          seen.add(p.id);
          if (results.length >= 10) break;
        }
      }
    }

    return results;
  }

  /// 8-10 Recent Products (last sold or scanned items)
  List<ProductModel> get recentProducts {
    final List<ProductModel> results = [];
    final Set<String> seen = {};

    // 1. In-session recently used products
    for (final id in _recentProductIds) {
      final p = _products.firstWhere(
        (item) => item.id == id,
        orElse: () => ProductModel(id: '', name: '', price: 0, stock: 0, category: ''),
      );
      if (p.id.isNotEmpty && !seen.contains(p.id)) {
        results.add(p);
        seen.add(p.id);
        if (results.length >= 10) return results;
      }
    }

    // 2. From recent sales (newest first)
    final sales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get24HourSales();
    for (final sale in sales) {
      for (final item in sale.items) {
        final id = item.product.id;
        if (id.isNotEmpty && !id.startsWith('custom_') && !seen.contains(id)) {
          final catalogMatch = _products.firstWhere(
            (cp) => cp.id == id,
            orElse: () => item.product,
          );
          if (catalogMatch.id.isNotEmpty && !seen.contains(catalogMatch.id)) {
            results.add(catalogMatch);
            seen.add(catalogMatch.id);
            if (results.length >= 10) return results;
          }
        }
      }
    }

    // 3. Fallback to catalog if empty
    if (results.isEmpty) {
      return _products.take(10).toList();
    }

    return results;
  }

  StreamSubscription<AppCacheEvent>? _productsSub;
  StreamSubscription<AppCacheEvent>? _inventorySub;
  StreamSubscription<AppCacheEvent>? _reservationSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  PosController({PosRepository? repository}) : _repo = repository ?? PosRepository() {
    _initFromCache();
    loadCatalog(forceRefresh: true);
    fetchBackendSales();
    CounterWebSocketService.instance.connect();
    fetchActiveBaskets();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _productsSub = AppEventBus().on(AppCacheEventType.productsMutated, (_) {
      loadCatalog(forceRefresh: true);
    });
    _inventorySub = AppEventBus().on(AppCacheEventType.inventoryMutated, (_) {
      loadCatalog(forceRefresh: true);
    });
    _reservationSub = AppEventBus().on(AppCacheEventType.reservationMutated, (_) {
      loadCatalog(forceRefresh: true);
    });
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _products = [];
      _barcodeIndex.clear();
      _serverSales = [];
      invalidateSalesMetricsCache();
      clearCart();
      notifyListeners();
    });
    _posParkedSub = CounterWebSocketService.instance.posParkedStream.listen((eventData) {
      _handleParkedStreamEvent(eventData);
    });
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSyncDebounce?.cancel();
    _posParkedSub?.cancel();
    _productsSub?.cancel();
    _inventorySub?.cancel();
    _reservationSub?.cancel();
    _logoutSub?.cancel();
    super.dispose();
  }

  void _initFromCache() {
    _autoPrintEnabled = LocalCacheService.getAutoPrintEnabled();
    final cached = LocalCacheService.getProducts();
    if (cached.isNotEmpty) {
      _products = cached;
      _rebuildBarcodeIndex();
    }
    final cachedSales = LocalCacheService.get10DaySales();
    if (cachedSales.isNotEmpty) {
      _serverSales = cachedSales;
      invalidateSalesMetricsCache();
    }
    final draftCart = LocalCacheService.getCartDraft();
    if (draftCart.isNotEmpty && _cart.isEmpty) {
      _cart.addAll(draftCart);
    }
  }

  /// Proactively loads catalog products for zero-lag POS search & barcode lookup
  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (_products.isNotEmpty && !forceRefresh) return;
    final inFlight = _catalogLoadInFlight;
    if (inFlight != null) return inFlight;

    final request = _fetchCatalog(forceRefresh: forceRefresh);
    _catalogLoadInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_catalogLoadInFlight, request)) {
        _catalogLoadInFlight = null;
      }
    }
  }

  Future<void> _fetchCatalog({required bool forceRefresh}) async {
    try {
      final res = await _repo.searchProducts('');
      if (res.success && res.data != null) {
        _products = res.data!;
        _rebuildBarcodeIndex();
        await LocalCacheService.saveProducts(_products);
        notifyListeners();
      } else if (forceRefresh || _products.isEmpty) {
        setError(
          res.error ??
              (TokenStorage.getLanguage() == 'hi'
                  ? 'उत्पाद कैटलॉग लोड नहीं हो सका'
                  : 'Product catalog could not be refreshed'),
        );
      }
    } catch (e) {
      if (forceRefresh || _products.isEmpty) {
        setError(e.toString());
      }
    }
  }

  /// Fetches confirmed PostgreSQL sales for live reports and Today's Sales Screen (10-day retention window)
  /// Safely merges server records with existing local unsynced/recent bills so no data ever disappears.
  Future<void> fetchBackendSales({String date = ''}) async {
    try {
      var res = await _repo.getSales(limit: 100, date: date);
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final serverList = res.data!;
        final localList = LocalCacheService.get10DaySales();
        final Map<String, SaleModel> deduplicated = {};

        for (final s in serverList) {
          final billNum = s.billNumber?.trim() ?? '';
          final key = billNum.isNotEmpty ? billNum : 's_${s.createdAt.millisecondsSinceEpoch}_${s.totalAmount}';
          deduplicated[key] = s;
        }

        for (final s in localList) {
          final billNum = s.billNumber?.trim() ?? '';
          final key = billNum.isNotEmpty ? billNum : 's_${s.createdAt.millisecondsSinceEpoch}_${s.totalAmount}';
          if (!deduplicated.containsKey(key)) {
            deduplicated[key] = s;
          }
        }

        final merged = deduplicated.values.toList();
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _serverSales = merged;
        invalidateSalesMetricsCache();
        await LocalCacheService.saveSalesList(_serverSales);
        notifyListeners();
        return;
      }

      // Fallback: If date was specific and returned empty, fetch general 10-day history
      if (date.isNotEmpty) {
        res = await _repo.getSales(limit: 100, date: '');
        if (res.success && res.data != null && res.data!.isNotEmpty) {
          final serverList = res.data!;
          final localList = LocalCacheService.get10DaySales();
          final Map<String, SaleModel> deduplicated = {};

          for (final s in serverList) {
            final billNum = s.billNumber?.trim() ?? '';
            final key = billNum.isNotEmpty ? billNum : 's_${s.createdAt.millisecondsSinceEpoch}_${s.totalAmount}';
            deduplicated[key] = s;
          }

          for (final s in localList) {
            final billNum = s.billNumber?.trim() ?? '';
            final key = billNum.isNotEmpty ? billNum : 's_${s.createdAt.millisecondsSinceEpoch}_${s.totalAmount}';
            if (!deduplicated.containsKey(key)) {
              deduplicated[key] = s;
            }
          }

          final merged = deduplicated.values.toList();
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _serverSales = merged;
          invalidateSalesMetricsCache();
          await LocalCacheService.saveSalesList(_serverSales);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setCustomerPhone(String phone) {
    if (_isCompletingSale) return;
    _customerPhone = phone;
    scheduleAutoSync();
    notifyListeners();
  }

  void setCustomerName(String name) {
    if (_isCompletingSale) return;
    _customerName = name;
    scheduleAutoSync();
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    if (_isCompletingSale) return;
    if (!const {'cash', 'upi', 'split', 'khata'}.contains(method)) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'भुगतान का तरीका मान्य नहीं है'
            : 'Unsupported payment method',
      );
      return;
    }
    _paymentMethod = method;
    scheduleAutoSync();
    notifyListeners();
  }

  void setDiscount(double amount) {
    if (_isCompletingSale) return;
    if (!amount.isFinite || amount < 0 || amount > subtotal) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'छूट बिल की राशि से अधिक नहीं हो सकती'
            : 'Discount cannot exceed the bill subtotal',
      );
      return;
    }
    _discount = amount;
    scheduleAutoSync();
    notifyListeners();
  }

  void setCashTendered(double amount) {
    if (_isCompletingSale) return;
    if (!amount.isFinite || amount < 0) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'नकद राशि मान्य नहीं है'
            : 'Enter a valid cash amount',
      );
      return;
    }
    _cashTendered = amount;
    notifyListeners();
  }

  void addToCart(ProductModel product, {int quantity = 1}) {
    if (_isCompletingSale) return;
    if (quantity <= 0 || !product.price.isFinite || product.price < 0) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'वस्तु की कीमत या मात्रा मान्य नहीं है'
            : 'The item price or quantity is invalid',
      );
      return;
    }
    recordRecentProduct(product.id);
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(PosCartItem(product: product, quantity: quantity));
    }
    AppAudioHapticFeedback.scanSuccess();
    scheduleAutoSync();
    notifyListeners();
  }

  void addCustomItem({
    required String name,
    required double price,
    int quantity = 1,
    String unit = 'item',
  }) {
    if (_isCompletingSale) return;
    if (!price.isFinite || price <= 0 || quantity <= 0) {
      setError(
        TokenStorage.getLanguage() == 'hi'
            ? 'कस्टम वस्तु की कीमत और मात्रा मान्य होनी चाहिए'
            : 'Custom item price and quantity must be valid',
      );
      return;
    }
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Custom Item';
    final customProduct = ProductModel(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      price: price > 0 ? price : 0.0,
      stock: 9999,
      unit: unit.trim().isNotEmpty ? unit.trim() : 'item',
      category: 'General Store',
    );
    _cart.add(PosCartItem(product: customProduct, quantity: quantity, customPrice: price));
    AppAudioHapticFeedback.scanSuccess();
    scheduleAutoSync();
    notifyListeners();
  }

  void updateCartItemPrice(PosCartItem item, double newPrice) {
    if (_isCompletingSale) return;
    if (newPrice.isFinite && newPrice >= 0 && _cart.contains(item)) {
      item.customPrice = newPrice;
      scheduleAutoSync();
      notifyListeners();
    }
  }

  /// ✂️ Decomposes/Breaks a multi-piece garment set (e.g. 3-pc Kurti Set -> Kurti Only)
  /// Replaces the cart item with the selected single piece and its custom price.
  void breakSetCartItem({
    required PosCartItem item,
    required String selectedPieceName,
    required double selectedPiecePrice,
  }) {
    if (_isCompletingSale) return;
    final idx = _cart.indexOf(item);
    if (idx != -1 &&
        selectedPieceName.trim().isNotEmpty &&
        selectedPiecePrice.isFinite &&
        selectedPiecePrice > 0) {
      final updatedProduct = item.product.copyWith(
        name: selectedPieceName,
        price: selectedPiecePrice,
      );
      _cart[idx] = PosCartItem(
        product: updatedProduct,
        quantity: item.quantity > 0 ? item.quantity : 1,
        customPrice: selectedPiecePrice,
      );
      scheduleAutoSync();
      notifyListeners();
    }
  }

  void incrementQuantity(PosCartItem item) {
    if (_isCompletingSale || !_cart.contains(item)) return;
    item.quantity += 1;
    scheduleAutoSync();
    notifyListeners();
  }

  void decrementQuantity(PosCartItem item) {
    if (_isCompletingSale || !_cart.contains(item)) return;
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _cart.remove(item);
    }
    scheduleAutoSync();
    notifyListeners();
  }

  void removeFromCart(PosCartItem item) {
    if (_isCompletingSale) return;
    _cart.remove(item);
    scheduleAutoSync();
    notifyListeners();
  }

  void clearCart({bool syncWithBackend = true}) {
    if (_isCompletingSale) return;
    _resetCartState(syncWithBackend: syncWithBackend);
  }

  void _resetCartState({required bool syncWithBackend}) {
    _cart.clear();
    LocalCacheService.clearCartDraft();
    _discount = 0.0;
    _customerPhone = '';
    _customerName = '';
    _cashTendered = 0.0;
    _splitCashAmount = 0.0;
    _paymentMethod = 'cash';
    if (syncWithBackend) {
      scheduleAutoSync();
    }
    notifyListeners();
  }

  // --- Real-time Floor Multi-Basket Synchronization Engine ---

  void _handleParkedStreamEvent(Map<String, dynamic> eventData) {
    final event = eventData['event']?.toString() ?? '';
    final payload = eventData['payload'] is Map<String, dynamic>
        ? eventData['payload'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (event == 'POS_PARKED_BILLS_CHANGED') {
      final token = payload['token']?.toString() ?? '';
      fetchActiveBaskets(silent: true);

      // If another family member updated the active token on their phone:
      if (!_isSyncingToServer && token.isNotEmpty && token.toUpperCase() == _currentActiveToken.toUpperCase()) {
        if (payload['bill'] is Map<String, dynamic>) {
          final bill = PosParkedBill.fromJson(payload['bill'] as Map<String, dynamic>);
          final serverCount = bill.totalItemCount;
          final localCount = totalItemCount;
          if (bill.items.length != _cart.length || serverCount != localCount) {
            _cart.clear();
            for (final item in bill.items) {
              _cart.add(PosCartItem(
                product: item.product,
                quantity: item.quantity,
                customPrice: item.customPrice,
              ));
            }
            if (bill.customerPhone.isNotEmpty) _customerPhone = bill.customerPhone;
            if (bill.customerName.isNotEmpty) _customerName = bill.customerName;
            _discount = bill.discountAmount;
            _paymentMethod = bill.paymentMethod;
            notifyListeners();
          }
        }
      }
    } else if (event == 'POS_PARKED_BILL_DELETED') {
      final idOrToken = payload['id_or_token']?.toString() ?? '';
      _activeBaskets.removeWhere((b) =>
          b.id == idOrToken || b.label.toUpperCase() == idOrToken.toUpperCase());
      if (_currentActiveToken.toUpperCase() == idOrToken.toUpperCase()) {
        clearCart(syncWithBackend: false);
      }
      notifyListeners();
    }
  }

  Future<void> fetchActiveBaskets({bool silent = false}) async {
    if (!silent) {
      _isLoadingBaskets = true;
      notifyListeners();
    }
    try {
      final res = await _repo.listParkedBills();
      if (res.success && res.data != null) {
        _activeBaskets = res.data!.map((e) => PosParkedBill.fromJson(e)).toList();

        // If local cart is empty, check if active token already has items on server
        if (_cart.isEmpty) {
          final match = _activeBaskets.firstWhere(
            (b) => b.label.toUpperCase() == _currentActiveToken.toUpperCase(),
            orElse: () => PosParkedBill(id: '', label: '', items: [], totalAmount: 0),
          );
          if (match.items.isNotEmpty) {
            _cart.clear();
            for (final item in match.items) {
              _cart.add(PosCartItem(
                product: item.product,
                quantity: item.quantity,
                customPrice: item.customPrice,
              ));
            }
            _customerPhone = match.customerPhone;
            _customerName = match.customerName;
            _discount = match.discountAmount;
            _paymentMethod = match.paymentMethod;
          }
        }
      }
    } catch (_) {}
    if (!silent) {
      _isLoadingBaskets = false;
    }
    notifyListeners();
  }

  Future<void> switchToken(String newToken) async {
    final clean = newToken.trim().toUpperCase();
    if (clean.isEmpty || clean == _currentActiveToken) return;

    // Flush any pending sync on old token
    _autoSyncDebounce?.cancel();
    if (_cart.isNotEmpty) {
      await syncCurrentTokenToBackend();
    }

    _currentActiveToken = clean;

    final match = _activeBaskets.firstWhere(
      (b) => b.label.toUpperCase() == clean,
      orElse: () => PosParkedBill(id: '', label: '', items: [], totalAmount: 0),
    );

    if (match.items.isNotEmpty) {
      _cart.clear();
      for (final item in match.items) {
        _cart.add(PosCartItem(
          product: item.product,
          quantity: item.quantity,
          customPrice: item.customPrice,
        ));
      }
      _customerPhone = match.customerPhone;
      _customerName = match.customerName;
      _discount = match.discountAmount;
      _paymentMethod = match.paymentMethod;
      _cashTendered = 0.0;
    } else {
      clearCart(syncWithBackend: false);
    }

    notifyListeners();
  }

  void scheduleAutoSync() {
    // ⚡ Tier 1: In-Memory Draft Auto-Save (Crash & Low-Battery Protection)
    LocalCacheService.saveCartDraft(_cart);

    final token = TokenStorage.getToken();
    if (token == null || token.isEmpty) return;

    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      syncCurrentTokenToBackend();
    });
  }

  Future<void> syncCurrentTokenToBackend() async {
    if (_isSyncingToServer) return;
    if (_currentActiveToken.trim().isEmpty) return;

    if (_cart.isEmpty) {
      final existed = _activeBaskets.any((b) => b.label.toUpperCase() == _currentActiveToken.toUpperCase());
      if (existed) {
        _activeBaskets.removeWhere((b) => b.label.toUpperCase() == _currentActiveToken.toUpperCase());
        notifyListeners();
        try {
          await _repo.deleteParkedBill(_currentActiveToken);
        } catch (_) {}
      }
      return;
    }

    _isSyncingToServer = true;
    try {
      final res = await _repo.parkBill(
        label: _currentActiveToken,
        items: _cart,
        discountAmount: _discount,
        customerPhone: _customerPhone,
        paymentMethod: _paymentMethod,
      );
      if (res.success && res.data != null) {
        final bill = PosParkedBill.fromJson(res.data!);
        final idx = _activeBaskets.indexWhere((b) => b.label.toUpperCase() == _currentActiveToken.toUpperCase());
        if (idx >= 0) {
          _activeBaskets[idx] = bill;
        } else {
          _activeBaskets.add(bill);
        }
        notifyListeners();
      }
    } catch (_) {} finally {
      _isSyncingToServer = false;
    }
  }

  /// Parks current active bill cart so another customer can be billed at the counter
  bool holdCurrentBill() {
    if (_cart.isEmpty) return false;
    _heldBills.add(PosHeldBill(
      id: 'held_${DateTime.now().millisecondsSinceEpoch}',
      heldAt: DateTime.now(),
      items: List<PosCartItem>.from(_cart.map((e) => PosCartItem(
        product: e.product,
        quantity: e.quantity,
        customPrice: e.customPrice,
      ))),
      customerPhone: _customerPhone,
      customerName: _customerName,
      discount: _discount,
      paymentMethod: _paymentMethod,
    ));
    clearCart();
    return true;
  }

  /// Restores a previously held bill back into the active counter cart
  void recallHeldBill(PosHeldBill bill) {
    clearCart();
    for (final item in bill.items) {
      _cart.add(PosCartItem(
        product: item.product,
        quantity: item.quantity,
        customPrice: item.customPrice,
      ));
    }
    _customerPhone = bill.customerPhone;
    _customerName = bill.customerName;
    _discount = bill.discount;
    _paymentMethod = bill.paymentMethod;
    _heldBills.removeWhere((b) => b.id == bill.id);
    notifyListeners();
  }

  /// Discards a held bill from memory
  void deleteHeldBill(PosHeldBill bill) {
    _heldBills.removeWhere((b) => b.id == bill.id);
    notifyListeners();
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final response = await _repo.searchProducts(query);
    if (response.success && response.data != null) {
      return response.data!;
    }

    setError(
      response.error ??
          (TokenStorage.getLanguage() == 'hi'
              ? 'उत्पाद खोजे नहीं जा सके'
              : 'Products could not be searched'),
    );
    return const [];
  }

  String _lastScannedActionMessage = '';
  String get lastScannedActionMessage => _lastScannedActionMessage;

  Future<bool> scanAndAddToCart(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return false;
    _lastScannedActionMessage = '';

    // Check if scanned code is a Floor Basket Token QR Code (e.g. SHOP-TOKEN:T-05 or TOKEN:T-05 or T-05)
    final upper = cleanBarcode.toUpperCase();
    if (upper.startsWith('SHOP-TOKEN:') || upper.startsWith('TOKEN:') || RegExp(r'^T-\d{2}$').hasMatch(upper)) {
      String token = upper;
      if (token.startsWith('SHOP-TOKEN:')) {
        token = token.substring('SHOP-TOKEN:'.length).trim();
      } else if (token.startsWith('TOKEN:')) {
        token = token.substring('TOKEN:'.length).trim();
      }
      if (token.isNotEmpty) {
        await switchToken(token);
        _lastScannedActionMessage = 'TOKEN:$token';
        return true;
      }
    }

    // 1. Try In-Memory (RAM) O(1) Hash Index first (sub-millisecond instant lookup)
    final lowerBarcode = cleanBarcode.toLowerCase();
    ProductModel? localMatch = _barcodeIndex[lowerBarcode];

    // Fallback to in-memory linear match if item was typed by product name
    localMatch ??= _products.firstWhere(
      (p) => p.name.toLowerCase() == lowerBarcode,
      orElse: () => ProductModel(id: '', name: '', price: 0, stock: 0, category: ''),
    );

    if (localMatch.id.toString().isNotEmpty) {
      addToCart(localMatch);
      _lastScannedActionMessage = 'PRODUCT:${localMatch.name}';
      return true;
    }

    // 2. Try repository API barcode scan
    final response = await _repo.scanBarcode(cleanBarcode);
    if (response.success && response.data != null) {
      addToCart(response.data!);
      _lastScannedActionMessage = 'PRODUCT:${response.data!.name}';
      return true;
    }
    return false;
  }

  /// Quickly registers a brand-new unlisted barcode item directly on the floor
  /// and adds it to the current active customer's cart
  Future<bool> quickRegisterBarcodeAndAddToCart({
    required String barcode,
    required String name,
    required double price,
    double costPrice = 0.0,
    double mrp = 0.0,
    int stock = 50,
    String unit = 'pcs',
    String category = 'General Store',
  }) async {
    final cleanBarcode = barcode.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Item $cleanBarcode';
    if (cleanBarcode.isEmpty ||
        !price.isFinite ||
        price <= 0 ||
        !mrp.isFinite ||
        mrp < 0) {
      return false;
    }

    try {
      final newProduct = ProductModel(
        id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        barcode: cleanBarcode,
        sku: cleanBarcode,
        price: price,
        costPrice: costPrice,
        comparePrice: mrp > 0 ? mrp : price,
        stock: stock,
        category: category,
        unit: unit,
        isActive: true,
      );

      // 1. Add to local memory catalog for instant subsequent scans
      _products.insert(0, newProduct);
      _rebuildBarcodeIndex();
      LocalCacheService.saveProducts(_products);

      // 2. Add to active cart
      addToCart(newProduct);
      _lastScannedActionMessage = 'PRODUCT:$cleanName';

      // 3. Silently persist to backend in background
      final productData = {
        'name': cleanName,
        'barcode': cleanBarcode,
        'sku': cleanBarcode,
        'price': price,
        if (costPrice > 0) 'cost_price': costPrice,
        'compare_price': mrp > 0 ? mrp : price,
        'mrp': mrp > 0 ? mrp : price,
        'stock': stock,
        'stock_quantity': stock,
        'category': category,
        'unit': unit,
        'is_active': true,
      };

      final sessionToken = TokenStorage.getToken();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        ProductRepository().createProduct(productData).then((res) {
          if (res.success && res.data != null) {
            final idx = _products.indexWhere((p) => p.barcode == cleanBarcode);
            if (idx >= 0) {
              _products[idx] = res.data!;
              _rebuildBarcodeIndex();
              LocalCacheService.saveProducts(_products);
            }
          }
          AppEventBus().emit(AppCacheEventType.productsMutated);
        }).catchError((_) {});
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SaleModel?> completeSale() async {
    if (_isCompletingSale) return null;

    if (_cart.isEmpty) {
      setError(TokenStorage.getLanguage() == 'hi' ? 'बिल कार्ट खाली है, कृपया पहले आइटम जोड़ें' : 'Bill Cart is empty, please scan or add items first');
      return null;
    }

    final isHindi = TokenStorage.getLanguage() == 'hi';
    final customerPhone = _customerPhone.replaceAll(RegExp(r'\D'), '');
    if (_paymentMethod == 'khata' && !RegExp(r'^\d{10}$').hasMatch(customerPhone)) {
      setError(
        isHindi
            ? 'उधार बिलिंग के लिए 10 अंकों का मोबाइल नंबर आवश्यक है'
            : 'Credit billing requires a valid 10-digit customer mobile',
      );
      return null;
    }

    final currentSubtotal = subtotal;
    if (!currentSubtotal.isFinite ||
        _cart.any(
          (item) =>
              item.quantity <= 0 ||
              !item.customPrice.isFinite ||
              item.customPrice < 0 ||
              !item.total.isFinite,
        ) ||
        !_discount.isFinite ||
        _discount < 0 ||
        _discount > currentSubtotal) {
      setError(
        isHindi
            ? 'बिल में अमान्य कीमत, मात्रा या छूट है'
            : 'The bill contains an invalid price, quantity, or discount',
      );
      return null;
    }

    if (_paymentMethod == 'split' &&
        (!_splitCashAmount.isFinite ||
            _splitCashAmount < 0 ||
            _splitCashAmount > grandTotal)) {
      setError(
        isHindi
            ? 'स्प्लिट भुगतान की नकद राशि बिल की कुल राशि से अधिक नहीं हो सकती'
            : 'The split cash amount cannot exceed the bill total',
      );
      return null;
    }

    final paymentMethod = _paymentMethod;
    final customerPhoneForSale = paymentMethod == 'khata'
        ? customerPhone
        : _customerPhone.trim();
    final customerName = _customerName.trim();
    final discountAmount = _discount;
    final saleTotal = grandTotal;
    final items = List<PosCartItem>.unmodifiable(
      _cart.map(
        (item) => PosCartItem(
          product: item.product,
          quantity: item.quantity,
          customPrice: item.customPrice,
        ),
      ),
    );
    final billedToken = _currentActiveToken;

    PosSplitPayment? split;
    if (paymentMethod == 'split') {
      split = PosSplitPayment(
        cashAmount: _splitCashAmount,
        onlineAmount: saleTotal - _splitCashAmount,
      );
    }

    final checkoutSessionKey =
        'pos_${billedToken}_${DateTime.now().microsecondsSinceEpoch}';
    _isCompletingSale = true;
    notifyListeners();
    setLoading(true);
    clearError();

    try {
      final response = await _repo.createSale(
        customerPhone: customerPhoneForSale,
        customerName: customerName,
        items: items,
        discountAmount: discountAmount,
        paymentMethod: paymentMethod,
        splitPayments: split,
        idempotencyKey: checkoutSessionKey,
      );

      if (response.success && response.data != null) {
        _lastCompletedSale = response.data;
        await LocalCacheService.saveCompletedSale(_lastCompletedSale!);
        _insertRecentSale(_lastCompletedSale!);

        await _repo.deleteParkedBill(billedToken);
        _activeBaskets.removeWhere(
          (b) => b.label.toUpperCase() == billedToken.toUpperCase(),
        );

        _resetCartState(syncWithBackend: false);
        fetchBackendSales();

        AppEventBus().emit(
          AppCacheEventType.posSaleCompleted,
          payload: _lastCompletedSale,
        );
        AppEventBus().emit(AppCacheEventType.inventoryMutated);
        if (paymentMethod == 'khata') {
          AppEventBus().emit(AppCacheEventType.khataMutated);
        }
        return _lastCompletedSale;
      }

      final now = DateTime.now();
      final offlineBillNum =
          'OFF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.microsecondsSinceEpoch.toString().substring(8)}';
      _lastCompletedSale = SaleModel(
        billNumber: offlineBillNum,
        customerPhone: customerPhoneForSale,
        items: items,
        subtotal: currentSubtotal,
        discountAmount: discountAmount,
        totalAmount: saleTotal,
        paymentMethod: paymentMethod,
        splitPayments: split,
        createdAt: now,
      );

      await LocalCacheService.saveCompletedSale(_lastCompletedSale!);
      _insertRecentSale(_lastCompletedSale!);
      await OfflineSyncService.instance.enqueue(
        action: SyncActionType.posSale,
        endpoint: ApiConstants.posSale,
        method: 'POST',
        idempotencyKey: checkoutSessionKey,
        payload: {
          'customer_phone': customerPhoneForSale,
          'customer_name': customerName,
          'items': items.map((item) => item.toJson()).toList(),
          'discount_amount': discountAmount,
          'payment_method': paymentMethod,
          if (split != null) 'split_payments': split.toJson(),
        },
        title: 'POS Bill #$offlineBillNum',
        amount: saleTotal,
      );

      _activeBaskets.removeWhere(
        (b) => b.label.toUpperCase() == billedToken.toUpperCase(),
      );
      _resetCartState(syncWithBackend: false);
      AppEventBus().emit(
        AppCacheEventType.posSaleCompleted,
        payload: _lastCompletedSale,
      );
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      if (paymentMethod == 'khata') {
        AppEventBus().emit(AppCacheEventType.khataMutated);
      }
      return _lastCompletedSale;
    } finally {
      setLoading(false);
      _isCompletingSale = false;
      notifyListeners();
    }
  }

  void _insertRecentSale(SaleModel sale) {
    final billNumber = sale.billNumber;
    if (billNumber != null && billNumber.isNotEmpty) {
      _serverSales.removeWhere((existing) => existing.billNumber == billNumber);
    }
    _serverSales.insert(0, sale);
    invalidateSalesMetricsCache();
  }

  /// 🖨️ Direct Print 58mm / 80mm Vector Thermal Receipt via OS Spooler & Printer Drivers
  Future<bool> generateThermalReceiptPdf(
    BuildContext context,
    SaleModel sale,
    String shopName, {
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    ThermalReceiptWidth width = ThermalReceiptWidth.roll80mm,
  }) async {
    return await ThermalReceiptPdfService.directPrintReceipt(
      sale: sale,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      upiId: upiId,
      width: width,
    );
  }

  /// 📤 Share Thermal Receipt PDF directly via WhatsApp or System Share
  Future<void> shareThermalReceiptPdf(
    SaleModel sale,
    String shopName, {
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    ThermalReceiptWidth width = ThermalReceiptWidth.roll80mm,
  }) async {
    await ThermalReceiptPdfService.shareReceiptPdf(
      sale: sale,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      upiId: upiId,
      width: width,
    );
  }

  /// ⚡ Direct ESC/POS High-Speed Thermal Print via Network/IP Socket (10ms, no print preview dialog)
  Future<bool> printViaEscPosTcp({
    required SaleModel sale,
    required String shopName,
    required String printerIp,
    int port = 9100,
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    EscPosRollWidth width = EscPosRollWidth.roll80mm,
  }) async {
    final bytes = EscPosService.generateReceiptBytes(
      sale: sale,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      upiId: upiId,
      rollWidth: width,
    );

    return await EscPosService.printViaTcpSocket(
      printerIp: printerIp,
      port: port,
      bytes: bytes,
    );
  }

  /// 🔄 Process In-Store POS Bill Return & Restock Inventory
  Future<ApiResponse<Map<String, dynamic>>> processBillReturn({
    required String billNumber,
    required List<Map<String, dynamic>> items,
    String refundMode = 'cash',
    String reason = '',
  }) async {
    setLoading(true);
    clearError();

    final response = await _repo.processPosReturn(
      billNumber: billNumber,
      items: items,
      refundMode: refundMode,
      reason: reason,
    );

    setLoading(false);

    if (response.success) {
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      AppEventBus().emit(AppCacheEventType.posSaleCompleted);
      if (refundMode == 'khata') {
        AppEventBus().emit(AppCacheEventType.khataMutated);
      }
      notifyListeners();
    } else {
      setError(response.error ?? 'Failed to process return');
    }

    return response;
  }

  // --- Receiptless Return Lookup (Search past bills by phone or barcode within 30 days) ---
  final PosAdvancedRepository _advancedRepo = PosAdvancedRepository();
  List<ReturnLookupItem> _lookupResults = [];
  List<ReturnLookupItem> get lookupResults => List.unmodifiable(_lookupResults);
  bool _isLookingUpReturns = false;
  bool get isLookingUpReturns => _isLookingUpReturns;

  Future<void> lookupReturns({String? phone, String? barcode}) async {
    _isLookingUpReturns = true;
    _lookupResults = [];
    notifyListeners();

    final res = await _advancedRepo.lookupReturns(phone: phone, barcode: barcode);
    _isLookingUpReturns = false;

    if (res.success && res.data != null) {
      _lookupResults = res.data!;
      notifyListeners();
    } else {
      _lookupResults = [];
      setError(res.error ?? 'No past purchase records found for this customer or barcode');
    }
  }

  void clearLookup() {
    _lookupResults = [];
    notifyListeners();
  }
}
