import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../pos/controllers/pos_controller.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import 'inventory_screen.dart' show showAddProductDialog;
import 'product_detail_screen.dart';

/// Clean, Fast, High-Performance Instant Price & Stock Checker Screen.
/// Designed for lightning-fast counter customer queries:
/// - Instant 0-latency Barcode / SKU / Name lookup
/// - High-contrast Selling Price & MRP Savings hero display
/// - Counter Privacy Shield: 1-Tap Toggle to hide Wholesale Margin from customers
/// - Category & Stock Filter Chips using Reusable Design System
/// - 1-Tap Actions: Add to POS Cart, Share on WhatsApp, Edit Product
class PriceCheckerScreen extends StatefulWidget {
  final String? initialBarcode;
  final String? initialQuery;

  const PriceCheckerScreen({super.key, this.initialBarcode, this.initialQuery});

  @override
  State<PriceCheckerScreen> createState() => _PriceCheckerScreenState();
}

class _PriceCheckerScreenState extends State<PriceCheckerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  ProductModel? _selectedProduct;
  List<ProductModel> _matchingProducts = [];
  bool _hasSearched = false;

  String _selectedCategory = 'All';
  String _selectedStockFilter =
      'All'; // 'All', 'In Stock', 'Low Stock', 'Discounted'
  bool _hideCostMargin = true; // Default to Counter Privacy Mode (hides wholesale cost from customer view)
  final List<ProductModel> _recentLookups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = widget.initialBarcode ?? widget.initialQuery;
      if (initial != null && initial.trim().isNotEmpty) {
        _searchController.text = initial.trim();
        _lookupProduct(initial.trim());
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim().toLowerCase();

    if (clean.isEmpty) {
      setState(() {
        _selectedProduct = null;
        _matchingProducts = [];
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 120), () {
      _lookupProduct(clean);
    });
  }

  void _lookupProduct(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    final allProducts = context.read<ProductController>().products;

    // Apply active category and stock filters if set
    List<ProductModel> candidates = allProducts;
    if (_selectedCategory != 'All') {
      candidates = candidates
          .where(
            (p) => p.category.toLowerCase() == _selectedCategory.toLowerCase(),
          )
          .toList();
    }
    if (_selectedStockFilter == 'In Stock') {
      candidates = candidates.where((p) => p.stock > 0).toList();
    } else if (_selectedStockFilter == 'Low Stock') {
      candidates = candidates
          .where((p) => p.stock > 0 && p.stock <= p.lowStockThreshold)
          .toList();
    } else if (_selectedStockFilter == 'Discounted') {
      candidates = candidates.where((p) => p.comparePrice > p.price).toList();
    }

    // 1. Exact Barcode Match (0ms instant)
    for (final p in candidates) {
      if (p.barcode.trim().toLowerCase() == clean) {
        _setFoundProduct(p);
        return;
      }
    }

    // 2. Exact SKU Match
    for (final p in candidates) {
      if (p.sku.trim().toLowerCase() == clean) {
        _setFoundProduct(p);
        return;
      }
    }

    // 3. Multi-token text matching across Name, Brand, Category, Barcode, SKU
    final tokens = clean
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final matches = candidates.where((p) {
      final name = p.name.toLowerCase();
      final brand = p.brand.toLowerCase();
      final cat = p.category.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final sku = p.sku.toLowerCase();

      return tokens.every(
        (token) =>
            name.contains(token) ||
            brand.contains(token) ||
            cat.contains(token) ||
            barcode.contains(token) ||
            sku.contains(token),
      );
    }).toList();

    setState(() {
      _hasSearched = true;
      _matchingProducts = matches;
      _selectedProduct = matches.isNotEmpty ? matches.first : null;
      if (_selectedProduct != null) {
        _addToRecentHistory(_selectedProduct!);
      }
    });
  }

  void _setFoundProduct(ProductModel p) {
    setState(() {
      _selectedProduct = p;
      _matchingProducts = [p];
      _hasSearched = true;
    });
    _addToRecentHistory(p);
  }

  void _addToRecentHistory(ProductModel p) {
    _recentLookups.removeWhere((item) => item.id == p.id);
    _recentLookups.insert(0, p);
    if (_recentLookups.length > 6) {
      _recentLookups.removeLast();
    }
  }

  void _selectProduct(ProductModel p) {
    setState(() {
      _selectedProduct = p;
    });
    _addToRecentHistory(p);
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _selectedProduct = null;
      _matchingProducts = [];
      _hasSearched = false;
    });
    _searchFocusNode.requestFocus();
  }

  void _openCameraScanner(BuildContext context) {
    MobileBarcodeScannerDialog.show(
      context,
      title: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
      subtitle: context.isHindi
          ? 'रेट व स्टॉक तुरंत जांचने के लिए बारकोड स्कैन करें'
          : 'Scan to instantly check price, MRP & live stock',
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

  void _addToPosCart(ProductModel p) {
    final pos = context.read<PosController>();
    pos.addToCart(p);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.isHindi
                    ? '${p.name} POS बिल में जोड़ा गया'
                    : '${p.name} added to POS Bill',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: context.isHindi ? 'POS देखें' : 'View POS',
          textColor: Colors.white,
          onPressed: () => context.go('/merchant/pos'),
        ),
      ),
    );
  }

  Future<void> _shareOnWhatsApp(ProductModel p) async {
    final authShop = context.read<AuthController>().currentShop;
    final shopName = authShop?.name.trim() ?? 'ShopSilo Store';
    final shopPhone = authShop?.phone.trim() ?? '';
    final isHindi = context.isHindi;

    final buffer = StringBuffer();
    buffer.writeln('🏪 *${shopName.toUpperCase()}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('📦 *${p.name}*');
    if (p.brand.isNotEmpty) buffer.writeln('🏷️ ब्रांड: ${p.brand}');
    buffer.writeln(
      '💰 *रेट (Price): ₹${p.price.toStringAsFixed(0)}* ${p.unit.isNotEmpty ? "/ ${p.unit}" : ""}',
    );
    if (p.comparePrice > p.price) {
      final savings = p.comparePrice - p.price;
      buffer.writeln(
        '🏷️ MRP: ~₹${p.comparePrice.toStringAsFixed(0)}~ (बचत: ₹${savings.toStringAsFixed(0)})',
      );
    }
    buffer.writeln(
      '📦 स्टॉक: ${p.stock > 0 ? "उपलब्ध (In Stock)" : "सम्पर्क करें"}',
    );
    if (shopPhone.isNotEmpty) buffer.writeln('📞 सम्पर्क: $shopPhone');
    buffer.writeln('--------------------------------');
    buffer.writeln(
      isHindi
          ? 'खरीदने हेतु काउंटर पर आएं या ऑर्डर करें!'
          : 'Visit counter to purchase or place order!',
    );

    final quoteText = buffer.toString();
    await WhatsAppShareHelper.shareToWhatsApp(
      context: context,
      message: quoteText,
    );
  }

  void _openEditProduct(ProductModel p) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)));
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final allProducts = context.watch<ProductController>().products;

    // Distinct Category List
    final Set<String> categories = {'All'};
    for (final p in allProducts) {
      if (p.category.trim().isNotEmpty) {
        categories.add(p.category.trim());
      }
    }

    final p = _selectedProduct;

    return MerchantShell(
      currentIndex: -1,
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: context.colorBorder, height: 1.0),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.colorTextPrimary,
            size: 22,
          ),
          tooltip: isHindi ? 'वापस जाएं' : 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/merchant');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi
                  ? 'तुरंत भाव व स्टॉक जांचें'
                  : 'Instant Price & Stock Checker',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: context.colorTextPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${allProducts.length} ${isHindi ? "कुल उत्पाद" : "Store Products"}',
              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
            ),
          ],
        ),
        actions: [
          // Privacy Shield: 1-Tap Toggle to hide Wholesale Profit Margin from customer view
          IconButton(
            icon: Icon(
              _hideCostMargin
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _hideCostMargin
                  ? AppColors.warning
                  : context.colorTextSecondary,
              size: 21,
            ),
            tooltip: _hideCostMargin
                ? (isHindi ? 'मार्जिन दिखाएं' : 'Show Margin')
                : (isHindi
                      ? 'मार्जिन छुपाएं (ग्राहक मोड)'
                      : 'Hide Margin (Customer View)'),
            onPressed: () {
              setState(() {
                _hideCostMargin = !_hideCostMargin;
              });
              HapticFeedback.selectionClick();
            },
          ),
          // Camera Barcode Scanner Trigger
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: isHindi ? 'बारकोड स्कैन करें' : 'Scan barcode',
            onPressed: () => _openCameraScanner(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      child: ResponsiveContainer(
        maxWidth: 960,
        child: Column(
          children: [
            // 1. Top Supercharged Search & Scan Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              color: context.colorSurface,
              child: Column(
                children: [
                  AppSearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    hintText: isHindi
                        ? 'नाम, बारकोड, SKU या ब्रांड से खोजें...'
                        : 'Search name, barcode, SKU or brand...',
                    debounceDuration: Duration.zero,
                    onChanged: _onQueryChanged,
                    onSubmitted: (val) {
                      _onQueryChanged(val);
                      _lookupProduct(val);
                    },
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: 10),

                  // 2. Interactive Category & Stock Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Stock status filters
                        AppFilterChip(
                          label: isHindi ? 'सभी' : 'All',
                          isSelected:
                              _selectedStockFilter == 'All' &&
                              _selectedCategory == 'All',
                          onSelected: () {
                            setState(() {
                              _selectedStockFilter = 'All';
                              _selectedCategory = 'All';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _lookupProduct(_searchController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        AppFilterChip(
                          label: isHindi ? 'उपलब्ध स्टॉक' : 'In Stock',
                          isSelected: _selectedStockFilter == 'In Stock',
                          onSelected: () {
                            setState(() {
                              _selectedStockFilter =
                                  _selectedStockFilter == 'In Stock'
                                  ? 'All'
                                  : 'In Stock';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _lookupProduct(_searchController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        AppFilterChip(
                          label: isHindi ? 'कम स्टॉक' : 'Low Stock',
                          isSelected: _selectedStockFilter == 'Low Stock',
                          onSelected: () {
                            setState(() {
                              _selectedStockFilter =
                                  _selectedStockFilter == 'Low Stock'
                                  ? 'All'
                                  : 'Low Stock';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _lookupProduct(_searchController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        AppFilterChip(
                          label: isHindi ? 'छूट / ऑफर्स' : 'Discounted',
                          isSelected: _selectedStockFilter == 'Discounted',
                          onSelected: () {
                            setState(() {
                              _selectedStockFilter =
                                  _selectedStockFilter == 'Discounted'
                                  ? 'All'
                                  : 'Discounted';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _lookupProduct(_searchController.text);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 20,
                          color: context.colorBorder,
                        ),
                        const SizedBox(width: 8),

                        // Dynamic Category chips
                        ...categories.where((c) => c != 'All').map((cat) {
                          final isSelected =
                              _selectedCategory.toLowerCase() ==
                              cat.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: AppFilterChip(
                              label: cat,
                              isSelected: isSelected,
                              onSelected: () {
                                setState(() {
                                  _selectedCategory = isSelected ? 'All' : cat;
                                });
                                if (_searchController.text.isNotEmpty) {
                                  _lookupProduct(_searchController.text);
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1.0, color: context.colorBorder),

            // 3. Scrollable Result Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. HERO HIGHLIGHT CARD (When an item is matched or selected)
                    if (p != null) ...[
                      _buildHeroPriceCard(context, p, isHindi),
                      const SizedBox(height: 16),
                    ],

                    // B. MULTIPLE MATCHING RESULTS (If user typed a broad search query)
                    if (_matchingProducts.length > 1) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 16,
                            color: context.colorTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isHindi
                                ? 'मिलते-जुलते उत्पाद (${_matchingProducts.length})'
                                : 'Matching Products (${_matchingProducts.length})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: context.colorTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _matchingProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final match = _matchingProducts[index];
                          final isSelected = p?.id == match.id;
                          return _buildMatchingListItem(
                            ctx,
                            match,
                            isSelected,
                            isHindi,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // C. NO PRODUCT FOUND STATE
                    if (_hasSearched && p == null) ...[
                      _buildNotFoundCard(context, isHindi),
                      const SizedBox(height: 16),
                    ],

                    // E. EMPTY INITIAL STATE (Before Searching)
                    if (!_hasSearched && p == null) ...[
                      // Recent Lookups (History chips)
                      if (_recentLookups.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isHindi
                                  ? 'हाल ही में देखे गए भाव'
                                  : 'Recently Checked Items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: context.colorTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recentLookups.map((item) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.price_check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                '${item.name} (₹${item.price.toStringAsFixed(0)})',
                              ),
                              backgroundColor: context.colorSurfaceSubtle,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: context.colorBorder),
                              ),
                              onPressed: () => _selectProduct(item),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildInitialGuideCard(context, isHindi),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HERO PRICE CARD: ULTRA-CLEAN HIGH-CONTRAST SELLING RATE DISPLAY
  // --------------------------------------------------------------------------
  Widget _buildHeroPriceCard(
    BuildContext context,
    ProductModel p,
    bool isHindi,
  ) {
    final hasSavings = p.comparePrice > p.price;
    final savings = hasSavings ? p.comparePrice - p.price : 0.0;
    final discountPercent = hasSavings
        ? ((savings / p.comparePrice) * 100).round()
        : 0;
    final hasCost = p.costPrice > 0;
    final margin = hasCost ? p.price - p.costPrice : 0.0;
    final marginPercent = hasCost && p.costPrice > 0
        ? ((margin / p.costPrice) * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row: Product Image + Name + Category Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colorBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: AppProductImage(
                  imageUrl: p.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.inventory_2_outlined,
                  fallbackIconSize: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.brand.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: context.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.brand.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: context.colorTextPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(
                          p.category,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.colorTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (p.barcode.isNotEmpty)
                          Text(
                            '• #${p.barcode}',
                            style: TextStyle(
                              fontSize: 11.5,
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
          const SizedBox(height: 16),
          Container(height: 1.0, color: context.colorBorder),
          const SizedBox(height: 14),

          // 2. THE PRICE HERO SHOWCASE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colorBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi
                            ? 'बिक्री मूल्य (Selling Price)'
                            : 'Customer Selling Price',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (p.unit.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '/ ${p.unit}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colorTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // MRP & Savings
                      if (hasSavings) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'MRP: ₹${p.comparePrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.colorTextMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isHindi
                                    ? 'बचत ₹${savings.toStringAsFixed(0)} ($discountPercent% छूट)'
                                    : 'Save ₹${savings.toStringAsFixed(0)} ($discountPercent% OFF)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Live Stock Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isHindi ? 'स्टॉक स्थिति' : 'Stock Status',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorTextMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStockPill(p, isHindi),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. WHOLESALE MARGIN ROW (Counter Privacy Shield)
          if (hasCost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hideCostMargin
                    ? context.colorSurfaceSubtle
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hideCostMargin
                      ? context.colorBorder
                      : AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hideCostMargin
                        ? Icons.visibility_off_rounded
                        : Icons.trending_up_rounded,
                    size: 16,
                    color: _hideCostMargin
                        ? context.colorTextMuted
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _hideCostMargin
                        ? Text(
                            isHindi
                                ? 'थोक मार्जिन छुपा हुआ है (ग्राहक सुरक्षा मोड)'
                                : 'Wholesale margin hidden (Counter Privacy Mode)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.colorTextMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Text(
                            isHindi
                                ? 'ख़रीद: ₹${p.costPrice.toStringAsFixed(0)} | मुनाफ़ा: ₹${margin.toStringAsFixed(0)} ($marginPercent%)'
                                : 'Cost: ₹${p.costPrice.toStringAsFixed(0)} | Margin: ₹${margin.toStringAsFixed(0)} ($marginPercent%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _hideCostMargin = !_hideCostMargin);
                      HapticFeedback.selectionClick();
                    },
                    child: Text(
                      _hideCostMargin
                          ? (isHindi ? 'दिखाएं' : 'Show')
                          : (isHindi ? 'छुपाएं' : 'Hide'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.colorTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 4. ACTION BUTTONS ROW (Using Reusable AppButton)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppButton.primary(
                  text: isHindi ? 'POS बिल में जोड़ें' : 'Add to POS Cart',
                  icon: Icons.add_shopping_cart_rounded,
                  size: AppButtonSize.md,
                  onPressed: () => _addToPosCart(p),
                ),
              ),
              const SizedBox(width: 8),
              AppButton.whatsapp(
                text: isHindi ? 'रेट भेजें' : 'WhatsApp',
                icon: Icons.share_rounded,
                size: AppButtonSize.md,
                onPressed: () => _shareOnWhatsApp(p),
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: Icons.edit_rounded,
                tooltip: isHindi ? 'उत्पाद एडिट करें' : 'Edit Product',
                size: AppIconButtonSize.md,
                onPressed: () => _openEditProduct(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Stock Pill Helper
  Widget _buildStockPill(ProductModel p, bool isHindi) {
    if (p.stock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isHindi ? '✕ ख़त्म (0)' : '✕ Out of Stock',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
      );
    }

    if (p.stock <= p.lowStockThreshold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isHindi ? '⚠ कम stock: ${p.stock}' : '⚠ Low Stock: ${p.stock}',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppColors.warning,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isHindi ? '✓ स्टॉक: ${p.stock} ${p.unit}' : '✓ In Stock: ${p.stock}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MATCHING PRODUCT LIST ITEM CARD
  // --------------------------------------------------------------------------
  Widget _buildMatchingListItem(
    BuildContext context,
    ProductModel item,
    bool isSelected,
    bool isHindi,
  ) {
    return InkWell(
      onTap: () => _selectProduct(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorPrimaryLight.withValues(alpha: 0.3)
              : context.colorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.colorBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: AppProductImage(
                imageUrl: item.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                fallbackIcon: Icons.inventory_2_outlined,
                fallbackIconSize: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: context.colorTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category} • ${item.stock > 0 ? "${item.stock} left" : "Out of stock"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
                if (item.comparePrice > item.price)
                  Text(
                    'MRP ₹${item.comparePrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.colorTextMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // NOT FOUND CARD
  // --------------------------------------------------------------------------
  Widget _buildNotFoundCard(BuildContext context, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: context.colorTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            isHindi ? 'कोई उत्पाद नहीं मिला' : 'No Product Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isHindi
                ? 'कृपया बारकोड या नाम की स्पेलिंग जांचें'
                : 'Try checking barcode or searching with different keywords',
            style: TextStyle(fontSize: 12, color: context.colorTextMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              isHindi ? '+ नया सामान जोड़ें' : '+ Add New Product',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => showAddProductDialog(context, initialName: _searchController.text),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // INITIAL GUIDE CARD
  // --------------------------------------------------------------------------
  Widget _buildInitialGuideCard(BuildContext context, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.price_check_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isHindi
                ? 'काउंटर तुरंत भाव जांच (Fast Price Lookup)'
                : 'Instant Counter Price Lookup',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isHindi
                ? 'ग्राहक को तुरंत सही भाव, MRP व छूट बताने के लिए ऊपर बारकोड गन से स्कैन करें या नाम लिखें।'
                : 'Quote exact selling prices, MRP & savings to customers instantly by scanning or typing above.',
            style: TextStyle(
              fontSize: 12.5,
              color: context.colorTextMuted,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(
              isHindi ? 'कैमरा से बारकोड स्कैन करें' : 'Scan Barcode with Camera',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _openCameraScanner(context),
          ),
        ],
      ),
    );
  }
}
