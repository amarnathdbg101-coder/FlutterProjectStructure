import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import 'inventory_screen.dart' show showAddProductDialog;
import 'product_detail_screen.dart';

/// Compact Products Register List Screen.
/// Designed for retail counters (Clothing & Cosmetic shops) where merchants
/// prefer a fast, vertical single-column register ledger view to quickly scan
/// product prices, stock counts, and edit details with minimal taps.
class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigateToDetail(ProductModel p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: p,
          onEditRequested: (ctx, item) => showAddProductDialog(ctx, initialProduct: item),
          onDuplicateRequested: (ctx, item) {
            Navigator.pop(ctx);
            showAddProductDialog(context, initialProduct: item, isDuplicate: true);
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(context.isHindi ? 'उत्पाद हटाएं' : 'Delete Product'),
        content: Text(
          context.isHindi
              ? 'क्या आप निश्चित हैं कि आप "${p.name}" को कैटलॉग से हटाना चाहते हैं?'
              : 'Are you sure you want to delete "${p.name}" from your catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ProductController>().deleteProduct(p.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.isHindi ? 'उत्पाद हटा दिया गया' : 'Product deleted successfully',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text(
              context.isHindi ? 'हटाएं' : 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodCtrl = context.watch<ProductController>();
    final allProducts = prodCtrl.products;

    // Filter by query (Name, Barcode, SKU, Category)
    final filtered = _searchQuery.isEmpty
        ? allProducts
        : allProducts.where((p) {
            final q = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                p.barcode.toLowerCase().contains(q) ||
                p.sku.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q);
          }).toList();

    final outOfStockCount = allProducts.where((p) => p.isOutOfStock).length;
    final lowStockCount = allProducts.where((p) => p.isLowStock).length;

    return Scaffold(
      backgroundColor: context.colorSurface,
      appBar: AppBar(
        backgroundColor: context.colorSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(fallbackRoute: '/merchant/inventory'),
        title: Text(
          context.isHindi ? 'सामान सूची (रजिस्टर व्यू)' : 'Products Register List',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.isHindi ? 'ताज़ा करें' : 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: context.colorTextPrimary, size: 22),
            onPressed: () => prodCtrl.loadProducts(forceRefresh: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.isHindi ? '+ नया सामान जोड़ें' : '+ Add Product',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
        onPressed: () => showAddProductDialog(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colorBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: context.isHindi
                        ? 'सामान, बारकोड या कैटेगरी से खोजें...'
                        : 'Search by name, barcode, or category...',
                    hintStyle: TextStyle(fontSize: 13, color: context.colorTextMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // Quick Status Filter Ribbon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${context.isHindi ? "कुल सामान" : "Total Products"}: ${filtered.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colorTextMuted,
                    ),
                  ),
                  const Spacer(),
                  if (outOfStockCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔴 $outOfStockCount ${context.isHindi ? "खत्म" : "out"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  if (lowStockCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🟠 $lowStockCount ${context.isHindi ? "कम स्टॉक" : "low"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: context.colorBorder),

            // Main Product Register List
            Expanded(
              child: prodCtrl.isLoading && allProducts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 56, color: context.colorTextMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? (context.isHindi ? 'कोई सामान नहीं मिला' : 'No matching products')
                                      : (context.isHindi ? 'कैटलॉग में कोई सामान नहीं है' : 'No products found'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.colorTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? (context.isHindi ? 'दूसरा नाम या बारकोड डालकर खोजें' : 'Try searching with a different term')
                                      : (context.isHindi ? 'नीचे बटन दबाकर पहला सामान जोड़ें' : 'Tap below to add your first product'),
                                  style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                                ),
                                const SizedBox(height: 16),
                                if (_searchQuery.isEmpty)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: Text(context.isHindi ? 'सामान जोड़ें' : 'Add Product'),
                                    onPressed: () => showAddProductDialog(context),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final stockColor = p.isOutOfStock
                                ? AppColors.error
                                : (p.isLowStock ? AppColors.warning : AppColors.success);

                            return InkWell(
                              onTap: () => _navigateToDetail(p),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.colorSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colorBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Product Image Thumbnail (46x46)
                                    Stack(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: context.colorBorder),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: AppProductImage(
                                              imageUrl: p.imageUrl,
                                              width: 46,
                                              height: 46,
                                              fit: BoxFit.contain,
                                              fallbackIcon: Icons.inventory_2_outlined,
                                              fallbackIconSize: 22,
                                            ),
                                          ),
                                        ),
                                        // Stock indicator dot
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: stockColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),

                                    // Product Info (Name, Barcode, Category)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                              color: context.colorTextPrimary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              if (p.barcode.isNotEmpty) ...[
                                                Text(
                                                  p.barcode,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: context.colorTextMuted,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text('•', style: TextStyle(fontSize: 10, color: context.colorTextMuted)),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  p.category,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: context.colorTextMuted,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Price & Stock Counter
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${p.price.toInt()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: stockColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p.isOutOfStock
                                                ? (context.isHindi ? 'खत्म' : 'Out')
                                                : '${p.stock} ${p.unit}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: stockColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Quick 3-Dot Menu
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded, color: context.colorTextSecondary, size: 20),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      color: context.colorSurface,
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          showAddProductDialog(context, initialProduct: p);
                                        } else if (val == 'delete') {
                                          _confirmDelete(context, p);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Text(ctx.isHindi ? 'विवरण बदलें' : 'Edit Details', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
