import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../products/models/product_model.dart';
import '../../products/repositories/product_repository.dart';
import '../models/procurement_model.dart';
import '../repositories/procurement_repository.dart';
import '../services/procurement_pdf_service.dart';

class ProcurementController extends BaseController {
  final ProcurementRepository _repo = ProcurementRepository();
  List<ProcurementItemModel> _items = [];

  List<ProcurementItemModel> get items => _items;
  int get totalCount => _items.length;
  int get completedCount => _items.where((i) => i.isCompleted).length;
  int get pendingCount => totalCount - completedCount;

  double get totalEstimatedBudget => _items.fold(0.0, (sum, i) => sum + i.itemEstimatedCost);
  double get completedPurchasedExpense => _items.where((i) => i.isCompleted).fold(0.0, (sum, i) => sum + i.itemActualCost);
  double get pendingProcurementCost => totalEstimatedBudget - completedPurchasedExpense;

  StreamSubscription<AppCacheEvent>? _logoutSub;
  StreamSubscription<AppCacheEvent>? _procurementSub;

  ProcurementController() {
    _hydrateFromLocalCache();
    fetchBackendProcurement();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _items = [];
      notifyListeners();
    });

    _procurementSub = AppEventBus().on(AppCacheEventType.procurementMutated, (_) {
      fetchBackendProcurement(silent: true);
    });
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    _procurementSub?.cancel();
    super.dispose();
  }

  void refreshList() {
    fetchBackendProcurement();
  }

  void _hydrateFromLocalCache() {
    _items = LocalCacheService.getProcurementItems();
    notifyListeners();
  }

  Future<void> _persistCache() async {
    await LocalCacheService.saveProcurementItems(_items);
  }

  /// Syncs procurement items with PostgreSQL backend database
  Future<void> fetchBackendProcurement({bool silent = false}) async {
    if (!silent && _items.isEmpty) setLoading(true);
    try {
      final res = await _repo.listProcurementItems();
      if (res.success && res.data != null) {
        _items = res.data!;
        await _persistCache();
        clearError();
      }
    } catch (e) {
      debugPrint('[Procurement] Backend sync failed, using offline cache: $e');
    } finally {
      if (!silent) setLoading(false);
      notifyListeners();
    }
  }

  Future<void> addItem({
    required String name,
    required String qty,
    String category = 'General Store',
    double estimatedPrice = 0.0,
    double actualPrice = 0.0,
    String dealerName = '',
    String dealerPhone = '',
    String notes = '',
  }) async {
    final tempId = 'pr_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = ProcurementItemModel(
      id: tempId,
      name: name.trim(),
      category: category,
      qty: qty.trim().isEmpty ? '1' : qty.trim(),
      estimatedPrice: estimatedPrice,
      actualPrice: actualPrice,
      dealerName: dealerName.trim(),
      dealerPhone: dealerPhone.trim(),
      notes: notes.trim(),
    );

    // 0ms Optimistic UI update
    _items.insert(0, newItem);
    await _persistCache();
    notifyListeners();

    // Persist to PostgreSQL backend in background
    try {
      final res = await _repo.createProcurementItem(
        name: name,
        qty: qty,
        category: category,
        estimatedPrice: estimatedPrice,
        actualPrice: actualPrice,
        dealerName: dealerName,
        dealerPhone: dealerPhone,
        notes: notes,
      );
      if (res.success && res.data != null) {
        final idx = _items.indexWhere((i) => i.id == tempId);
        if (idx != -1) {
          _items[idx] = res.data!;
          await _persistCache();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[Procurement] Cloud save failed, saved locally: $e');
    }
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required String qty,
    String category = 'General Store',
    double estimatedPrice = 0.0,
    double actualPrice = 0.0,
    String dealerName = '',
    String dealerPhone = '',
    String notes = '',
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final old = _items[idx];
      final updated = ProcurementItemModel(
        id: old.id,
        name: name.trim(),
        category: category,
        qty: qty.trim().isEmpty ? '1' : qty.trim(),
        estimatedPrice: estimatedPrice,
        actualPrice: actualPrice > 0 ? actualPrice : old.actualPrice,
        dealerName: dealerName.trim(),
        dealerPhone: dealerPhone.trim(),
        notes: notes.trim(),
        isCompleted: old.isCompleted,
        createdAt: old.createdAt,
      );
      _items[idx] = updated;
      await _persistCache();
      notifyListeners();

      // Cloud sync
      try {
        await _repo.updateProcurementItem(id, {
          'name': name.trim(),
          'qty': qty.trim(),
          'category': category.trim(),
          'estimated_price': estimatedPrice,
          'actual_price': actualPrice,
          'dealer_name': dealerName.trim(),
          'dealer_phone': dealerPhone.trim(),
          'notes': notes.trim(),
        });
      } catch (e) {
        debugPrint('[Procurement] Cloud update failed, saved locally: $e');
      }
    }
  }

  Future<void> toggleItem(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].isCompleted = !_items[idx].isCompleted;
      await _persistCache();
      notifyListeners();

      // Cloud sync
      try {
        await _repo.toggleProcurementItem(id);
      } catch (e) {
        debugPrint('[Procurement] Cloud toggle failed, saved locally: $e');
      }
    }
  }

  Future<void> removeItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _persistCache();
    notifyListeners();

    // Cloud sync
    try {
      await _repo.deleteProcurementItem(id);
    } catch (e) {
      debugPrint('[Procurement] Cloud delete failed: $e');
    }
  }

  Future<void> clearAllCompleted() async {
    _items.removeWhere((i) => i.isCompleted);
    await _persistCache();
    notifyListeners();

    // Cloud sync
    try {
      await _repo.clearCompleted();
    } catch (e) {
      debugPrint('[Procurement] Cloud clear completed failed: $e');
    }
  }

  /// Dynamically imports REAL low-stock products from inventory with cloud backup
  Future<void> importLowStockProducts(List<ProductModel> lowStockProducts) async {
    int importedCount = 0;
    for (var prod in lowStockProducts) {
      if (!_items.any((i) => i.name.toLowerCase() == prod.name.toLowerCase())) {
        final reorderQty = '${prod.lowStockThreshold * 2} ${prod.unit}s';
        final estRate = prod.costPrice > 0 ? prod.costPrice : prod.price;

        final item = ProcurementItemModel(
          id: 'pr_${DateTime.now().millisecondsSinceEpoch}_${prod.id}',
          name: prod.name,
          category: prod.category,
          qty: reorderQty,
          estimatedPrice: estRate,
          notes: 'Auto-imported from Low Stock Alert',
        );

        _items.insert(0, item);
        importedCount++;

        // Async cloud persist
        _repo.createProcurementItem(
          name: prod.name,
          qty: reorderQty,
          category: prod.category,
          estimatedPrice: estRate,
          notes: 'Auto-imported from Low Stock Alert',
        );
      }
    }
    if (importedCount > 0) {
      await _persistCache();
      notifyListeners();
    }
  }

  /// 📤 1-Tap Native Share Sheet (Bluetooth, WhatsApp, Instagram, Quick Share, etc.)
  Future<void> sharePdfSheet(BuildContext context, String shopName) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mandi procurement list is empty')),
      );
      return;
    }

    final pending = _items.where((i) => !i.isCompleted).toList();
    final target = pending.isNotEmpty ? pending : _items;

    final cachedShop = LocalCacheService.getShop();
    final effectiveShopName = shopName.trim().isNotEmpty && shopName.trim() != 'ShopSilo Merchant'
        ? shopName.trim()
        : (cachedShop?.name.trim().isNotEmpty ?? false
            ? cachedShop!.name.trim()
            : 'ShopSilo Partner Store');

    try {
      await ProcurementPdfService.shareProcurementSheet(
        shopName: effectiveShopName,
        items: target,
        totalBudget: totalEstimatedBudget,
        shopAddress: cachedShop?.address,
        shopPhone: cachedShop?.phone ?? cachedShop?.whatsappNumber,
      );
    } catch (err) {
      debugPrint('[Procurement] Share PDF failed: $err');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.isHindi ? 'मंडी लिस्ट शेयर करने में विफल: $err' : 'Failed to share mandi list: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🖨️ 1-Tap Mandi Procurement PDF Sheet Engine (Shares or Prints)
  Future<void> generatePdfSheet(BuildContext context, String shopName) async {
    await sharePdfSheet(context, shopName);
  }
}
