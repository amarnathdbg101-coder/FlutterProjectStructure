import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../products/models/product_model.dart';
import '../models/procurement_model.dart';

class ProcurementController extends BaseController {
  List<ProcurementItemModel> _items = [];

  List<ProcurementItemModel> get items => _items;
  int get totalCount => _items.length;
  int get completedCount => _items.where((i) => i.isCompleted).length;
  int get pendingCount => totalCount - completedCount;

  double get totalEstimatedBudget => _items.fold(0.0, (sum, i) => sum + i.itemEstimatedCost);
  double get completedPurchasedExpense => _items.where((i) => i.isCompleted).fold(0.0, (sum, i) => sum + i.itemActualCost);
  double get pendingProcurementCost => totalEstimatedBudget - completedPurchasedExpense;

  ProcurementController() {
    _hydrateFromLocalCache();
  }

  void _hydrateFromLocalCache() {
    _items = LocalCacheService.getProcurementItems();
    notifyListeners();
  }

  Future<void> _persistCache() async {
    await LocalCacheService.saveProcurementItems(_items);
  }

  void addItem({
    required String name,
    required String qty,
    String category = 'General Store',
    double estimatedPrice = 0.0,
    double actualPrice = 0.0,
    String dealerName = '',
    String dealerPhone = '',
    String notes = '',
  }) {
    final newItem = ProcurementItemModel(
      id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      qty: qty.trim().isEmpty ? '1' : qty.trim(),
      estimatedPrice: estimatedPrice,
      actualPrice: actualPrice,
      dealerName: dealerName.trim(),
      dealerPhone: dealerPhone.trim(),
      notes: notes.trim(),
    );
    _items.insert(0, newItem);
    _persistCache();
    notifyListeners();
  }

  void toggleItem(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].isCompleted = !_items[idx].isCompleted;
      _persistCache();
      notifyListeners();
    }
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    _persistCache();
    notifyListeners();
  }

  void clearAllCompleted() {
    _items.removeWhere((i) => i.isCompleted);
    _persistCache();
    notifyListeners();
  }

  /// Dynamically imports REAL low-stock products from inventory (NO hardcoded data!)
  void importLowStockProducts(List<ProductModel> lowStockProducts) {
    int importedCount = 0;
    for (var prod in lowStockProducts) {
      if (!_items.any((i) => i.name.toLowerCase() == prod.name.toLowerCase())) {
        final reorderQty = '${prod.lowStockThreshold * 2} ${prod.unit}s';
        final estRate = prod.costPrice > 0 ? prod.costPrice : prod.price;

        _items.insert(
          0,
          ProcurementItemModel(
            id: 'pr_${DateTime.now().millisecondsSinceEpoch}_${prod.id}',
            name: prod.name,
            category: prod.category,
            qty: reorderQty,
            estimatedPrice: estRate,
            notes: 'Auto-imported from Low Stock Alert',
          ),
        );
        importedCount++;
      }
    }
    if (importedCount > 0) {
      _persistCache();
      notifyListeners();
    }
  }
}
