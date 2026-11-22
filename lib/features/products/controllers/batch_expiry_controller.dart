import 'package:flutter/widgets.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../pos/models/pos_features_model.dart';
import '../../pos/repositories/pos_advanced_repository.dart';
import '../models/product_model.dart';
import '../services/expiry_audit_pdf_service.dart';

enum ExpiryUrgency {
  expired,   // daysRemaining < 0
  critical,  // 0 <= daysRemaining <= 7
  warning,   // 8 <= daysRemaining <= 30
  upcoming,  // daysRemaining > 30
}

/// A unified item representing an expiry-tracked product (from inventory or batch lot)
class ExpiryTrackedItem {
  final String id;
  final String? productId;
  final String name;
  final String category;
  final String barcode;
  final String? imageUrl;
  final String? batchNumber;
  final DateTime expiryDate;
  final int daysRemaining;
  final double stockQuantity;
  final String unit;
  final double mrp;
  final double purchaseCost;
  final double markdownDiscount;
  final bool isBatchLot;
  final ProductModel? product;
  final ProductBatch? batch;

  const ExpiryTrackedItem({
    required this.id,
    this.productId,
    required this.name,
    required this.category,
    required this.barcode,
    this.imageUrl,
    this.batchNumber,
    required this.expiryDate,
    required this.daysRemaining,
    required this.stockQuantity,
    this.unit = 'Pcs',
    required this.mrp,
    this.purchaseCost = 0.0,
    this.markdownDiscount = 0.0,
    required this.isBatchLot,
    this.product,
    this.batch,
  });

  ExpiryUrgency get urgency {
    if (daysRemaining < 0) return ExpiryUrgency.expired;
    if (daysRemaining <= 7) return ExpiryUrgency.critical;
    if (daysRemaining <= 30) return ExpiryUrgency.warning;
    return ExpiryUrgency.upcoming;
  }

  bool get isExpired => daysRemaining < 0;
  bool get isCritical => !isExpired && daysRemaining <= 7;
  bool get isWarning => !isExpired && daysRemaining > 7 && daysRemaining <= 30;
  bool get isUpcoming => daysRemaining > 30;
}

