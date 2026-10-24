import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/product_controller.dart';
import '../services/smart_stock_reorder_service.dart';
import 'product_detail_screen.dart';

/// Dedicated Low Stock & Out of Stock Alerts Page.
/// Exclusively displays products where stock <= lowStockThreshold or stock <= 0.
/// Features 1-tap quick restock steppers, alert threshold limits, and instant catalog edits.
class LowStockAlertsScreen extends StatefulWidget {
  const LowStockAlertsScreen({super.key});

  @override
  State<LowStockAlertsScreen> createState() => _LowStockAlertsScreenState();
}

class _LowStockAlertsScreenState extends State<LowStockAlertsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prodController = context.watch<ProductController>();

    // Exclusively filter Low Stock & Out of Stock products
    final lowStockProducts = prodController.products.where((p) {
      final isAlert = p.isLowStock || p.isOutOfStock || p.stock <= p.lowStockThreshold;
      if (!isAlert) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchCategory = p.category.toLowerCase().contains(q);
        final matchSku = p.sku.toLowerCase().contains(q);
        final matchBarcode = p.barcode.toLowerCase().contains(q);
        if (!matchName && !matchCategory && !matchSku && !matchBarcode) return false;
      }

      return true;
    }).toList();

    return MerchantShell(
      currentIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: context.colorSurface,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: context.colorBorder,
              height: 1.0,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary, size: 22),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/merchant/inventory');
              }
            },
          ),
          title: Text(
            '⚠️ ${context.tr('low_stock_title')} (${lowStockProducts.length})',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colorTextPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh',
              onPressed: () async {
                await prodController.loadProducts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ ${context.tr('low_stock_refreshed')}'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await prodController.loadProducts();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: ResponsiveContainer(
                maxWidth: 960,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Low Stock Alert Header Banner
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      color: AppColors.warning.withValues(alpha: context.isDark ? 0.2 : 0.08),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${lowStockProducts.length} ${context.tr('low_stock_banner_title')}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('low_stock_banner_subtitle'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bulk Reorder & WhatsApp Share Action Bar
                    if (lowStockProducts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.playlist_add_rounded, size: 18),
                            label: Text(
                              context.tr('stock_reorder_bulk_btn'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              SmartStockReorderService.addAllLowStockToProcurement(context, lowStockProducts);
                            },
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 17, color: AppColors.success),
                            label: Text(
                              context.tr('stock_share_whatsapp_order'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              final auth = context.read<AuthController>();
                              final shopName = auth.shop?.name ?? '';
                              final msg = SmartStockReorderService.formatSupplierOrderMessage(
                                products: lowStockProducts,
                                shopName: shopName,
                                isHindi: context.isHindi,
                              );
                              SmartStockReorderService.shareSupplierOrderOnWhatsApp(
                                context: context,
                                message: msg,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Search Filter
                    AppProductSearchBar(
                      controller: _searchController,
                      hintText: context.tr('low_stock_search_hint'),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      onClear: () => setState(() => _searchQuery = ''),
                    ),
                    const SizedBox(height: 16),

                    // Products List
                    if (lowStockProducts.isEmpty) ...[
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.successLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '🎉 ${context.tr('low_stock_empty_title')}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.colorTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('low_stock_empty_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colorTextMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.white),
                              label: Text(
                                context.tr('low_stock_view_active'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => context.go('/merchant/inventory'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lowStockProducts.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final p = lowStockProducts[idx];
                          final isOutOfStock = p.stock <= 0;

                          final badgeColor = isOutOfStock ? AppColors.error : AppColors.warning;
                          final badgeBg = isOutOfStock ? context.colorErrorLight : context.colorWarningLight;
                          final statusText = isOutOfStock
                              ? '❌ ${context.tr('inv_status_out_of_stock')}'
                              : '⚠️ ${context.tr('inv_status_low_stock')} (${p.stock})';

                          return AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    // Product Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AppProductImage(
                                        imageUrl: p.imageUrl,
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.cover,
                                        fallbackIcon: Icons.inventory_2_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  p.name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: context.colorTextPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),

                                          Text(
                                            '${p.category} • SKU: ${p.sku.isNotEmpty ? p.sku : 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.colorTextMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 3),

                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 2,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                'Price: ₹${p.price.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              Text(
                                                '• ${context.tr('low_stock_alert_limit')}: ≤ ${p.lowStockThreshold} ${p.unit}s',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.colorTextMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Divider(height: 1, color: context.colorBorder),
                                const SizedBox(height: 10),

                                // Quick Restock Stepper Row
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      '${context.tr('stock_quick_restock')}:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextSecondary),
                                    ),
                                    const SizedBox(width: 8),

                                    // Stepper
                                    Container(
                                      decoration: BoxDecoration(
                                        color: context.colorSurfaceSubtle,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.colorBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, size: 16),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            onPressed: p.stock > 0
                                                ? () => prodController.adjustStock(p, -1)
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '${p.stock}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: context.colorTextPrimary,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, size: 16),
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            onPressed: () => prodController.adjustStock(p, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Quick Add Chips
                                    for (final count in [5, 10, 25])
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () async {
                                          await prodController.adjustStock(p, count);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('+$count ${p.unit} ${context.tr('low_stock_restock_added')} ${p.name}!'),
                                                backgroundColor: AppColors.success,
                                                duration: const Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: context.colorPrimaryLight,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            '+$count',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Card Bottom Actions: Wholesale Reorder & Edit
                                Row(
                                  children: [
                                    // 1-Tap Reorder to Wholesale Procurement List
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          backgroundColor: context.colorPrimaryLight.withValues(alpha: 0.4),
                                        ),
                                        icon: const Icon(Icons.playlist_add_rounded, size: 16, color: AppColors.primary),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${context.tr('stock_reorder_btn')} (+${SmartStockReorderService.getRecommendedReorderQuantity(p)})',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          SmartStockReorderService.addToProcurementList(context, p);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Edit Product Button
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(color: context.colorBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: Icon(Icons.edit_note_rounded, size: 16, color: context.colorTextPrimary),
                                      label: Text(
                                        context.tr('btn_edit'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: context.colorTextPrimary,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailScreen(product: p),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
