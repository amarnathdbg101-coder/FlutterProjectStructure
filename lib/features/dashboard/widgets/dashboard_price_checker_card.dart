import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../../products/models/product_model.dart';
import '../../products/services/smart_barcode_catalog_service.dart';

/// Instant Counter Price & Stock Finder for Merchant Dashboard.
/// Designed specifically for fast customer price inquiries:
/// Shopkeeper scans a barcode or types a product name, and instantly
/// sees exact Selling Price, MRP, Savings, and Live Stock to quote to customer.
class DashboardPriceCheckerCard extends StatefulWidget {
  const DashboardPriceCheckerCard({super.key});

  @override
  State<DashboardPriceCheckerCard> createState() => _DashboardPriceCheckerCardState();
}

class _DashboardPriceCheckerCardState extends State<DashboardPriceCheckerCard> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ProductModel? _selectedProduct;
  List<ProductModel> _matchingProducts = [];
  SmartCatalogItem? _masterCatalogMatch;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim().toLowerCase();

    if (clean.isEmpty) {
      setState(() {
        _selectedProduct = null;
        _matchingProducts = [];
        _masterCatalogMatch = null;
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _lookupProduct(clean);
    });
  }

  void _lookupProduct(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    final allProducts = context.read<ProductController>().products;

    // 1. Exact Barcode Match (0ms priority)
    for (final p in allProducts) {
      if (p.barcode.trim().toLowerCase() == clean) {
        setState(() {
          _selectedProduct = p;
          _matchingProducts = [];
          _masterCatalogMatch = null;
          _hasSearched = true;
        });
        return;
      }
    }

    // 2. Exact SKU Match
    for (final p in allProducts) {
      if (p.sku.trim().toLowerCase() == clean) {
        setState(() {
          _selectedProduct = p;
          _matchingProducts = [];
          _masterCatalogMatch = null;
          _hasSearched = true;
        });
        return;
      }
    }

    // 3. Multi-token text search in Name & Brand
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final matches = allProducts.where((p) {
      final name = p.name.toLowerCase();
      final brand = p.brand.toLowerCase();
      final cat = p.category.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final sku = p.sku.toLowerCase();

      return tokens.every((token) =>
          name.contains(token) ||
          brand.contains(token) ||
          cat.contains(token) ||
          barcode.contains(token) ||
          sku.contains(token));
    }).take(4).toList();

    if (matches.length == 1 && (clean == matches.first.name.toLowerCase() || tokens.length >= 2)) {
      // Direct high-confidence match
      setState(() {
        _selectedProduct = matches.first;
        _matchingProducts = [];
        _masterCatalogMatch = null;
        _hasSearched = true;
      });
      return;
    }

    // 4. Fallback check in Master Barcode Catalog if numeric/barcode-like
    SmartCatalogItem? master;
    if (matches.isEmpty && RegExp(r'^\d{4,14}$').hasMatch(clean)) {
      master = SmartBarcodeCatalogService.lookupSync(clean);
    }

    setState(() {
      _selectedProduct = matches.isNotEmpty ? matches.first : null;
      _matchingProducts = matches.length > 1 ? matches : [];
      _masterCatalogMatch = master;
      _hasSearched = true;
    });
  }

  void _selectProduct(ProductModel p) {
    setState(() {
      _selectedProduct = p;
      _matchingProducts = [];
      _searchController.text = p.name;
    });
  }

  void _resetSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _selectedProduct = null;
      _matchingProducts = [];
      _masterCatalogMatch = null;
      _hasSearched = false;
    });
  }

  void _openCameraScanner(BuildContext context) {
    MobileBarcodeScannerDialog.show(
      context,
      title: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
      subtitle: context.isHindi ? 'ग्राहक को मूल्य बताने के लिए स्कैन करें' : 'Scan to instantly check price & stock',
      autoCloseOnSuccess: true,
      onBarcodeScanned: (barcode) async {
        final clean = barcode.trim();
        if (clean.isNotEmpty) {
          _searchController.text = clean;
          _lookupProduct(clean);
        }
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final p = _selectedProduct;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p != null
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.colorBorder,
          width: p != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.price_check_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'तुरंत भाव व स्टॉक जांचें' : 'Instant Price & Stock Checker',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.colorTextPrimary,
                      ),
                    ),
                    Text(
                      isHindi
                          ? 'ग्राहक को तुरंत सही रेट और स्टॉक बताने के लिए'
                          : 'Quickly quote exact price, MRP & stock to customer',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasSearched)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    isHindi ? 'रीसेट' : 'Clear',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _resetSearch,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Integrated Search & Scan Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: context.colorBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: context.colorTextMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colorTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: isHindi
                          ? 'बारकोड, SKU या नाम लिखें (उदा. Maggi, Oil)...'
                          : 'Type name, SKU or scan barcode...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: context.colorTextMuted,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: _resetSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close_rounded, size: 16, color: context.colorTextMuted),
                    ),
                  ),
                const SizedBox(width: 4),
                // Camera Barcode Scanner 1-Tap Trigger
                InkWell(
                  onTap: () => _openCameraScanner(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isHindi ? 'स्कैन' : 'Scan',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Multiple Matching Suggestions Chips (If user typed a broad word like "oil" or "soap")
          if (_matchingProducts.isNotEmpty && p != null) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _matchingProducts.map((match) {
                  final isSelected = match.id == p.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _selectProduct(match),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? context.colorPrimaryLight : context.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : context.colorBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              match.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? AppColors.primary : context.colorTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${match.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 🌟 RESULT DISPLAY 1: PRODUCT FOUND IN SHOP (HIGH-CONTRAST PRICE HERO CARD)
          if (p != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Thumbnail
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: context.colorSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.colorBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AppProductImage(
                          imageUrl: p.imageUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.inventory_2_outlined,
                          fallbackIconSize: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.brand.isNotEmpty)
                              Text(
                                p.brand.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.colorTextPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.category} ${p.barcode.isNotEmpty ? "• #${p.barcode}" : ""}',
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // PRICE HERO ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isHindi ? 'ग्राहक भाव: ' : 'Price: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextSecondary,
                        ),
                      ),
                      Text(
                        '₹${p.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (p.unit.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Text(
                          '/ ${p.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colorTextSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),

                      // LIVE STOCK BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: p.isOutOfStock
                              ? AppColors.errorLight
                              : (p.isLowStock ? AppColors.warning.withValues(alpha: 0.15) : AppColors.successLight),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: p.isOutOfStock
                                ? AppColors.error.withValues(alpha: 0.3)
                                : (p.isLowStock ? AppColors.warning.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Text(
                          p.isOutOfStock
                              ? (isHindi ? 'स्टॉक समाप्त' : 'Out of Stock')
                              : (isHindi ? 'स्टॉक: ${p.stock}' : 'Stock: ${p.stock} left'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: p.isOutOfStock
                                ? AppColors.error
                                : (p.isLowStock ? AppColors.warning : AppColors.success),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // MRP & SAVINGS CALCULATION (If Compare Price > Price)
                  if (p.comparePrice > p.price) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'MRP: ₹${p.comparePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.colorTextMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isHindi
                                ? '₹${(p.comparePrice - p.price).toStringAsFixed(0)} बचत (${(((p.comparePrice - p.price) / p.comparePrice) * 100).toStringAsFixed(0)}% OFF)'
                                : 'Save ₹${(p.comparePrice - p.price).toStringAsFixed(0)} (${(((p.comparePrice - p.price) / p.comparePrice) * 100).toStringAsFixed(0)}% OFF)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  // QUICK ACTION: IF CUSTOMER SAYS "THEEK HAI EK DE DO", 1-TAP ADD TO BILL!
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          label: Text(
                            isHindi ? 'बिल में जोड़ें (POS)' : 'Add to Active Bill (POS)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          onPressed: () {
                            context.read<PosController>().addToCart(p);
                            _resetSearch();
                            context.go('/merchant/pos');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isHindi ? '${p.name} बिल में जोड़ दिया गया!' : '${p.name} added to bill!'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _resetSearch,
                        child: Text(isHindi ? 'बंद करें' : 'Done', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]

          // 🌟 RESULT DISPLAY 2: MASTER CATALOG MATCH (NOT IN SHOP, BUT GLOBAL BRAND FOUND)
          else if (_masterCatalogMatch != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_masterCatalogMatch!.brand} ${_masterCatalogMatch!.name}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        Text(
                          isHindi
                            ? 'मास्टर MRP: ₹${_masterCatalogMatch!.mrp.toStringAsFixed(0)} (आपकी दुकान में नहीं है)'
                            : 'Standard MRP: ₹${_masterCatalogMatch!.mrp.toStringAsFixed(0)} (Not in your stock)',
                          style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final barcode = _searchController.text.trim();
                      _resetSearch();
                      context.push('/merchant/inventory?filter=add&barcode=$barcode');
                    },
                    child: Text(
                      isHindi ? '+ स्टॉक जोड़ें' : '+ Add Stock',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ]

          // 🌟 RESULT DISPLAY 3: ZERO MATCHES FOUND
          else if (_hasSearched && _searchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colorBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_off_rounded, size: 18, color: context.colorTextMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHindi
                          ? '"${_searchController.text.trim()}" दुकान में उपलब्ध नहीं है'
                          : 'No product found for "${_searchController.text.trim()}"',
                      style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetSearch,
                    child: Text(isHindi ? 'हटाएं' : 'Clear', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
