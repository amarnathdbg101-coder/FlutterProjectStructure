import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../products/models/product_model.dart';
import '../models/pos_model.dart';
import '../repositories/pos_repository.dart';

class PosController extends BaseController {
  final PosRepository _repo = PosRepository();

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  PosController() {
    _initFromCache();
  }

  void _initFromCache() {
    final cached = LocalCacheService.getProducts();
    if (cached.isNotEmpty) {
      _products = cached;
    }
  }

  final List<PosCartItem> _cart = [];
  List<PosCartItem> get cart => List.unmodifiable(_cart);

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

  /// 24-Hour Sales Analytics Summary (Products Sold in last 24 hours)
  double get today24hRevenue {
    final sales24h = LocalCacheService.get24HourSales();
    return sales24h.fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get today24hBillCount {
    return LocalCacheService.get24HourSales().length;
  }

  List<Map<String, dynamic>> get24HourSoldProductsSummary() {
    final sales24h = LocalCacheService.get24HourSales();
    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final sale in sales24h) {
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

  void setCustomerPhone(String phone) {
    _customerPhone = phone;
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
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
    notifyListeners();
  }

  void updateCartItemPrice(PosCartItem item, double newPrice) {
    if (newPrice >= 0) {
      item.customPrice = newPrice;
      notifyListeners();
    }
  }

  void incrementQuantity(PosCartItem item) {
    item.quantity += 1;
    notifyListeners();
  }

  void decrementQuantity(PosCartItem item) {
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _cart.remove(item);
    }
    notifyListeners();
  }

  void removeFromCart(PosCartItem item) {
    _cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0.0;
    _customerPhone = '';
    _customerName = '';
    _cashTendered = 0.0;
    _paymentMethod = 'cash';
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
      setError(response.error ?? 'Failed to load products');
    }
  }

  Future<bool> scanAndAddToCart(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return false;

    // 1. Try local memory search first (0ms)
    final localMatch = _products.firstWhere(
      (p) => p.barcode.toLowerCase() == cleanBarcode.toLowerCase() ||
             p.sku.toLowerCase() == cleanBarcode.toLowerCase() ||
             p.name.toLowerCase() == cleanBarcode.toLowerCase(),
      orElse: () => ProductModel(id: '', name: '', price: 0, stock: 0, category: ''),
    );

    if (localMatch.id.toString().isNotEmpty) {
      addToCart(localMatch);
      return true;
    }

    // 2. Try repository API barcode scan
    final response = await _repo.scanBarcode(cleanBarcode);
    if (response.success && response.data != null) {
      addToCart(response.data!);
      return true;
    }
    return false;
  }

  Future<SaleModel?> completeSale() async {
    if (_cart.isEmpty) {
      setError('Cart is empty. Please scan or add items first.');
      return null;
    }

    if (_paymentMethod == 'khata' && _customerPhone.trim().length < 10) {
      setError('A valid 10-digit customer mobile number is required for Khata credit.');
      return null;
    }

    setLoading(true);
    clearError();

    final response = await _repo.createSale(
      customerPhone: _customerPhone,
      items: _cart,
      discountAmount: _discount,
      paymentMethod: _paymentMethod,
    );
    setLoading(false);

    if (response.success && response.data != null) {
      _lastCompletedSale = response.data;
      await LocalCacheService.saveCompletedSale(_lastCompletedSale!);
      clearCart();
      notifyListeners();
      return _lastCompletedSale;
    } else {
      // Local optimistic sale completed fallback
      final fallbackSale = SaleModel(
        billNumber: '100${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        customerPhone: _customerPhone,
        items: List.from(_cart),
        subtotal: subtotal,
        discountAmount: _discount,
        totalAmount: grandTotal,
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
      );
      _lastCompletedSale = fallbackSale;
      await LocalCacheService.saveCompletedSale(fallbackSale);
      clearCart();
      notifyListeners();
      return fallbackSale;
    }
  }
}
