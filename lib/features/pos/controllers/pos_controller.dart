import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../products/models/product_model.dart';
import '../models/pos_model.dart';
import '../repositories/pos_repository.dart';

class PosController extends BaseController {
  final PosRepository _repo = PosRepository();

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

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

  PosController() {
    _initFromCache();
    loadCatalog();
    fetchBackendSales();
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
      final res = await _repo.getSales(date: date);
      if (res.success && res.data != null) {
        _serverSales = res.data!;
        await LocalCacheService.saveSalesList(_serverSales);
        notifyListeners();
      }
    } catch (_) {}
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
      setError(response.error ?? 'Products load nahi ho sake');
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
      setError('Bill Cart is empty, please scan or add items first');
      return null;
    }

    if (_paymentMethod == 'khata' && _customerPhone.trim().length < 10) {
      setError('10-digit customer mobile required for credit (khata) billing');
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
      _serverSales.insert(0, _lastCompletedSale!);
      clearCart();
      fetchBackendSales();
      notifyListeners();
      return _lastCompletedSale;
    } else {
      setError((response.message != null && response.message!.isNotEmpty)
          ? response.message!
          : 'Failed to record bill on server');
      notifyListeners();
      return null;
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
