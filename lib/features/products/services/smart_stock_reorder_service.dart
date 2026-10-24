import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../procurement/models/procurement_model.dart';
import '../models/product_model.dart';

/// Service for calculating smart stock restock quantities and seamlessly
/// auto-syncing low stock inventory items with wholesale procurement reorder lists.
class SmartStockReorderService {
  /// Calculate realistic recommended reorder units based on low-stock threshold
  static int getRecommendedReorderQuantity(ProductModel product) {
    if (product.lowStockThreshold > 0) {
      final recommended = product.lowStockThreshold * 2;
      return recommended < 5 ? 5 : recommended;
    }
    return 10;
  }

  /// 1-Tap Add single product to Wholesale Procurement Reorder List
  static Future<bool> addToProcurementList(
    BuildContext context,
    ProductModel product, {
    int? reorderQuantity,
    bool showToast = true,
  }) async {
    final qty = reorderQuantity ?? getRecommendedReorderQuantity(product);
    final items = LocalCacheService.getProcurementItems();
    final existingIdx = items.indexWhere(
      (i) => i.name.trim().toLowerCase() == product.name.trim().toLowerCase(),
    );

    final estPrice = product.costPrice > 0 ? product.costPrice : product.price;
    final qtyStr = '$qty ${product.unit}s';

    if (existingIdx != -1) {
      // Update quantity if already in procurement
      final cur = items[existingIdx];
      items[existingIdx] = ProcurementItemModel(
        id: cur.id,
        name: cur.name,
        category: product.category.isNotEmpty ? product.category : cur.category,
        qty: qtyStr,
        estimatedPrice: estPrice,
        actualPrice: cur.actualPrice,
        dealerName: product.supplier.trim().isNotEmpty ? product.supplier.trim() : cur.dealerName,
        dealerPhone: cur.dealerPhone,
        notes: cur.notes.isNotEmpty ? cur.notes : 'Auto-reorder for low stock',
        isCompleted: false,
      );
    } else {
      // Insert new procurement item at top
      items.insert(
        0,
        ProcurementItemModel(
          id: 'pr_${DateTime.now().millisecondsSinceEpoch}_${product.id}',
          name: product.name.trim(),
          category: product.category,
          qty: qtyStr,
          estimatedPrice: estPrice,
          dealerName: product.supplier.trim().isNotEmpty ? product.supplier.trim() : '',
          notes: 'Auto-reorder for low stock',
        ),
      );
    }

    await LocalCacheService.saveProcurementItems(items);

    if (showToast && context.mounted) {
      final isHindi = context.isHindi;
      final msg = isHindi
          ? '✓ "${product.name}" ($qtyStr) ${context.tr('stock_reorder_toast_added')}'
          : '✓ "${product.name}" ($qtyStr) ${context.tr('stock_reorder_toast_added')}';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: context.tr('stock_reorder_view_btn'),
            textColor: Colors.white,
            onPressed: () {
              try {
                context.push('/merchant/procurement');
              } catch (_) {}
            },
          ),
        ),
      );
    }

    return true;
  }

  /// 1-Tap Bulk Add all low stock products to Wholesale Procurement Reorder List
  static Future<int> addAllLowStockToProcurement(
    BuildContext context,
    List<ProductModel> lowStockProducts, {
    bool showToast = true,
  }) async {
    if (lowStockProducts.isEmpty) return 0;

    final items = LocalCacheService.getProcurementItems();
    int addedCount = 0;

    for (final product in lowStockProducts) {
      final exists = items.any(
        (i) => i.name.trim().toLowerCase() == product.name.trim().toLowerCase(),
      );

      if (!exists) {
        final qty = getRecommendedReorderQuantity(product);
        final estPrice = product.costPrice > 0 ? product.costPrice : product.price;

        items.insert(
          0,
          ProcurementItemModel(
            id: 'pr_${DateTime.now().millisecondsSinceEpoch}_${product.id}_$addedCount',
            name: product.name.trim(),
            category: product.category,
            qty: '$qty ${product.unit}s',
            estimatedPrice: estPrice,
            dealerName: product.supplier.trim().isNotEmpty ? product.supplier.trim() : '',
            notes: 'Auto-reorder from Low Stock Alert',
          ),
        );
        addedCount++;
      }
    }

    if (addedCount > 0) {
      await LocalCacheService.saveProcurementItems(items);
    }

    if (showToast && context.mounted) {
      final isHindi = context.isHindi;
      final msg = isHindi
          ? '✓ $addedCount सामान ${context.tr('stock_reorder_toast_bulk')}'
          : '✓ $addedCount items ${context.tr('stock_reorder_toast_bulk')}';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: context.tr('stock_reorder_view_btn'),
            textColor: Colors.white,
            onPressed: () {
              try {
                context.push('/merchant/procurement');
              } catch (_) {}
            },
          ),
        ),
      );
    }

    return addedCount;
  }

  /// Format an executive supplier wholesale purchase order message (pure bilingual, zero vegetable imagery)
  static String formatSupplierOrderMessage({
    required List<ProductModel> products,
    required String shopName,
    required bool isHindi,
  }) {
    final cleanShop = shopName.trim().isNotEmpty ? shopName.trim() : 'ShopSilo Partner Store';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final buffer = StringBuffer();
    double totalEstCost = 0.0;

    if (isHindi) {
      buffer.writeln('📦 *थोक खरीद ऑर्डर (Wholesale Purchase Order)*');
      buffer.writeln('दुकान: *$cleanShop*');
      buffer.writeln('दिनांक: $dateStr');
      buffer.writeln('----------------------------------');
      buffer.writeln();

      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        final qty = getRecommendedReorderQuantity(p);
        final rate = p.costPrice > 0 ? p.costPrice : p.price;
        final lineTotal = rate * qty;
        totalEstCost += lineTotal;

        buffer.writeln('${i + 1}. *${p.name}*');
        buffer.writeln('   मात्रा: $qty ${p.unit}s | अनुमानित दर: ₹${rate.toStringAsFixed(0)}');
      }

      buffer.writeln();
      buffer.writeln('----------------------------------');
      buffer.writeln('कुल वस्तुएं: *${products.length}* | अनुमानित कुल: *₹${totalEstCost.toStringAsFixed(0)}*');
      buffer.writeln();
      buffer.writeln('कृपया इस ऑर्डर की पुष्टि करें और डिलीवरी का समय बताएं।');
      buffer.writeln('धन्यवाद!\n*$cleanShop*');
    } else {
      buffer.writeln('📦 *WHOLESALE PURCHASE ORDER*');
      buffer.writeln('Store: *$cleanShop*');
      buffer.writeln('Date: $dateStr');
      buffer.writeln('----------------------------------');
      buffer.writeln();

      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        final qty = getRecommendedReorderQuantity(p);
        final rate = p.costPrice > 0 ? p.costPrice : p.price;
        final lineTotal = rate * qty;
        totalEstCost += lineTotal;

        buffer.writeln('${i + 1}. *${p.name}*');
        buffer.writeln('   Qty: $qty ${p.unit}s | Est. Rate: ₹${rate.toStringAsFixed(0)}');
      }

      buffer.writeln();
      buffer.writeln('----------------------------------');
      buffer.writeln('Total Items: *${products.length}* | Est. Total: *₹${totalEstCost.toStringAsFixed(0)}*');
      buffer.writeln();
      buffer.writeln('Please confirm this order and dispatch timeline.');
      buffer.writeln('Thank you!\n*$cleanShop*');
    }

    return buffer.toString().trim();
  }

  /// Launch WhatsApp with supplier order message, with graceful clipboard fallback
  static Future<void> shareSupplierOrderOnWhatsApp({
    required BuildContext context,
    required String message,
    String? supplierPhone,
  }) async {
    final cleanPhone = supplierPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final formattedPhone = cleanPhone.isNotEmpty
        ? (cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone)
        : '';

    final urlString = formattedPhone.isNotEmpty
        ? 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(message)}';

    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback: Copy to clipboard
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isHindi
                ? 'ऑर्डर क्लिपबोर्ड पर कॉपी हो गया!'
                : 'Purchase order copied to clipboard!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}