class BatchExpiryController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  List<ProductBatch> _batches = [];
  List<ProductBatch> get batches => List.unmodifiable(_batches);

  List<ProductModel> _inventoryProducts = [];
  List<ProductModel> get inventoryProducts => List.unmodifiable(_inventoryProducts);

  MarkdownScanResult? _lastScanResult;
  MarkdownScanResult? get lastScanResult => _lastScanResult;

  int _selectedDaysWindow = 30;
  int get selectedDaysWindow => _selectedDaysWindow;

  bool _isScanningMarkdown = false;
  bool get isScanningMarkdown => _isScanningMarkdown;

  /// Sync full inventory products so all products with expiry dates show up immediately
  void syncInventoryProducts(List<ProductModel> products) {
    _inventoryProducts = products;
    notifyListeners();
  }

  void setDaysWindow(int days) {
    _selectedDaysWindow = days;
    loadNearExpiry(days: days);
  }

  Future<void> loadNearExpiry({int? days}) async {
    final window = days ?? _selectedDaysWindow;
    setLoading(true);
    final res = await _repo.listNearExpiryBatches(days: window);
    setLoading(false);

    if (res.success && res.data != null) {
      _batches = res.data!;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load near-expiry lots');
    }
  }

  /// All expiry tracked items combined from inventory catalog + batch lots
  List<ExpiryTrackedItem> get allTrackedItems {
    final Map<String, ExpiryTrackedItem> itemsMap = {};

    // 1. Process all inventory products that have an expiryDate attribute
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final p in _inventoryProducts) {
      final exp = p.expiryDate;
      if (exp == null) continue;

      final expDay = DateTime(exp.year, exp.month, exp.day);
      final days = expDay.difference(today).inDays;
      final key = 'prod_${p.id ?? p.name}';

      itemsMap[key] = ExpiryTrackedItem(
        id: key,
        productId: p.id?.toString(),
        name: p.name.trim().isNotEmpty ? p.name.trim() : 'Unknown Product',
        category: p.category.trim().isNotEmpty ? p.category.trim() : 'General Store',
        barcode: p.barcode,
        imageUrl: p.imageUrl,
        batchNumber: p.batchNo.isNotEmpty ? p.batchNo : null,
        expiryDate: exp,
        daysRemaining: days,
        stockQuantity: p.stock.toDouble(),
        unit: p.unit.trim().isNotEmpty ? p.unit.trim() : 'Pcs',
        mrp: p.price,
        purchaseCost: p.costPrice,
        markdownDiscount: 0.0,
        isBatchLot: false,
        product: p,
      );
    }

    // 2. Process all POS batches
    for (final b in _batches) {
      final key = 'batch_${b.id}';
      ProductModel? matchedProduct;
      try {
        matchedProduct = _inventoryProducts.firstWhere(
          (p) => p.id?.toString() == b.productId,
        );
      } catch (_) {
        matchedProduct = null;
      }

      itemsMap[key] = ExpiryTrackedItem(
        id: key,
        productId: b.productId,
        name: b.productName.trim().isNotEmpty ? b.productName.trim() : (matchedProduct?.name ?? 'Lot Product'),
        category: matchedProduct?.category.trim().isNotEmpty == true ? matchedProduct!.category.trim() : 'General Store',
        barcode: matchedProduct?.barcode ?? '',
        imageUrl: matchedProduct?.imageUrl,
        batchNumber: b.batchNumber,
        expiryDate: b.expiryDate,
        daysRemaining: b.daysToExpiry,
        stockQuantity: b.currentQuantity,
        unit: matchedProduct?.unit.trim().isNotEmpty == true ? matchedProduct!.unit.trim() : 'Pcs',
        mrp: b.mrp > 0 ? b.mrp : (matchedProduct?.price ?? 0.0),
        purchaseCost: b.purchaseCost,
        markdownDiscount: b.markdownDiscount,
        isBatchLot: true,
        product: matchedProduct,
        batch: b,
      );
    }

    final list = itemsMap.values.toList();
    // Sort: Nearest expiry first (Expired < 0 first, then 0d, 1d, 2d...)
    list.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return list;
  }

  // Summary Counts
  int get totalCount => allTrackedItems.length;
  int get expiredCount => allTrackedItems.where((i) => i.isExpired).length;
  int get criticalCount => allTrackedItems.where((i) => i.isCritical).length;
  int get warningCount => allTrackedItems.where((i) => i.isWarning).length;
  int get upcomingCount => allTrackedItems.where((i) => i.isUpcoming).length;

  /// Total capital locked in expiring inventory (<= 30 days or expired)
  double get capitalAtRisk30D {
    return allTrackedItems
        .where((i) => i.daysRemaining <= 30)
        .fold(0.0, (sum, i) => sum + (i.stockQuantity * (i.purchaseCost > 0 ? i.purchaseCost : i.mrp * 0.7)));
  }

  /// Capital lost in expired dead stock (< 0 days)
  double get expiredCapitalLost {
    return allTrackedItems
        .where((i) => i.isExpired)
        .fold(0.0, (sum, i) => sum + (i.stockQuantity * (i.purchaseCost > 0 ? i.purchaseCost : i.mrp * 0.7)));
  }

  /// Critical capital at risk in the next 0-7 days
  double get criticalCapitalAtRisk {
    return allTrackedItems
        .where((i) => i.isCritical)
        .fold(0.0, (sum, i) => sum + (i.stockQuantity * (i.purchaseCost > 0 ? i.purchaseCost : i.mrp * 0.7)));
  }

  /// Warning capital at risk in 8-30 days
  double get warningCapitalAtRisk {
    return allTrackedItems
        .where((i) => i.isWarning)
        .fold(0.0, (sum, i) => sum + (i.stockQuantity * (i.purchaseCost > 0 ? i.purchaseCost : i.mrp * 0.7)));
  }

  /// Estimated potential sales revenue if liquidated
  double get potentialClearanceRevenue {
    return allTrackedItems
        .where((i) => i.daysRemaining <= 30 && !i.isExpired)
        .fold(0.0, (sum, i) => sum + (i.stockQuantity * i.mrp));
  }

  /// Filtered and sorted items based on active screen criteria
  List<ExpiryTrackedItem> getFilteredItems({
    String filter = 'all', // 'all', 'expired', '7_days', '30_days', '60_days', 'safe'
    String searchQuery = '',
    String category = 'All',
    String sortOrder = 'expiry_asc', // 'expiry_asc', 'expiry_desc', 'stock_desc', 'name_asc'
  }) {
    var items = allTrackedItems;

    // Filter by urgency window
    if (filter == 'expired') {
      items = items.where((i) => i.isExpired).toList();
    } else if (filter == '7_days') {
      items = items.where((i) => !i.isExpired && i.daysRemaining <= 7).toList();
    } else if (filter == '30_days') {
      items = items.where((i) => !i.isExpired && i.daysRemaining <= 30).toList();
    } else if (filter == '60_days') {
      items = items.where((i) => !i.isExpired && i.daysRemaining <= 60).toList();
    } else if (filter == 'safe') {
      items = items.where((i) => i.daysRemaining > 30).toList();
    }

    // Filter by category
    if (category != 'All' && category.isNotEmpty) {
      items = items.where((i) => i.category.toLowerCase().contains(category.toLowerCase())).toList();
    }

    // Filter by query (name, barcode, batch number)
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      items = items.where((i) {
        final nameMatch = i.name.toLowerCase().contains(q);
        final barMatch = i.barcode.toLowerCase().contains(q);
        final batchMatch = (i.batchNumber ?? '').toLowerCase().contains(q);
        final catMatch = i.category.toLowerCase().contains(q);
        return nameMatch || barMatch || batchMatch || catMatch;
      }).toList();
    }

    // Sort order
    if (sortOrder == 'expiry_desc') {
      items.sort((a, b) => b.daysRemaining.compareTo(a.daysRemaining));
    } else if (sortOrder == 'stock_desc') {
      items.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
    } else if (sortOrder == 'name_asc') {
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // default: expiry_asc (expired first, then 0d, 1d, etc.)
      items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    }

    return items;
  }

  Future<bool> createBatch({
    required String productId,
    required String productName,
    required String batchNumber,
    required DateTime expiryDate,
    required double initialQuantity,
    required double purchaseCost,
    required double mrp,
  }) async {
    setLoading(true);
    final res = await _repo.createProductBatch({
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'initial_quantity': initialQuantity,
      'purchase_cost': purchaseCost,
      'mrp': mrp,
    });
    setLoading(false);

    if (res.success && res.data != null) {
      _batches.insert(0, res.data!);
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'लॉट #$batchNumber सफलतापूर्वक जोड़ा गया');
      return true;
    } else {
      setError(res.error ?? 'Failed to register product batch');
      return false;
    }
  }

  Future<MarkdownScanResult?> runMarkdownScan() async {
    _isScanningMarkdown = true;
    notifyListeners();

    final res = await _repo.runMarkdownScan();
    _isScanningMarkdown = false;

    if (res.success && res.data != null) {
      _lastScanResult = res.data;
      await loadNearExpiry();
      CustomSnackbar.showSuccess(
        null,
        '${_lastScanResult!.markdownsApplied} एक्सपायरी लॉट पर क्लियरेंस छूट लागू की गई!',
      );
      return _lastScanResult;
    } else {
      setError(res.error ?? 'Failed to execute markdown scan');
      return null;
    }
  }

  /// Apply clearance markdown discount to a specific batch lot
  Future<bool> applyBatchClearance({
    required String batchId,
    required double markdownPercent,
    double? customPrice,
  }) async {
    setLoading(true);
    final res = await _repo.applyBatchMarkdown(batchId, markdownPercent, customPrice: customPrice);
    setLoading(false);

    if (res.success && res.data != null) {
      final updated = res.data!;
      final idx = _batches.indexWhere((b) => b.id == batchId);
      if (idx != -1) {
        _batches[idx] = updated;
      }
      notifyListeners();
      return true;
    } else {
      setError(res.error ?? 'Failed to apply markdown');
      return false;
    }
  }

  /// Write off expired batch (disposal or return to wholesaler)
  Future<bool> writeOffBatch({
    required String batchId,
    required int quantity,
    required String reason,
  }) async {
    setLoading(true);
    final res = await _repo.writeOffBatch(batchId, quantity, reason);
    setLoading(false);

    if (res.success && res.data != null) {
      final updated = res.data!;
      final idx = _batches.indexWhere((b) => b.id == batchId);
      if (idx != -1) {
        if (updated.currentQuantity <= 0) {
          _batches.removeAt(idx);
        } else {
          _batches[idx] = updated;
        }
      }
      notifyListeners();
      return true;
    } else {
      setError(res.error ?? 'Failed to write off batch');
      return false;
    }
  }

  /// Export printable PDF stock audit checklist
  Future<void> exportAuditSheet({
    required BuildContext context,
    String shopName = 'Shop Silo Retail Store',
    bool isHindi = true,
  }) async {
    try {
      await ExpiryAuditPdfService.printOrShareAuditPdf(
        items: allTrackedItems,
        totalCapitalAtRisk: capitalAtRisk30D,
        expiredCapitalLost: expiredCapitalLost,
        shopName: shopName,
      );
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'PDF जनरेट करने में त्रुटि: $e');
      }
    }
  }
}
