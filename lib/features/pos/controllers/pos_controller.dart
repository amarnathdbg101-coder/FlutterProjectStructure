import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/audio_haptic_service.dart';
import '../../../core/services/counter_websocket_service.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../products/models/product_model.dart';
import '../../products/repositories/product_repository.dart';
import '../models/pos_model.dart';
import '../repositories/pos_repository.dart';

class PosController extends BaseController {
  final PosRepository _repo = PosRepository();

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

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
    _splitCashAmount = val >= 0 ? val : 0.0;
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

  /// 24-Hour Sales Analytics Summary (Products Sold in last 24 hours)
  double get today24hRevenue {
    final sales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get24HourSales();
    return sales.fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get today24hBillCount {
    final sales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get24HourSales();
    return sales.length;
  }

  List<Map<String, dynamic>> get24HourSoldProductsSummary() {
    final sales = _serverSales.isNotEmpty ? _serverSales : LocalCacheService.get24HourSales();
    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final sale in sales) {
      for (final item in sale.items) {
        final name = item.product.name.trim().isNotEmpty ? item.product.name.trim() : 'Product';
        if (aggregated.containsKey(name)) {
          aggregated[name]!['qty'] = (aggregated[name]!['qty'] as int) + item.quantity;
          aggregated[name]!['total'] = (aggregated[name]!['total'] as double) + item.total;
        } else {
          aggregated[name] = {
            'name': name,
            'qty': item.quantity,
            'unit_price': item.customPrice,
            'total': item.total,
          };
        }
      }
    }

    final list = aggregated.values.toList();
    list.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return list;
  }

  StreamSubscription<AppCacheEvent>? _productsSub;
  StreamSubscription<AppCacheEvent>? _inventorySub;
  StreamSubscription<AppCacheEvent>? _reservationSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  PosController() {
    _initFromCache();
    loadCatalog();
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
      _serverSales = [];
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
    final cached = LocalCacheService.getProducts();
    if (cached.isNotEmpty) {
      _products = cached;
    }
    final cachedSales = LocalCacheService.get24HourSales();
    if (cachedSales.isNotEmpty) {
      _serverSales = cachedSales;
    }
  }

