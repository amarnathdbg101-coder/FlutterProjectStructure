import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../products/models/product_model.dart';
import '../../products/repositories/product_repository.dart';
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

  /// 🖨️ 1-Tap Print-Ready Mandi Procurement PDF Sheet Engine
  Future<void> generatePdfSheet(BuildContext context, String shopName) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mandi procurement list khali hai')),
      );
      return;
    }

    final pending = _items.where((i) => !i.isCompleted).toList();
    final target = pending.isNotEmpty ? pending : _items;

    final ProductRepository productRepo = ProductRepository();
    final requestItems = target.map((i) => {
      'name': i.name,
      'qty': i.qty,
      'category': i.category,
      'dealer': i.dealerName,
      'estimated_price': '₹${i.estimatedPrice.toStringAsFixed(0)}',
      'notes': i.notes,
    }).toList();

    try {
      final res = await productRepo.generateCustomProcurementPdf(
        title: '$shopName - Mandi Procurement Sheet',
        items: requestItems,
      );

      if (res.success && res.data != null) {
        final pdfUrl = res.data!['pdf_url']?.toString() ?? res.data!['url']?.toString();
        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          final uri = Uri.parse(pdfUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
      }
    } catch (_) {}

    // Clean HTML Print-Ready Fallback
    final dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    String htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Mandi Procurement Order Sheet</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; color: #0f172a; }
        .header { text-align: center; border-bottom: 2px solid #4f46e5; padding-bottom: 12px; margin-bottom: 20px; }
        .header h1 { margin: 0; color: #4f46e5; font-size: 22px; }
        .header p { margin: 4px 0 0 0; color: #64748b; font-size: 13px; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th, td { border: 1px solid #cbd5e1; padding: 10px; text-align: left; font-size: 13px; }
        th { background-color: #f1f5f9; font-weight: bold; }
        .total-row { font-weight: bold; background-color: #f8fafc; }
        @media print { .no-print { display: none; } }
      </style>
    </head>
    <body>
      <div class="no-print" style="margin-bottom: 16px;">
        <button onclick="window.print()" style="background:#4f46e5;color:white;border:none;padding:10px 18px;border-radius:6px;font-weight:bold;cursor:pointer;">🖨️ Print / Save as PDF</button>
      </div>
      <div class="header">
        <h1>🌾 $shopName - Mandi Procurement Order Sheet</h1>
        <p>Date: $dateStr • Total Items: ${target.length} • Est. Budget: ₹${totalEstimatedBudget.toStringAsFixed(0)}</p>
      </div>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Item Name</th>
            <th>Category</th>
            <th>Quantity / Weight</th>
            <th>Est Rate (₹)</th>
            <th>Dealer / Wholesaler</th>
          </tr>
        </thead>
        <tbody>
    ''';

    for (int i = 0; i < target.length; i++) {
      final item = target[i];
      htmlContent += '''
        <tr>
          <td>${i + 1}</td>
          <td><strong>${item.name}</strong></td>
          <td>${item.category}</td>
          <td>${item.qty}</td>
          <td>₹${item.estimatedPrice.toStringAsFixed(0)}</td>
          <td>${item.dealerName.isNotEmpty ? item.dealerName : '-'}</td>
        </tr>
      ''';
    }

    htmlContent += '''
        <tr class="total-row">
          <td colspan="4" style="text-align:right;">ESTIMATED TOTAL BUDGET:</td>
          <td colspan="2">₹${totalEstimatedBudget.toStringAsFixed(0)}</td>
        </tr>
        </tbody>
      </table>
    </body>
    </html>
    ''';

    final uri = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: Encoding.getByName('utf-8'));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