  /// Proactively loads catalog products for zero-lag POS search & barcode lookup
  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (_products.isNotEmpty && !forceRefresh) return;
    try {
      final res = await _repo.searchProducts('');
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        _products = res.data!;
        await LocalCacheService.saveProducts(_products);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Fetches confirmed PostgreSQL sales for live reports and Today's Sales Screen
  Future<void> fetchBackendSales({String date = 'today'}) async {
    try {
      var res = await _repo.getSales(date: date);
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        _serverSales = res.data!;
        await LocalCacheService.saveSalesList(_serverSales);
        notifyListeners();
        return;
      }

      // Fallback: If date='today' returned empty, fetch all recent sales history
      if (date == 'today') {
        res = await _repo.getSales(date: '');
        if (res.success && res.data != null && res.data!.isNotEmpty) {
          _serverSales = res.data!;
          await LocalCacheService.saveSalesList(_serverSales);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setCustomerPhone(String phone) {
    _customerPhone = phone;
    scheduleAutoSync();
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name;
    scheduleAutoSync();
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    scheduleAutoSync();
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
    scheduleAutoSync();
    notifyListeners();
  }

  void setCashTendered(double amount) {
    _cashTendered = amount;
    notifyListeners();
  }

  void addToCart(ProductModel product, {int quantity = 1}) {
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

  void addCustomItem({required String name, required double price, int quantity = 1}) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Custom Item';
    final customProduct = ProductModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      price: price > 0 ? price : 0.0,
      stock: 999,
      unit: 'item',
      category: 'Services & Others',
    );
    _cart.add(PosCartItem(product: customProduct, quantity: quantity, customPrice: price));
    AppAudioHapticFeedback.scanSuccess();
    scheduleAutoSync();
    notifyListeners();
  }

  void updateCartItemPrice(PosCartItem item, double newPrice) {
    if (newPrice >= 0) {
      item.customPrice = newPrice;
      scheduleAutoSync();
      notifyListeners();
    }
  }

  void incrementQuantity(PosCartItem item) {
    item.quantity += 1;
    scheduleAutoSync();
    notifyListeners();
  }

  void decrementQuantity(PosCartItem item) {
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _cart.remove(item);
    }
    scheduleAutoSync();
    notifyListeners();
  }

  void removeFromCart(PosCartItem item) {
    _cart.remove(item);
    scheduleAutoSync();
    notifyListeners();
  }

  void clearCart({bool syncWithBackend = true}) {
    _cart.clear();
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

  Future<void> searchProducts(String query) async {
    setLoading(true);
    clearError();

    final response = await _repo.searchProducts(query);
    setLoading(false);

    if (response.success && response.data != null) {
      _products = response.data!;
      notifyListeners();
    } else {
      setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'उत्पाद लोड नहीं हो सके' : 'Failed to load products'));
    }
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

    // 1. Try local memory search first (0ms)
    final localMatch = _products.firstWhere(
      (p) => p.barcode.toLowerCase() == cleanBarcode.toLowerCase() ||
             p.sku.toLowerCase() == cleanBarcode.toLowerCase() ||
             p.name.toLowerCase() == cleanBarcode.toLowerCase(),
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
    double mrp = 0.0,
    String category = 'General Store',
  }) async {
    final cleanBarcode = barcode.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Item $cleanBarcode';
    if (cleanBarcode.isEmpty || price < 0) return false;

    try {
      final newProduct = ProductModel(
        id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        barcode: cleanBarcode,
        sku: cleanBarcode,
        price: price,
        comparePrice: mrp > 0 ? mrp : price,
        stock: 999,
        category: category,
        unit: 'piece',
        isActive: true,
      );

      // 1. Add to local memory catalog for instant subsequent scans
      _products.insert(0, newProduct);
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
        'mrp': mrp > 0 ? mrp : price,
        'stock': 999,
        'category': category,
        'unit': 'piece',
        'is_active': true,
      };

      final sessionToken = TokenStorage.getToken();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        ProductRepository().createProduct(productData).then((res) {
          if (res.success && res.data != null) {
            final idx = _products.indexWhere((p) => p.barcode == cleanBarcode);
            if (idx >= 0) {
              _products[idx] = res.data!;
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
    if (_cart.isEmpty) {
      setError(TokenStorage.getLanguage() == 'hi' ? 'बिल कार्ट खाली है, कृपया पहले आइटम जोड़ें' : 'Bill Cart is empty, please scan or add items first');
      return null;
    }

    if (_paymentMethod == 'khata' && _customerPhone.trim().length < 10) {
      setError(TokenStorage.getLanguage() == 'hi' ? 'उधार बिलिंग के लिए 10 अंकों का मोबाइल नंबर आवश्यक है' : '10-digit customer mobile required for credit billing');
      return null;
    }

    setLoading(true);
    clearError();

    PosSplitPayment? split;
    if (_paymentMethod == 'split') {
      split = PosSplitPayment(
        cashAmount: _splitCashAmount,
        onlineAmount: splitUpiAmount,
      );
    }

    final response = await _repo.createSale(
      customerPhone: _customerPhone,
      customerName: _customerName,
      items: _cart,
      discountAmount: _discount,
      paymentMethod: _paymentMethod,
      splitPayments: split,
    );
    setLoading(false);

    if (response.success && response.data != null) {
      final billedToken = _currentActiveToken;
      _lastCompletedSale = response.data;
      await LocalCacheService.saveCompletedSale(_lastCompletedSale!);
      _serverSales.insert(0, _lastCompletedSale!);

      // Delete the billed running basket from GoBackend so all devices clear it immediately
      try {
        await _repo.deleteParkedBill(billedToken);
      } catch (_) {}
      _activeBaskets.removeWhere((b) => b.label.toUpperCase() == billedToken.toUpperCase());

      clearCart(syncWithBackend: false);
      fetchBackendSales();
      notifyListeners();

      // Emit event-driven invalidation events
      AppEventBus().emit(AppCacheEventType.posSaleCompleted, payload: _lastCompletedSale);
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      if (_paymentMethod == 'khata') {
        AppEventBus().emit(AppCacheEventType.khataMutated);
      }
      return _lastCompletedSale;
    } else {
      // Offline fallback: generate local offline bill and queue for background sync
      final now = DateTime.now();
      final offlineBillNum = 'OFF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

      _lastCompletedSale = SaleModel(
        billNumber: offlineBillNum,
        customerPhone: _customerPhone,
        items: List.from(_cart),
        subtotal: subtotal,
        discountAmount: _discount,
        totalAmount: grandTotal,
        paymentMethod: _paymentMethod,
        splitPayments: split,
        createdAt: now,
      );

      await LocalCacheService.saveCompletedSale(_lastCompletedSale!);
      _serverSales.insert(0, _lastCompletedSale!);

      // Enqueue to OfflineSyncService for background reconciliation
      await OfflineSyncService.instance.enqueue(
        action: SyncActionType.posSale,
        endpoint: ApiConstants.posSale,
        method: 'POST',
        payload: {
          'customer_phone': _customerPhone,
          'customer_name': _customerName,
          'items': _cart.map((e) => e.toJson()).toList(),
          'discount_amount': _discount,
          'payment_method': _paymentMethod,
          if (split != null) 'split_payments': split.toJson(),
        },
        title: 'POS Bill #$offlineBillNum',
        amount: grandTotal,
      );

      final billedToken = _currentActiveToken;
      _activeBaskets.removeWhere((b) => b.label.toUpperCase() == billedToken.toUpperCase());
      clearCart(syncWithBackend: false);
      notifyListeners();

      AppEventBus().emit(AppCacheEventType.posSaleCompleted, payload: _lastCompletedSale);
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      if (_paymentMethod == 'khata') {
        AppEventBus().emit(AppCacheEventType.khataMutated);
      }
      return _lastCompletedSale;
    }
  }

  /// 🖨️ Generate 58mm / 80mm Printable Thermal Receipt PDF Engine
  Future<void> generateThermalReceiptPdf(BuildContext context, SaleModel sale, String shopName) async {
    final PosRepository posRepo = PosRepository();
    if (sale.billNumber != null && sale.billNumber!.isNotEmpty) {
      try {
        final res = await posRepo.getReceiptPdfUrl(sale.billNumber!);
        if (res.success && res.data != null && res.data!.isNotEmpty) {
          final uri = Uri.parse(res.data!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
      } catch (_) {}
    }

    // Clean 58mm / 80mm Thermal Receipt HTML Print Engine
    final dateStr = AppDateTimeUtils.formatDateTime(sale.createdAt, includeYear: true);
    String htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Thermal Receipt #${sale.billNumber ?? "1001"}</title>
      <style>
        body { font-family: 'Courier New', Courier, monospace; width: 280px; margin: 0 auto; padding: 10px; color: #000; }
        .center { text-align: center; }
        .bold { font-weight: bold; }
        .line { border-bottom: 1px dashed #000; margin: 8px 0; }
        table { width: 100%; border-collapse: collapse; font-size: 12px; }
        td { padding: 3px 0; }
        .right { text-align: right; }
        .no-print { margin-bottom: 12px; text-align: center; }
        @media print { .no-print { display: none; } }
      </style>
    </head>
    <body>
      <div class="no-print">
        <button onclick="window.print()" style="background:#000;color:#fff;border:none;padding:8px 14px;border-radius:4px;font-weight:bold;cursor:pointer;">🖨️ Print Receipt</button>
      </div>
      <div class="center bold" style="font-size: 16px;">$shopName</div>
      <div class="center" style="font-size: 11px;">RETAIL POS BILL INVOICE</div>
      <div class="line"></div>
      <div style="font-size: 11px;">
        Bill #: ${sale.billNumber ?? "1001"}<br>
        Date: $dateStr<br>
        Pay Mode: ${sale.paymentMethod.toUpperCase()}<br>
        ${sale.customerPhone.isNotEmpty ? "Customer: ${sale.customerPhone}<br>" : ""}
      </div>
      <div class="line"></div>
      <table>
        <thead>
          <tr class="bold">
            <td style="width:50%;">ITEM</td>
            <td class="center" style="width:20%;">QTY</td>
            <td class="right" style="width:30%;">PRICE</td>
          </tr>
        </thead>
        <tbody>
    ''';

    for (final item in sale.items) {
      htmlContent += '''
        <tr>
          <td>${item.product.name}</td>
          <td class="center">${item.quantity}</td>
          <td class="right">₹${item.total.toStringAsFixed(0)}</td>
        </tr>
      ''';
    }

    htmlContent += '''
        </tbody>
      </table>
      <div class="line"></div>
      <table>
        <tr><td>Subtotal:</td><td class="right">₹${sale.subtotal.toStringAsFixed(2)}</td></tr>
        ${sale.discountAmount > 0 ? '<tr><td>Discount:</td><td class="right">-₹${sale.discountAmount.toStringAsFixed(2)}</td></tr>' : ''}
        <tr class="bold" style="font-size: 14px;"><td>TOTAL:</td><td class="right">₹${sale.totalAmount.toStringAsFixed(2)}</td></tr>
      </table>
      <div class="line"></div>
      <div class="center bold" style="font-size: 12px; margin-top: 10px;">THANK YOU! VISIT AGAIN</div>
    </body>
    </html>
    ''';

    final uri = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: Encoding.getByName('utf-8'));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

}
