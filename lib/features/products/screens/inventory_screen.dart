import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../dashboard/repositories/ai_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../models/bulk_import_result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/search_fuzzy_utils.dart';
import '../../../core/widgets/app_highlighted_text.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/category_controller.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/manage_categories_sheet.dart';
import '../../../core/widgets/price_checker_dialog.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../widgets/batch_barcode_pairing_dialog.dart';
import '../services/smart_barcode_catalog_service.dart';
import 'product_detail_screen.dart';
import 'barcode_sheet_studio_screen.dart';

/// Comprehensive Inventory Ordering & Sorting Options for Merchants
enum InventorySortOption {
  newest,
  stockLowHigh,
  stockHighLow,
  priceHighLow,
  priceLowHigh,
  marginHighLow,
  nameAZ,
  nameZA,
  bargainFirst,
}

extension InventorySortOptionExt on InventorySortOption {
  String getTitle(BuildContext context) {
    switch (this) {
      case InventorySortOption.newest:
        return context.isHindi ? 'नवीनतम (हाल ही में जोड़े गए)' : 'Newest First';
      case InventorySortOption.stockLowHigh:
        return context.isHindi ? 'कम स्टॉक (रीऑर्डर के लिए)' : 'Stock: Low to High (Reorder First)';
      case InventorySortOption.stockHighLow:
        return context.isHindi ? 'अधिक स्टॉक (ज्यादा से कम)' : 'Stock: High to Low';
      case InventorySortOption.priceHighLow:
        return context.isHindi ? 'कीमत: ज्यादा से कम' : 'Price: High to Low';
      case InventorySortOption.priceLowHigh:
        return context.isHindi ? 'कीमत: कम से ज्यादा' : 'Price: Low to High';
      case InventorySortOption.marginHighLow:
        return context.isHindi ? 'अधिकतम मुनाफा (मार्जिन %)' : 'Highest Profit Margin';
      case InventorySortOption.nameAZ:
        return context.isHindi ? 'नाम: A से Z' : 'Name: A to Z';
      case InventorySortOption.nameZA:
        return context.isHindi ? 'नाम: Z से A' : 'Name: Z to A';
      case InventorySortOption.bargainFirst:
        return context.isHindi ? 'हिडन प्राइस (मोलभाव वाले)' : 'Hidden Price (Bargain Items)';
    }
  }

  String getSubtitle(BuildContext context) {
    switch (this) {
      case InventorySortOption.newest:
        return context.isHindi ? 'हाल ही में जोड़े गए उत्पाद' : 'Default ordering by newest arrival';
      case InventorySortOption.stockLowHigh:
        return context.isHindi ? 'जिनका स्टॉक खत्म होने वाला है वो सबसे पहले' : 'Urgent items needing restocking appear first';
      case InventorySortOption.stockHighLow:
        return context.isHindi ? 'जिनका सबसे अधिक स्टॉक उपलब्ध है' : 'Abundant inventory items appear first';
      case InventorySortOption.priceHighLow:
        return context.isHindi ? 'अधिकतम मूल्य वाले उत्पाद पहले' : 'Highest selling price products first';
      case InventorySortOption.priceLowHigh:
        return context.isHindi ? 'कम कीमत वाले किफायती उत्पाद पहले' : 'Lowest selling price products first';
      case InventorySortOption.marginHighLow:
        return context.isHindi ? 'सबसे ज्यादा प्रॉफिट मार्जिन वाले उत्पाद' : 'Highest margin percentage products first';
      case InventorySortOption.nameAZ:
        return context.isHindi ? 'वर्णमाला अनुसार सीधा क्रम' : 'Alphabetical order from A to Z';
      case InventorySortOption.nameZA:
        return context.isHindi ? 'उलटे वर्णमाला अनुसार क्रम' : 'Alphabetical reverse order from Z to A';
      case InventorySortOption.bargainFirst:
        return context.isHindi ? 'जिनका ऑनलाइन मूल्य छुपा हुआ है' : 'Storefront price hidden products first';
    }
  }

  IconData get icon {
    switch (this) {
      case InventorySortOption.newest:
        return Icons.schedule_rounded;
      case InventorySortOption.stockLowHigh:
        return Icons.warning_amber_rounded;
      case InventorySortOption.stockHighLow:
        return Icons.inventory_2_outlined;
      case InventorySortOption.priceHighLow:
        return Icons.arrow_downward_rounded;
      case InventorySortOption.priceLowHigh:
        return Icons.arrow_upward_rounded;
      case InventorySortOption.marginHighLow:
        return Icons.trending_up_rounded;
      case InventorySortOption.nameAZ:
      case InventorySortOption.nameZA:
        return Icons.sort_by_alpha_rounded;
      case InventorySortOption.bargainFirst:
        return Icons.lock_outline_rounded;
    }
  }

  String getShortBadge(BuildContext context) {
    switch (this) {
      case InventorySortOption.newest:
        return context.isHindi ? 'सॉर्ट' : 'Sort';
      case InventorySortOption.stockLowHigh:
        return context.isHindi ? 'कम स्टॉक' : 'Low Stock';
      case InventorySortOption.stockHighLow:
        return context.isHindi ? 'अधिक स्टॉक' : 'High Stock';
      case InventorySortOption.priceHighLow:
        return context.isHindi ? 'कीमत ↓' : 'Price High';
      case InventorySortOption.priceLowHigh:
        return context.isHindi ? 'कीमत ↑' : 'Price Low';
      case InventorySortOption.marginHighLow:
        return context.isHindi ? 'मार्जिन %' : 'Margin %';
      case InventorySortOption.nameAZ:
        return 'A-Z';
      case InventorySortOption.nameZA:
        return 'Z-A';
      case InventorySortOption.bargainFirst:
        return context.isHindi ? 'मोलभाव' : 'Hidden';
    }
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  InventorySortOption _sortOption = InventorySortOption.newest;
  String _selectedCategory = 'All';
  bool _showOnlyLowStock = false;
  bool _showOnlyPriceHidden = false;
  bool _showOnlyDiscounted = false;
  bool _showOnlyMissingBarcode = false;
  bool _showOnlyNearExpiry = false;

  // 120 FPS Buttery-Smooth Scrolling & Filtering Cache
  List<ProductModel>? _cachedSourceProducts;
  String _lastSearchQuery = '';
  InventorySortOption _lastSortOption = InventorySortOption.newest;
  String _lastSelectedCategory = 'All';
  bool _lastShowOnlyLowStock = false;
  bool _lastShowOnlyPriceHidden = false;
  bool _lastShowOnlyDiscounted = false;
  bool _lastShowOnlyMissingBarcode = false;
  bool _lastShowOnlyNearExpiry = false;

  List<ProductModel> _cachedDisplayProducts = [];
  List<String> _cachedSortedCategories = [];
  int _cachedLowStockCount = 0;
  int _cachedHiddenPriceCount = 0;
  int _cachedDiscountedCount = 0;
  int _cachedMissingBarcodeCount = 0;
  int _cachedNearExpiryCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductController>().loadProducts();
      try {
        final uri = GoRouterState.of(context).uri;
        if (uri.queryParameters['filter'] == 'low_stock') {
          setState(() => _showOnlyLowStock = true);
        }
      } catch (_) {}
    });
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text != _searchQuery) {
      setState(() {
        _searchQuery = text;
      });

      // Debounce server database search by 350ms to find products beyond local page limit
      _searchDebounceTimer?.cancel();
      if (text.isNotEmpty) {
        _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted && _searchQuery == text) {
            context.read<ProductController>().loadProducts(search: text, silent: true);
          }
        });
      } else {
        context.read<ProductController>().loadProducts(silent: true);
      }
    }
  }

  void _clearAllFilters() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _showOnlyLowStock = false;
      _showOnlyPriceHidden = false;
      _showOnlyDiscounted = false;
      _showOnlyMissingBarcode = false;
      _showOnlyNearExpiry = false;
      _selectedCategory = 'All';
      _sortOption = InventorySortOption.newest;
    });
    context.read<ProductController>().loadProducts(silent: true);
  }

  void _recomputeFilteredProducts(List<ProductModel> allProducts) {
    if (identical(_cachedSourceProducts, allProducts) &&
        _lastSearchQuery == _searchQuery &&
        _lastSortOption == _sortOption &&
        _lastSelectedCategory == _selectedCategory &&
        _lastShowOnlyLowStock == _showOnlyLowStock &&
        _lastShowOnlyPriceHidden == _showOnlyPriceHidden &&
        _lastShowOnlyDiscounted == _showOnlyDiscounted &&
        _lastShowOnlyMissingBarcode == _showOnlyMissingBarcode &&
        _lastShowOnlyNearExpiry == _showOnlyNearExpiry) {
      return; // 0ms cache hit - zero CPU cycles during scrolling
    }

    _cachedSourceProducts = allProducts;
    _lastSearchQuery = _searchQuery;
    _lastSortOption = _sortOption;
    _lastSelectedCategory = _selectedCategory;
    _lastShowOnlyLowStock = _showOnlyLowStock;
    _lastShowOnlyPriceHidden = _showOnlyPriceHidden;
    _lastShowOnlyDiscounted = _showOnlyDiscounted;
    _lastShowOnlyMissingBarcode = _showOnlyMissingBarcode;
    _lastShowOnlyNearExpiry = _showOnlyNearExpiry;

    // 1. Dynamic categories & counts
    final availableCategories = <String>{};
    int lowStock = 0;
    int hiddenPrice = 0;
    int discounted = 0;
    int missingBarcode = 0;
    int nearExpiry = 0;

    for (final p in allProducts) {
      final cat = formatCategoryName(p.category);
      if (cat.isNotEmpty && cat != 'General Store') {
        availableCategories.add(cat);
      }
      if (p.isLowStock || p.isOutOfStock) {
        lowStock++;
      }
      if (!p.isPricePublic) {
        hiddenPrice++;
      }
      if (p.comparePrice > p.price) {
        discounted++;
      }
      if (p.barcode.trim().isEmpty) {
        missingBarcode++;
      }
      if (p.isNearExpiry || p.isExpired) {
        nearExpiry++;
      }
    }

    _cachedSortedCategories = availableCategories.toList()..sort();
    _cachedLowStockCount = lowStock;
    _cachedHiddenPriceCount = hiddenPrice;
    _cachedDiscountedCount = discounted;
    _cachedMissingBarcodeCount = missingBarcode;
    _cachedNearExpiryCount = nearExpiry;

    // 2. Tokenized search matching
    final trimmedQuery = _searchQuery.trim().toLowerCase();
    final queryTokens = trimmedQuery.isEmpty
        ? const <String>[]
        : trimmedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    List<ProductModel> displayList = allProducts.where((p) {
      if (_showOnlyLowStock && !(p.isLowStock || p.isOutOfStock)) {
        return false;
      }
      if (_showOnlyPriceHidden && p.isPricePublic) {
        return false;
      }
      if (_showOnlyDiscounted && p.comparePrice <= p.price) {
        return false;
      }
      if (_showOnlyMissingBarcode && p.barcode.trim().isNotEmpty) {
        return false;
      }
      if (_showOnlyNearExpiry && !(p.isNearExpiry || p.isExpired)) {
        return false;
      }
      if (_selectedCategory != 'All') {
        if (!CategoryRegistry.isCategoryMatch(p.category, _selectedCategory)) {
          return false;
        }
      }
      if (queryTokens.isNotEmpty) {
        final serverQuery = context.read<ProductController>().searchQuery;
        final isServerResults = serverQuery.isNotEmpty && serverQuery.trim().toLowerCase() == trimmedQuery;

        if (!isServerResults) {
          final buffer = StringBuffer()
            ..write(p.name.toLowerCase())
            ..write(' ')
            ..write(p.sku.toLowerCase())
            ..write(' ')
            ..write(p.barcode.toLowerCase())
            ..write(' ')
            ..write(p.category.toLowerCase())
            ..write(' ')
            ..write(p.brand.toLowerCase());

          for (final val in p.attributes.values) {
            if (val != null) {
              buffer.write(' ');
              buffer.write(val.toString().toLowerCase());
            }
          }

          final combined = buffer.toString();
          for (final token in queryTokens) {
            if (!combined.contains(token)) {
              return false;
            }
          }
        }
      }
      return true;
    }).toList();

    // 3. Multi-Criteria Sorting
    switch (_sortOption) {
      case InventorySortOption.newest:
        break;
      case InventorySortOption.stockLowHigh:
        displayList.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case InventorySortOption.stockHighLow:
        displayList.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case InventorySortOption.priceHighLow:
        displayList.sort((a, b) => b.price.compareTo(a.price));
        break;
      case InventorySortOption.priceLowHigh:
        displayList.sort((a, b) => a.price.compareTo(b.price));
        break;
      case InventorySortOption.marginHighLow:
        displayList.sort((a, b) => b.profitMarginPct.compareTo(a.profitMarginPct));
        break;
      case InventorySortOption.nameAZ:
        displayList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case InventorySortOption.nameZA:
        displayList.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case InventorySortOption.bargainFirst:
        displayList.sort((a, b) {
          final aScore = (!a.isPricePublic || a.allowBargain) ? 1 : 0;
          final bScore = (!b.isPricePublic || b.allowBargain) ? 1 : 0;
          return bScore.compareTo(aScore);
        });
        break;
    }

    _cachedDisplayProducts = displayList;
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.colorBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded, size: 22, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.isHindi ? 'इन्वेंट्री क्रमबद्ध करें' : 'Sort Inventory Catalog',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ctx.colorTextPrimary,
                              ),
                            ),
                            Text(
                              ctx.isHindi ? 'फास्ट सर्च और आसान इन्वेंट्री के लिए' : 'Fast searching & optimized inventory tracking',
                              style: TextStyle(
                                fontSize: 11,
                                color: ctx.colorTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: ctx.colorBorder),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: InventorySortOption.values.map((opt) {
                        final isSelected = _sortOption == opt;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? ctx.colorPrimaryLight : ctx.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : ctx.colorBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _sortOption = opt;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : ctx.colorSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : ctx.colorBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      opt.icon,
                                      size: 18,
                                      color: isSelected ? Colors.white : ctx.colorTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opt.getTitle(ctx),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? AppColors.primary : ctx.colorTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          opt.getSubtitle(ctx),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ctx.colorTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 20,
                                    color: isSelected ? AppColors.primary : ctx.colorTextMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
    IconData? icon,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppColors.primary;
    final effectiveBg = isSelected
        ? effectiveColor.withValues(alpha: 0.12)
        : context.colorSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? effectiveColor : context.colorBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? effectiveColor : context.colorTextSecondary,
                ),
                const SizedBox(width: 4.5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? effectiveColor : context.colorTextPrimary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? effectiveColor : context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : context.colorTextSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToProductDetails(BuildContext context, ProductModel p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: p,
          onEditRequested: (ctx, item) => _showAddProductDialog(ctx, initialProduct: item),
          onDuplicateRequested: (ctx, item) {
            Navigator.pop(ctx);
            _showAddProductDialog(context, initialProduct: item, isDuplicate: true);
          },
        ),
      ),
    );
  }

  /// Launches Continuous Assembly-Line Batch Barcode Pairing Station
  void _launchBatchBarcodePairing(BuildContext context, List<ProductModel> unmappedList) async {
    final prodCtrl = context.read<ProductController>();
    await BatchBarcodePairingDialog.show(
      context,
      unmappedProducts: unmappedList,
      onCheckDuplicate: (barcode) {
        return prodCtrl.products.any((item) =>
            item.barcode.trim().isNotEmpty &&
            item.barcode.trim().toLowerCase() == barcode.trim().toLowerCase());
      },
      onAssignBarcode: (product, barcode) async {
        final updates = <String, dynamic>{
          'barcode': barcode,
        };
        if (product.sku.trim().isEmpty) {
          updates['sku'] = barcode;
        }
        return await prodCtrl.editProduct(product.id, updates);
      },
      onAutoGenerate: (product) async {
        final generated = _generateSmartSku(product.name);
        final updates = <String, dynamic>{
          'barcode': generated,
        };
        if (product.sku.trim().isEmpty) {
          updates['sku'] = generated;
        }
        return await prodCtrl.editProduct(product.id, updates);
      },
    );
  }

  /// Displays a clean bottom sheet modal offering Camera capture or Device Gallery selection
  void _showProductImageSourceSheet(
    BuildContext context, {
    required Function(List<XFile> files) onFilesSelected,
    int maxAllowed = 10,
    int currentCount = 0,
  }) {
    if (currentCount >= maxAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isHindi
                ? 'अधिकतम $maxAllowed तस्वीरें जोड़ी जा सकती हैं'
                : 'Maximum $maxAllowed images allowed',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: sheetCtx.colorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                sheetCtx.isHindi ? 'उत्पाद तस्वीर का स्रोत चुनें' : 'Choose Product Image Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: sheetCtx.colorTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text(
                  sheetCtx.isHindi ? 'कैमरा से फोटो खींचें' : 'Take Photo with Camera',
                  style: TextStyle(fontWeight: FontWeight.w600, color: sheetCtx.colorTextPrimary),
                ),
                subtitle: Text(
                  sheetCtx.isHindi ? 'सीधे कैमरे से नई तस्वीर लें' : 'Capture instant photo with camera',
                  style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                      requestFullMetadata: false,
                    );
                    if (picked != null) {
                      onFilesSelected([picked]);
                    }
                  } catch (e) {
                    debugPrint('[InventoryScreen] Camera picker error: $e');
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text(
                  sheetCtx.isHindi ? 'गैलरी / डिवाइस से चुनें' : 'Choose from Gallery / Photos',
                  style: TextStyle(fontWeight: FontWeight.w600, color: sheetCtx.colorTextPrimary),
                ),
                subtitle: Text(
                  sheetCtx.isHindi ? 'एक साथ कई तस्वीरें चुन सकते हैं' : 'Select multiple photos at once',
                  style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    final pickedFiles = await picker.pickMultiImage(
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                      requestFullMetadata: false,
                    );
                    if (pickedFiles.isNotEmpty) {
                      final remaining = maxAllowed - currentCount;
                      final selected = pickedFiles.take(remaining).toList();
                      onFilesSelected(selected);
                    }
                  } catch (e) {
                    debugPrint('[InventoryScreen] MultiImage picker warning: $e');
                    try {
                      final pickedFiles = await picker.pickMultiImage(
                        requestFullMetadata: false,
                      );
                      if (pickedFiles.isNotEmpty) {
                        final remaining = maxAllowed - currentCount;
                        final selected = pickedFiles.take(remaining).toList();
                        onFilesSelected(selected);
                      }
                    } catch (fallbackError) {
                      debugPrint('[InventoryScreen] Fallback image picker error: $fallbackError');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Generates a Smart SKU Code based on Product Name & Timestamp
  String _generateSmartSku(String productName) {
    final cleanName = productName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .trim()
        .toUpperCase();

    if (cleanName.isEmpty) {
      final randSuffix = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      return 'PROD-$randSuffix';
    }

    final words = cleanName.split(RegExp(r'\s+'));
    String prefix = '';

    if (words.length == 1) {
      prefix = words[0].length >= 4 ? words[0].substring(0, 4) : words[0];
    } else if (words.length == 2) {
      final w1 = words[0].length >= 3 ? words[0].substring(0, 3) : words[0];
      final w2 = words[1].length >= 3 ? words[1].substring(0, 3) : words[1];
      prefix = '$w1-$w2';
    } else {
      final w1 = words[0].length >= 2 ? words[0].substring(0, 2) : words[0];
      final w2 = words[1].length >= 2 ? words[1].substring(0, 2) : words[1];
      final w3 = words[2].length >= 2 ? words[2].substring(0, 2) : words[2];
      prefix = '$w1-$w2-$w3';
    }

    final suffix = (100 + (DateTime.now().millisecondsSinceEpoch % 900)).toString();
    return '$prefix-$suffix';
  }

  Widget _buildPresetChip(BuildContext context, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colorBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttrChip(
    BuildContext context,
    String label,
    String keyName,
    String hintVal,
    List<MapEntry<TextEditingController, TextEditingController>> customAttrPairs,
    StateSetter setModalState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setModalState(() {
            customAttrPairs.add(MapEntry(
              TextEditingController(text: keyName),
              TextEditingController(),
            ));
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colorPrimaryLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog(
    BuildContext context, {
    ProductModel? initialProduct,
    bool isDuplicate = false,
    String? initialBarcode,
    String? initialName,
  }) {
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentShop = authController.currentShop;
    if (currentShop == null || currentShop.id.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isHindi
                ? 'उत्पाद जोड़ने के लिए कृपया पहले स्टोर प्रोफ़ाइल बनाएं'
                : 'Please set up your store profile first before adding products',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push('/merchant/profile');
      return;
    }

    final isEdit = initialProduct != null && !isDuplicate;
    final resolvedInitialName = isDuplicate
        ? '${initialProduct?.name ?? ''} (Copy)'
        : (initialProduct?.name ?? initialName ?? '');
    final nameCtrl = TextEditingController(text: resolvedInitialName);
    final priceCtrl = TextEditingController(
      text: initialProduct != null && initialProduct.price > 0
          ? initialProduct.price.toStringAsFixed(0)
          : '',
    );
    final costPriceCtrl = TextEditingController(
      text: initialProduct != null && initialProduct.costPrice > 0
          ? initialProduct.costPrice.toStringAsFixed(0)
          : '',
    );
    final comparePriceCtrl = TextEditingController(
      text: initialProduct != null && initialProduct.comparePrice > 0
          ? initialProduct.comparePrice.toStringAsFixed(0)
          : '',
    );
    final floorPriceCtrl = TextEditingController(
      text: initialProduct != null && initialProduct.floorPrice > 0
          ? initialProduct.floorPrice.toStringAsFixed(0)
          : '',
    );
    final stockCtrl = TextEditingController(
      text: initialProduct != null ? initialProduct.stock.toString() : '20',
    );
    final lowStockCtrl = TextEditingController(
      text: initialProduct != null ? initialProduct.lowStockThreshold.toString() : '5',
    );
    final weightCtrl = TextEditingController(
      text: initialProduct != null && initialProduct.weight > 0
          ? initialProduct.weight.toString()
          : '',
    );
    final initialCategory = formatCategoryName(initialProduct?.category ?? 'General Store');
    final categoryCtrl = TextEditingController(text: initialCategory);
    final initialBarcodeVal = isDuplicate
        ? ''
        : (initialBarcode?.isNotEmpty == true
            ? initialBarcode!
            : (initialProduct?.barcode ?? ''));
    final barcodeCtrl = TextEditingController(text: initialBarcodeVal);
    final descriptionCtrl = TextEditingController(text: initialProduct?.description ?? '');
    final brandCtrl = TextEditingController(
      text: initialProduct?.brand.isNotEmpty == true
          ? initialProduct!.brand
          : (initialProduct?.attributes['brand']?.toString() ?? ''),
    );

    bool allowBargain = initialProduct?.allowBargain ?? false;
    bool isActive = initialProduct?.isActive ?? true;
    bool isFeatured = initialProduct?.isFeatured ?? false;
    bool isPricePublic = initialProduct?.isPricePublic ?? true;
    String unit = initialProduct?.unit ?? 'piece';

    // Instant Master Catalog Pre-fill if initialBarcode was provided (e.g. from Price Checker or external scan)
    if (initialBarcodeVal.isNotEmpty && (resolvedInitialName.isEmpty || isDuplicate)) {
      final initialMatch = SmartBarcodeCatalogService.lookupSync(initialBarcodeVal);
      if (initialMatch != null) {
        if (nameCtrl.text.trim().isEmpty || isDuplicate) {
          nameCtrl.text = initialMatch.name;
        }
        if (brandCtrl.text.trim().isEmpty) {
          brandCtrl.text = initialMatch.brand;
        }
        if (descriptionCtrl.text.trim().isEmpty && (initialMatch.description?.isNotEmpty ?? false)) {
          descriptionCtrl.text = initialMatch.description!;
        }
        if (comparePriceCtrl.text.trim().isEmpty && initialMatch.mrp > 0) {
          comparePriceCtrl.text = initialMatch.mrp.toStringAsFixed(0);
        }
        if (priceCtrl.text.trim().isEmpty && initialMatch.sellingPrice > 0) {
          priceCtrl.text = initialMatch.sellingPrice.toStringAsFixed(0);
        }
        final canonicalCat = CategoryRegistry.formatCategoryName(initialMatch.category);
        categoryCtrl.text = canonicalCat;
        final u = initialMatch.unit.toLowerCase();
        if (u.contains('kg')) {
          unit = 'kg';
        } else if (u.contains('gm') || u.contains('g')) {
          unit = 'gm';
        } else if (u.contains('litre') || u.contains('l') || u.contains('ml')) {
          unit = 'litre';
        } else if (u.contains('packet') || u.contains('pack')) {
          unit = 'packet';
        } else {
          unit = 'piece';
        }
      }
    }

    List<String> productImages = List<String>.from(initialProduct?.images ?? []);
    final Map<String, XFile> pendingXFiles = {};
    bool isSaving = false;
    bool isAiScanning = false;

    // Dynamic Custom JSONB Attributes controllers (exclude reserved system keys)
    List<MapEntry<TextEditingController, TextEditingController>> customAttrPairs = [];
    if (initialProduct != null && initialProduct.attributes.isNotEmpty) {
      initialProduct.attributes.forEach((k, v) {
        final kLow = k.toLowerCase().trim();
        if (kLow != 'brand' &&
            kLow != 'category_name' &&
            kLow != 'category' &&
            kLow != 'unit' &&
            v != null &&
            v.toString().trim().isNotEmpty) {
          customAttrPairs.add(MapEntry(
            TextEditingController(text: k),
            TextEditingController(text: v.toString()),
          ));
        }
      });
    }

    // Fetch live categories from CategoryController (Custom + System Defaults)
    final catCtrl = context.read<CategoryController>();
    final dynamicCategories = catCtrl.categoryNames;
    final categoriesList = List<String>.from(
        dynamicCategories.isNotEmpty ? dynamicCategories : CategoryRegistry.canonicalCategories);

    if (categoryCtrl.text.isNotEmpty && !categoriesList.contains(categoryCtrl.text)) {
      categoriesList.insert(0, categoryCtrl.text);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          // Live Pricing Integrity Calculations
          final livePrice = double.tryParse(priceCtrl.text) ?? 0.0;
          final liveCost = double.tryParse(costPriceCtrl.text) ?? 0.0;
          final liveMrp = double.tryParse(comparePriceCtrl.text) ?? 0.0;

          final isMrpInvalid = liveMrp > 0 && liveMrp < livePrice;
          final isCostInvalid = liveCost > livePrice;
          final hasProfit = livePrice > liveCost && liveCost > 0;
          final hasDiscount = liveMrp > livePrice;

          final cleanName = nameCtrl.text.trim();
          final cleanBrand = brandCtrl.text.trim();
          final cleanWeight = weightCtrl.text.trim();

          String suggestedTitle = '';
          if (cleanBrand.isNotEmpty && !cleanName.toLowerCase().startsWith(cleanBrand.toLowerCase())) {
            suggestedTitle = '$cleanBrand $cleanName';
          } else {
            suggestedTitle = cleanName;
          }
          if (cleanWeight.isNotEmpty && !suggestedTitle.toLowerCase().contains(cleanWeight.toLowerCase())) {
            suggestedTitle = '$suggestedTitle $cleanWeight$unit';
          }
          final showTitleHelper = cleanName.isNotEmpty &&
              suggestedTitle.isNotEmpty &&
              suggestedTitle.toLowerCase() != cleanName.toLowerCase();

          String? lastAutofilledBarcode;

          Future<void> applyMasterCatalogAutofill(String rawBarcode, {bool forceOverwrite = false}) async {
            final clean = rawBarcode.trim();
            if (clean.isEmpty) return;
            final match = await SmartBarcodeCatalogService.lookup(clean);
            if (match != null) {
              lastAutofilledBarcode = clean;
              setModalState(() {
                barcodeCtrl.text = clean;
                if (forceOverwrite || nameCtrl.text.trim().isEmpty || nameCtrl.text.trim() == 'New Product') {
                  nameCtrl.text = match.name;
                }
                if (forceOverwrite || brandCtrl.text.trim().isEmpty) {
                  brandCtrl.text = match.brand;
                }
                if (forceOverwrite || descriptionCtrl.text.trim().isEmpty) {
                  if (match.description?.isNotEmpty ?? false) {
                    descriptionCtrl.text = match.description!;
                  }
                }
                if (match.mrp > 0 && (forceOverwrite || comparePriceCtrl.text.trim().isEmpty || comparePriceCtrl.text == '0')) {
                  comparePriceCtrl.text = match.mrp.toStringAsFixed(0);
                }
                if (match.sellingPrice > 0 && (forceOverwrite || priceCtrl.text.trim().isEmpty || priceCtrl.text == '0')) {
                  priceCtrl.text = match.sellingPrice.toStringAsFixed(0);
                }

                // Canonical category mapping
                final canonicalCat = CategoryRegistry.formatCategoryName(match.category);
                if (categoriesList.contains(canonicalCat)) {
                  categoryCtrl.text = canonicalCat;
                } else if (categoriesList.contains(match.category)) {
                  categoryCtrl.text = match.category;
                } else {
                  categoriesList.insert(0, canonicalCat);
                  categoryCtrl.text = canonicalCat;
                }

                // Unit mapping
                final u = match.unit.toLowerCase();
                if (u.contains('kg')) {
                  unit = 'kg';
                } else if (u.contains('gm') || u.contains('g')) {
                  unit = 'gm';
                } else if (u.contains('l') || u.contains('ml')) {
                  unit = 'litre';
                } else if (u.contains('pack')) {
                  unit = 'packet';
                } else {
                  unit = 'piece';
                }

                if (match.brand.isNotEmpty) {
                  final brandPair = customAttrPairs.firstWhere(
                    (p) => p.key.text.trim().toLowerCase() == 'brand',
                    orElse: () => MapEntry(TextEditingController(text: ''), TextEditingController(text: '')),
                  );
                  if (brandPair.key.text.isEmpty) {
                    customAttrPairs.add(MapEntry(
                      TextEditingController(text: 'Brand'),
                      TextEditingController(text: match.brand),
                    ));
                  } else if (forceOverwrite || brandPair.value.text.trim().isEmpty) {
                    brandPair.value.text = match.brand;
                  }
                }

                // Auto-fill ALL dynamic custom attributes (15+ fields) from Master Catalog
                if (match.attributes != null && match.attributes!.isNotEmpty) {
                  match.attributes!.forEach((key, val) {
                    final cleanKey = key.trim();
                    final cleanVal = val?.toString().trim() ?? '';
                    if (cleanKey.isNotEmpty &&
                        cleanVal.isNotEmpty &&
                        cleanKey.toLowerCase() != 'barcode' &&
                        cleanKey.toLowerCase() != 'unit' &&
                        cleanKey.toLowerCase() != 'brand' &&
                        cleanKey.toLowerCase() != 'category' &&
                        cleanKey.toLowerCase() != 'category_name' &&
                        cleanKey.toLowerCase() != 'is_price_public') {
                      final existingPair = customAttrPairs.firstWhere(
                        (p) => p.key.text.trim().toLowerCase() == cleanKey.toLowerCase(),
                        orElse: () => MapEntry(TextEditingController(text: ''), TextEditingController(text: '')),
                      );
                      if (existingPair.key.text.isEmpty) {
                        customAttrPairs.add(MapEntry(
                          TextEditingController(text: CategoryRegistry.formatCategoryName(cleanKey)),
                          TextEditingController(text: cleanVal),
                        ));
                      } else if (forceOverwrite || existingPair.value.text.trim().isEmpty) {
                        existingPair.value.text = cleanVal;
                      }
                    }
                  });
                }
              });

              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).clearSnackBars();
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sheetCtx.isHindi
                                ? '⚡ मास्टर कैटलॉग से विवरण लोड हुआ: ${match.name}'
                                : '⚡ Auto-filled details for: ${match.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else {
              setModalState(() {
                barcodeCtrl.text = clean;
              });
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).clearSnackBars();
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Text(
                      sheetCtx.isHindi
                          ? '✓ बारकोड स्कैन हुआ ($clean)'
                          : '✓ Barcode captured ($clean)',
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }

          Future<void> runAiAutofill(String imagePathOrKey) async {
            if (isAiScanning) return;
            setModalState(() {
              isAiScanning = true;
            });

            try {
              Uint8List? imageBytes;
              String mimeType = 'image/jpeg';

              if (pendingXFiles.containsKey(imagePathOrKey)) {
                final xf = pendingXFiles[imagePathOrKey]!;
                imageBytes = await xf.readAsBytes();
                if (xf.name.toLowerCase().endsWith('.png')) {
                  mimeType = 'image/png';
                }
              } else if (!imagePathOrKey.startsWith('http') && !kIsWeb) {
                final file = File(imagePathOrKey);
                if (await file.exists()) {
                  imageBytes = await file.readAsBytes();
                  if (imagePathOrKey.toLowerCase().endsWith('.png')) {
                    mimeType = 'image/png';
                  }
                }
              }

              if (imageBytes == null || imageBytes.isEmpty) {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(sheetCtx.isHindi
                          ? 'कृपया विश्लेषण के लिए पहले एक तस्वीर चुनें'
                          : 'Please pick an image first for AI analysis'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              final base64String = base64Encode(imageBytes);
              final aiRepo = AiRepository();
              final resp = await aiRepo.scanProduct(imageBase64: base64String, mimeType: mimeType);

              if (resp.success && resp.data != null) {
                final data = resp.data!;
                setModalState(() {
                  // 1. Name
                  final rawName = data['name']?.toString().trim() ?? '';
                  if (rawName.isNotEmpty) {
                    nameCtrl.text = rawName;
                  }

                  // 2. Brand
                  final rawBrand = data['brand']?.toString().trim() ?? '';
                  if (rawBrand.isNotEmpty) {
                    brandCtrl.text = rawBrand;
                  }

                  // 3. Category
                  final rawCategory = data['category_hint']?.toString().trim() ?? '';
                  if (rawCategory.isNotEmpty) {
                    final canonical = CategoryRegistry.formatCategoryName(rawCategory);
                    if (!categoriesList.contains(canonical)) {
                      categoriesList.insert(0, canonical);
                    }
                    categoryCtrl.text = canonical;
                  }

                  // 4. Weight
                  final rawWeight = data['weight'];
                  if (rawWeight != null) {
                    final w = double.tryParse(rawWeight.toString()) ?? 0;
                    if (w > 0) {
                      weightCtrl.text = w == w.toInt() ? w.toInt().toString() : w.toString();
                    }
                  }

                  // 5. Unit
                  final rawUnit = data['unit']?.toString().toLowerCase().trim() ?? '';
                  if (['gm', 'kg', 'ml', 'litre', 'piece', 'meter', 'pack', 'pair', 'box'].contains(rawUnit)) {
                    unit = rawUnit;
                  }

                  // 6. MRP
                  final rawMrp = data['mrp'];
                  if (rawMrp != null) {
                    final m = double.tryParse(rawMrp.toString()) ?? 0;
                    if (m > 0) {
                      comparePriceCtrl.text = m.toStringAsFixed(0);
                    }
                  }

                  // 7. Selling Price
                  final rawSp = data['selling_price'];
                  if (rawSp != null) {
                    final sp = double.tryParse(rawSp.toString()) ?? 0;
                    if (sp > 0) {
                      priceCtrl.text = sp.toStringAsFixed(0);
                    }
                  }

                  // 8. Cost Price
                  final rawCost = data['estimated_cost'];
                  if (rawCost != null) {
                    final cp = double.tryParse(rawCost.toString()) ?? 0;
                    if (cp > 0) {
                      costPriceCtrl.text = cp.toStringAsFixed(0);
                    }
                  }

                  // 9. Description
                  final rawDesc = data['description']?.toString().trim() ?? '';
                  if (rawDesc.isNotEmpty) {
                    descriptionCtrl.text = rawDesc;
                  }

                  // 10. Barcode / SKU
                  if (barcodeCtrl.text.trim().isEmpty) {
                    final rawBarcode = data['barcode']?.toString().trim() ?? '';
                    final rawSku = data['suggested_sku']?.toString().trim() ?? '';
                    if (rawBarcode.isNotEmpty) {
                      barcodeCtrl.text = rawBarcode;
                    } else if (rawSku.isNotEmpty) {
                      barcodeCtrl.text = rawSku;
                    }
                  }

                  // 11. Attributes (Deep specs)
                  if (data['attributes'] is Map) {
                    final attrMap = Map<String, dynamic>.from(data['attributes']);
                    attrMap.forEach((k, v) {
                      final cleanK = k.toString().trim();
                      final cleanV = v.toString().trim();
                      if (cleanK.isNotEmpty && cleanV.isNotEmpty && !cleanK.toLowerCase().contains('specs')) {
                        final existing = customAttrPairs.firstWhere(
                          (p) => p.key.text.toLowerCase().trim() == cleanK.toLowerCase(),
                          orElse: () => MapEntry(TextEditingController(text: ''), TextEditingController(text: '')),
                        );
                        if (existing.key.text.isEmpty) {
                          customAttrPairs.add(MapEntry(
                            TextEditingController(text: CategoryRegistry.formatCategoryName(cleanK)),
                            TextEditingController(text: cleanV),
                          ));
                        } else if (existing.value.text.trim().isEmpty) {
                          existing.value.text = cleanV;
                        }
                      }
                    });
                  }
                });

                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).clearSnackBars();
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sheetCtx.isHindi
                                  ? '✨ AI ने उत्पाद के 10+ विवरण लोड किए: ${data['name'] ?? ''}'
                                  : '✨ AI Auto-Filled 10+ details for: ${data['name'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(resp.message?.isNotEmpty == true
                          ? resp.message!
                          : (sheetCtx.isHindi ? 'AI से विवरण नहीं मिल सका' : 'Could not extract details from AI')),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            } catch (err) {
              debugPrint('[InventoryScreen] runAiAutofill exception: $err');
            } finally {
              if (sheetCtx.mounted) {
                setModalState(() {
                  isAiScanning = false;
                });
              }
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: sheetCtx.colorSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.90,
                maxWidth: 620,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle & Header
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: sheetCtx.colorBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: sheetCtx.colorPrimaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDuplicate
                                ? Icons.copy_rounded
                                : (isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded),
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isDuplicate
                                ? (sheetCtx.isHindi ? 'उत्पाद की प्रति बनाएं' : 'Duplicate Product')
                                : (isEdit ? sheetCtx.tr('inv_edit_dialog_title') : sheetCtx.tr('inv_add_dialog_title')),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: sheetCtx.colorTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    Divider(height: 20, color: sheetCtx.colorBorder),

                    // ⚡ PROMINENT GLOBAL MASTER BARCODE AUTO-FILL BANNER
                    if (!isEdit) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sheetCtx.isHindi
                                        ? '⚡ बारकोड स्कैन करें (ऑटो-फिल)'
                                        : '⚡ Scan Barcode to Auto-Fill',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: sheetCtx.colorTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    sheetCtx.isHindi
                                        ? 'Dove, Maggi, Parle-G आदि का नाम, ब्रांड, MRP स्वतः भरें'
                                        : 'Auto-fill Name, Brand, Category, MRP for Dove, Maggi, Parle-G...',
                                    style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.camera_alt_outlined, size: 16),
                              label: Text(
                                sheetCtx.isHindi ? 'स्कैन' : 'Scan',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () async {
                                await MobileBarcodeScannerDialog.show(
                                  sheetCtx,
                                  title: sheetCtx.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
                                  autoCloseOnSuccess: true,
                                  successMessage: sheetCtx.isHindi ? '✓ बारकोड से विवरण लोड हुआ!' : '✓ Product Details Loaded!',
                                  onBarcodeScanned: (scanned) async {
                                    final clean = scanned.trim();
                                    if (clean.isNotEmpty) {
                                      applyMasterCatalogAutofill(clean, forceOverwrite: true);
                                      setModalState(() {});
                                    }
                                    return true;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ⚡ QUICK PRESET TEMPLATES BAR (For Fast 1-Tap Data Entry)
                    if (!isEdit) ...[
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Quick Fill Presets:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: sheetCtx.colorTextMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip(sheetCtx, '🥛 Dairy / Milk', () {
                              setModalState(() {
                                categoryCtrl.text = 'Dairy, Bakery & Frozen';
                                unit = 'litre';
                                stockCtrl.text = '20';
                                lowStockCtrl.text = '5';
                              });
                            }),
                            _buildPresetChip(sheetCtx, '🌾 Grocery / Atta', () {
                              setModalState(() {
                                categoryCtrl.text = 'Grocery & Staples';
                                unit = 'kg';
                                stockCtrl.text = '50';
                                lowStockCtrl.text = '10';
                              });
                            }),
                            _buildPresetChip(sheetCtx, '🥤 Drinks / Snacks', () {
                              setModalState(() {
                                categoryCtrl.text = 'Snacks & Munchies';
                                unit = 'packet';
                                stockCtrl.text = '30';
                                lowStockCtrl.text = '5';
                              });
                            }),
                            _buildPresetChip(sheetCtx, '📱 Mobile Acc.', () {
                              setModalState(() {
                                categoryCtrl.text = 'Mobile & Accessories';
                                unit = 'piece';
                                allowBargain = true;
                                stockCtrl.text = '15';
                                lowStockCtrl.text = '3';
                              });
                            }),
                            _buildPresetChip(sheetCtx, '🧼 Personal Care', () {
                              setModalState(() {
                                categoryCtrl.text = 'Personal Care & Beauty';
                                unit = 'piece';
                                stockCtrl.text = '25';
                                lowStockCtrl.text = '5';
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // SECTION 1: PRODUCT IMAGES (Max 10 Images)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Product Images (${productImages.length}/10)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sheetCtx.colorTextMuted,
                          ),
                        ),
                        if (productImages.length < 10)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                            label: const Text('Add Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _showProductImageSourceSheet(
                                sheetCtx,
                                maxAllowed: 10,
                                currentCount: productImages.length,
                                onFilesSelected: (files) {
                                  setModalState(() {
                                    String? firstAddedKey;
                                    for (final f in files) {
                                      if (productImages.length < 10) {
                                        final key = f.path.isNotEmpty
                                            ? f.path
                                            : 'upload_${DateTime.now().microsecondsSinceEpoch}_${f.name}';
                                        productImages.add(key);
                                        pendingXFiles[key] = f;
                                        firstAddedKey ??= key;
                                      }
                                    }
                                    if (firstAddedKey != null && (nameCtrl.text.trim().isEmpty || isDuplicate)) {
                                      runAiAutofill(firstAddedKey);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sheetCtx.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sheetCtx.colorBorder),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...productImages.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final path = entry.value;

                              return Container(
                                width: 64,
                                height: 64,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: sheetCtx.colorBorder),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: AppProductImage(
                                          imageUrl: path,
                                          width: 64,
                                          height: 64,
                                          expand: true,
                                          fit: BoxFit.cover,
                                          fallbackIcon: Icons.image_rounded,
                                          fallbackIconSize: 24,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            final removed = productImages.removeAt(idx);
                                            pendingXFiles.remove(removed);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (productImages.length < 10)
                              InkWell(
                                onTap: () {
                                  _showProductImageSourceSheet(
                                    sheetCtx,
                                    maxAllowed: 10,
                                    currentCount: productImages.length,
                                    onFilesSelected: (files) {
                                      setModalState(() {
                                        String? firstAddedKey;
                                        for (final f in files) {
                                          if (productImages.length < 10) {
                                            final key = f.path.isNotEmpty
                                                ? f.path
                                                : 'upload_${DateTime.now().microsecondsSinceEpoch}_${f.name}';
                                            productImages.add(key);
                                            pendingXFiles[key] = f;
                                            firstAddedKey ??= key;
                                          }
                                        }
                                        if (firstAddedKey != null && (nameCtrl.text.trim().isEmpty || isDuplicate)) {
                                          runAiAutofill(firstAddedKey);
                                        }
                                      });
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: sheetCtx.colorSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_a_photo_outlined, size: 20, color: AppColors.primary),
                                      SizedBox(height: 2),
                                      Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // AI AUTO-FILL MAGIC BANNER & BUTTON
                    if (productImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAiScanning
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : sheetCtx.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: isAiScanning ? 0.35 : 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isAiScanning)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            else
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAiScanning
                                    ? (sheetCtx.isHindi
                                        ? '⚡ AI तस्वीर का विश्लेषण कर रहा है (10+ विवरण)...'
                                        : '⚡ AI analyzing image (extracting 10+ details)...')
                                    : (sheetCtx.isHindi
                                        ? '✨ AI से 10+ उत्पाद विवरण ऑटो-भरें'
                                        : '✨ AI Auto-Fill 10+ Details from Image'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (!isAiScanning)
                              InkWell(
                                onTap: () => runAiAutofill(productImages.first),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    sheetCtx.isHindi ? 'ऑटो-भरें' : 'Auto-Fill',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // SECTION 2: BASIC PRODUCT INFORMATION
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: brandCtrl,
                            decoration: InputDecoration(
                              labelText: sheetCtx.isHindi ? 'ब्रांड (Brand)' : 'Brand / Company',
                              hintText: 'e.g. Fortune, Amul, Tata',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 7,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('inv_add_category_dropdown_${categoryCtrl.text}'),
                            isExpanded: true,
                            initialValue: categoriesList.contains(categoryCtrl.text)
                                ? categoryCtrl.text
                                : (categoriesList.contains('General Store') ? 'General Store' : categoriesList.first),
                            decoration: InputDecoration(
                              labelText: '${sheetCtx.tr('inv_field_category')} *',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                                    tooltip: 'Nayi Custom Category Banayein',
                                    onPressed: () async {
                                      final newCat = await AddCategoryDialog.show(sheetCtx);
                                      if (newCat != null) {
                                        setModalState(() {
                                          if (!categoriesList.contains(newCat.name)) {
                                            categoriesList.insert(0, newCat.name);
                                          }
                                          categoryCtrl.text = newCat.name;
                                        });
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                                    tooltip: 'Manage Categories (Edit/Delete)',
                                    onPressed: () async {
                                      await ManageCategoriesSheet.show(sheetCtx);
                                      final refreshed = catCtrl.categoryNames;
                                      setModalState(() {
                                        categoriesList.clear();
                                        categoriesList.addAll(refreshed.isNotEmpty ? refreshed : CategoryRegistry.canonicalCategories);
                                        if (categoryCtrl.text.isNotEmpty && !categoriesList.contains(categoryCtrl.text)) {
                                          categoriesList.insert(0, categoryCtrl.text);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            items: [
                              ...categoriesList.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c, overflow: TextOverflow.ellipsis),
                                  )),
                              DropdownMenuItem(
                                value: '__ADD_NEW_CATEGORY__',
                                child: Row(
                                  children: const [
                                    Icon(Icons.add_circle_outline, color: AppColors.primary, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      '+ New Category...',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: '__MANAGE_CATEGORIES__',
                                child: Row(
                                  children: const [
                                    Icon(Icons.tune_rounded, color: AppColors.primary, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      '⚙️ Manage Categories...',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) async {
                              if (val == '__ADD_NEW_CATEGORY__') {
                                final newCat = await AddCategoryDialog.show(sheetCtx);
                                if (newCat != null) {
                                  setModalState(() {
                                    if (!categoriesList.contains(newCat.name)) {
                                      categoriesList.insert(0, newCat.name);
                                    }
                                    categoryCtrl.text = newCat.name;
                                  });
                                }
                              } else if (val == '__MANAGE_CATEGORIES__') {
                                await ManageCategoriesSheet.show(sheetCtx);
                                final refreshed = catCtrl.categoryNames;
                                setModalState(() {
                                  categoriesList.clear();
                                  categoriesList.addAll(refreshed.isNotEmpty ? refreshed : CategoryRegistry.canonicalCategories);
                                  if (categoryCtrl.text.isNotEmpty && !categoriesList.contains(categoryCtrl.text)) {
                                    categoriesList.insert(0, categoryCtrl.text);
                                  }
                                });
                              } else if (val != null) {
                                setModalState(() {
                                  categoryCtrl.text = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: '${sheetCtx.tr('inv_field_name')} *',
                        hintText: sheetCtx.isHindi
                            ? 'उदा. Fortune Refined Sunflower Oil 1L'
                            : 'e.g. Fortune Refined Sunflower Oil 1L',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    if (showTitleHelper) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            nameCtrl.text = suggestedTitle;
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  sheetCtx.isHindi ? 'सुझाया गया नाम: ' : 'Suggested Title: ',
                                  style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted),
                                ),
                                Flexible(
                                  child: Text(
                                    suggestedTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  sheetCtx.isHindi ? 'लागू करें' : 'Apply',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary, decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // SECTION 3: PRICING & MARGINS WITH REAL-TIME INTEGRITY FEEDBACK
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: '${sheetCtx.tr('inv_field_selling_price')} *',
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: costPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cost Price (Kharid)',
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🧮 1-TAP PROFIT MARGIN AUTO-CALCULATOR CHIPS
                    if (liveCost > 0) ...[
                      Row(
                        children: [
                          Text(
                            'Auto Margin:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sheetCtx.colorTextMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [10, 15, 20, 25, 30, 40].map((marginPct) {
                                  final calcSellingPrice = (liveCost * (1 + marginPct / 100)).roundToDouble();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          priceCtrl.text = calcSellingPrice.toStringAsFixed(0);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: sheetCtx.colorPrimaryLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          '+$marginPct% (₹${calcSellingPrice.toStringAsFixed(0)})',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: comparePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'MRP / Compare Price',
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: floorPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min Bargain Price',
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),

                    // LIVE PRICING DATA INTEGRITY FEEDBACK BADGES
                    if (isMrpInvalid || isCostInvalid || hasProfit || hasDiscount) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (isMrpInvalid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error),
                              ),
                              child: Text(
                                '⚠️ MRP (₹${liveMrp.toStringAsFixed(0)}) Selling Price se kam hai!',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ),
                          if (isCostInvalid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.warning),
                              ),
                              child: Text(
                                '⚠️ Cost Price (₹${liveCost.toStringAsFixed(0)}) Selling Price se zyada hai!',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                              ),
                            ),
                          if (hasProfit)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: Text(
                                'Est. Profit: +₹${(livePrice - liveCost).toStringAsFixed(0)} (${(((livePrice - liveCost) / livePrice) * 100).toStringAsFixed(1)}% Margin)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ),
                          if (hasDiscount)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Text(
                                'Discount: ${(((liveMrp - livePrice) / liveMrp) * 100).toStringAsFixed(0)}% OFF MRP',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // SECTION 4: STOCK, UNIT & ALERTS
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: sheetCtx.tr('inv_field_stock'),
                              hintText: '20',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('inv_edit_unit_dropdown_$unit'),
                            isExpanded: true,
                            initialValue: ['piece', 'kg', 'gm', 'litre', 'packet', 'box', 'dozen'].contains(unit) ? unit : 'piece',
                            decoration: InputDecoration(labelText: sheetCtx.tr('inv_field_unit')),
                            items: [
                              DropdownMenuItem(value: 'piece', child: Text(sheetCtx.tr('inv_unit_piece'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'kg', child: Text(sheetCtx.tr('inv_unit_kg'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'gm', child: Text(sheetCtx.tr('inv_unit_gm'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'litre', child: Text(sheetCtx.tr('inv_unit_litre'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'packet', child: Text(sheetCtx.tr('inv_unit_packet'), overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 'box', child: Text('Box / Peti', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 'dozen', child: Text('Dozen', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  unit = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Stock Restock Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${sheetCtx.tr('inv_quick_restock')}:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: sheetCtx.colorTextMuted,
                          ),
                        ),
                        for (final count in [5, 10, 25, 50, 100])
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              final curr = int.tryParse(stockCtrl.text.trim()) ?? 0;
                              stockCtrl.text = (curr + count).toString();
                              setModalState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: sheetCtx.colorPrimaryLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                '+$count',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            stockCtrl.text = '0';
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: sheetCtx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: sheetCtx.colorBorder),
                            ),
                            child: Text(
                              '0',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sheetCtx.colorTextMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lowStockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Low Stock Alert Limit',
                              hintText: '5',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight (Kg)',
                              hintText: '1.0',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Barcode / Smart Name-Based SKU Generator
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcodeCtrl,
                            onChanged: (val) {
                              final clean = val.trim();
                              if (clean.length >= 8) {
                                applyMasterCatalogAutofill(clean, forceOverwrite: nameCtrl.text.trim().isEmpty || nameCtrl.text.trim() == 'New Product');
                              }
                              setModalState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: sheetCtx.tr('inv_field_barcode'),
                              hintText: 'e.g. FORTUNE-RICE-389 or 890123456789',
                              suffixIcon: IconButton(
                                tooltip: sheetCtx.isHindi ? 'कैमरा से बारकोड स्कैन करें' : 'Scan Barcode with Camera',
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                                onPressed: () async {
                                  await MobileBarcodeScannerDialog.show(
                                    sheetCtx,
                                    title: sheetCtx.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
                                    autoCloseOnSuccess: true,
                                    successMessage: sheetCtx.isHindi ? '✓ बारकोड दर्ज हुआ!' : '✓ Barcode Captured!',
                                    onBarcodeScanned: (scanned) async {
                                      final clean = scanned.trim();
                                      if (clean.isNotEmpty) {
                                        applyMasterCatalogAutofill(clean, forceOverwrite: true);
                                        setModalState(() {});
                                      }
                                      return true;
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Generate SKU'),
                          onPressed: () {
                            final generatedSku = _generateSmartSku(nameCtrl.text);
                            barcodeCtrl.text = generatedSku;
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              SnackBar(
                                content: Text('Auto-generated SKU: $generatedSku'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    () {
                      final currentBarcode = barcodeCtrl.text.trim();
                      if (lastAutofilledBarcode != currentBarcode && lastAutofilledBarcode != null) {
                        // Tracking manual barcode edits
                      }
                      final masterMatch = currentBarcode.length >= 8
                          ? SmartBarcodeCatalogService.lookupSync(currentBarcode)
                          : null;
                      if (masterMatch == null) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${masterMatch.brand}: ${masterMatch.name}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      sheetCtx.isHindi
                                          ? 'मास्टर कैटलॉग: ${masterMatch.category} • MRP ₹${masterMatch.mrp.toStringAsFixed(0)}'
                                          : 'Master Catalog: ${masterMatch.category} • MRP ₹${masterMatch.mrp.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: sheetCtx.colorTextMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                ),
                                onPressed: () {
                                  lastAutofilledBarcode = null;
                                  applyMasterCatalogAutofill(currentBarcode);
                                },
                                child: Text(
                                  sheetCtx.isHindi ? 'पुनः भरें' : 'Refill',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }(),
                    const SizedBox(height: 12),

                    // SECTION 5: DYNAMIC CUSTOM SPECIFICATIONS & ATTRIBUTES
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Custom Attributes (${customAttrPairs.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sheetCtx.colorTextMuted,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Attribute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            setModalState(() {
                              customAttrPairs.add(MapEntry(
                                TextEditingController(),
                                TextEditingController(),
                              ));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // QUICK ATTRIBUTE TAG CLOUD CHIPS
                    Row(
                      children: [
                        Text(
                          'Quick Add:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sheetCtx.colorTextMuted),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildAttrChip(sheetCtx, '+ Weight/Vol', 'Weight', '1L / 1Kg', customAttrPairs, setModalState),
                                _buildAttrChip(sheetCtx, '+ Size', 'Size', 'Medium / XL', customAttrPairs, setModalState),
                                _buildAttrChip(sheetCtx, '+ Flavor', 'Flavor', 'Vanilla / Mango', customAttrPairs, setModalState),
                                _buildAttrChip(sheetCtx, '+ Warranty', 'Warranty', '1 Year', customAttrPairs, setModalState),
                                _buildAttrChip(sheetCtx, '+ Color', 'Color', 'Black / Blue', customAttrPairs, setModalState),
                                _buildAttrChip(sheetCtx, '+ Model', 'Model', '2026 Model', customAttrPairs, setModalState),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customAttrPairs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...customAttrPairs.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pair = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: pair.key,
                                  decoration: const InputDecoration(
                                    hintText: 'Key (e.g. Size, Flavor)',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: pair.value,
                                  decoration: const InputDecoration(
                                    hintText: 'Value (e.g. 1L, Vanilla)',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: sheetCtx.colorTextMuted),
                                onPressed: () {
                                  setModalState(() {
                                    pair.key.dispose();
                                    pair.value.dispose();
                                    customAttrPairs.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),

                    // Description / Notes
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        hintText: 'Product specifications, usage or notes...',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // TOGGLES ROW (Allow Bargain, Show Price Online, Featured)
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Show Price to Customers (Online)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isPricePublic
                              ? 'Price is publicly visible online on digital storefront'
                              : '🔒 Price Hidden online (Shows "Price on Request" - Customers visit or contact you to bargain)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isPricePublic ? AppColors.textSecondary : AppColors.primary,
                            fontWeight: isPricePublic ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                        value: isPricePublic,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setModalState(() => isPricePublic = val),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Allow Customer Bargain / Negotiate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        value: allowBargain,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setModalState(() => allowBargain = val),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Featured Product Badge', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        value: isFeatured,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setModalState(() => isFeatured = val),
                      ),
                    ),
                    // 🌟 LIVE CUSTOMER APP PREVIEW CARD
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sheetCtx.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sheetCtx.colorBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.visibility_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    sheetCtx.isHindi ? 'ग्राहक को कैसा दिखेगा (Live Preview)' : 'Customer App Preview',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: sheetCtx.colorTextMuted),
                                  ),
                                ],
                              ),
                              if (hasDiscount)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${(((liveMrp - livePrice) / liveMrp) * 100).toStringAsFixed(0)}% OFF',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: sheetCtx.colorSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: sheetCtx.colorBorder),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AppProductImage(
                                  imageUrl: productImages.isNotEmpty ? productImages.first : '',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.inventory_2_outlined,
                                  fallbackIconSize: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (brandCtrl.text.trim().isNotEmpty)
                                      Text(
                                        brandCtrl.text.trim().toUpperCase(),
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5),
                                      ),
                                    Text(
                                      nameCtrl.text.trim().isNotEmpty
                                          ? nameCtrl.text.trim()
                                          : (sheetCtx.isHindi ? 'उत्पाद का नाम यहाँ दिखेगा' : 'Product name will appear here'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: nameCtrl.text.trim().isNotEmpty ? sheetCtx.colorTextPrimary : sheetCtx.colorTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          livePrice > 0 ? '₹${livePrice.toStringAsFixed(0)}' : '₹--',
                                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: sheetCtx.colorTextPrimary),
                                        ),
                                        if (liveMrp > livePrice) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹${liveMrp.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: sheetCtx.colorTextMuted,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                        if (unit.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '/ $unit',
                                            style: TextStyle(fontSize: 11, color: sheetCtx.colorTextSecondary),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons Row (Save / Delete)
                    Row(
                      children: [
                        if (isEdit)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                            tooltip: 'Delete Product',
                            onPressed: () {
                              _confirmDeleteProduct(sheetCtx, initialProduct.id, () {
                                Navigator.pop(sheetCtx);
                              });
                            },
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(sheetCtx.tr('btn_cancel')),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(130, 46),
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  final price = double.tryParse(priceCtrl.text) ?? 0.0;
                                  final costPrice = double.tryParse(costPriceCtrl.text) ?? 0.0;
                                  final comparePrice = double.tryParse(comparePriceCtrl.text) ?? 0.0;
                                  final floorPrice = double.tryParse(floorPriceCtrl.text) ?? 0.0;
                                  final stock = int.tryParse(stockCtrl.text) ?? 0;
                                  final lowStock = int.tryParse(lowStockCtrl.text) ?? 5;
                                  final weight = double.tryParse(weightCtrl.text) ?? 0.0;

                                  // Constraint 1: Name validation
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text(sheetCtx.tr('inv_val_name'))),
                                    );
                                    return;
                                  }

                                  // Constraint 2: Selling price validation
                                  if (price <= 0) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text(sheetCtx.tr('inv_val_selling_price'))),
                                    );
                                    return;
                                  }

                                  // Constraint 3: MRP (Compare Price) Data Integrity Constraint
                                  if (comparePrice > 0 && comparePrice < price) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${sheetCtx.tr('inv_val_mrp_less')} (₹${comparePrice.toStringAsFixed(0)} < ₹${price.toStringAsFixed(0)})',
                                        ),
                                        backgroundColor: AppColors.error,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }

                                  // Constraint 4: Cost Price (Kharid) Constraint
                                  if (costPrice > price) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${sheetCtx.tr('inv_val_cost_more')} (₹${costPrice.toStringAsFixed(0)} > ₹${price.toStringAsFixed(0)})',
                                        ),
                                        backgroundColor: AppColors.error,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }

                                  // Constraint 5: Floor Price Constraint
                                  if (floorPrice > price) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${sheetCtx.tr('inv_val_floor_more')} (₹${floorPrice.toStringAsFixed(0)} > ₹${price.toStringAsFixed(0)})',
                                        ),
                                        backgroundColor: AppColors.error,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }

                                  // Constraint 6: Stock Validation
                                  if (stock < 0) {
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(
                                        content: Text(sheetCtx.tr('inv_val_required')),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  // Disable button for fast UI feedback before sheet dismissal
                                  setModalState(() => isSaving = true);
                                  final prodController = context.read<ProductController>();

                                  final attr = <String, dynamic>{};
                                  if (brandCtrl.text.trim().isNotEmpty) {
                                    attr['brand'] = brandCtrl.text.trim();
                                  }
                                  attr['unit'] = unit;
                                  for (var pair in customAttrPairs) {
                                    final k = pair.key.text.trim();
                                    final v = pair.value.text.trim();
                                    if (k.isNotEmpty && v.isNotEmpty) {
                                      attr[k] = v;
                                    }
                                  }

                                  final imagesList = List<String>.from(productImages);
                                  final localXFiles = <XFile>[];
                                  for (final img in productImages) {
                                    if (pendingXFiles.containsKey(img)) {
                                      localXFiles.add(pendingXFiles[img]!);
                                    } else if (!isServerImageUrl(img)) {
                                      localXFiles.add(XFile(img));
                                    }
                                  }

                                  // 1. Instantly close modal sheet (0ms waiting for merchant)
                                  Navigator.pop(sheetCtx);

                                  // 2. Instantly show success confirmation toast
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isDuplicate
                                                  ? (context.isHindi ? '✓ उत्पाद की प्रति बनाई गई' : '✓ Product duplicated successfully')
                                                  : (isEdit
                                                      ? context.tr('inv_toast_updated')
                                                      : context.tr('inv_toast_added')),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );

                                  // 3. Fire-and-forget 0ms optimistic save & background cloud sync
                                  if (isEdit) {
                                    final resolvedSku = barcodeCtrl.text.trim().isNotEmpty
                                        ? barcodeCtrl.text.trim()
                                        : (initialProduct.sku.isNotEmpty ? initialProduct.sku : initialProduct.barcode);
                                    prodController.editProduct(
                                      initialProduct.id,
                                      {
                                        'name': name,
                                        'description': descriptionCtrl.text.trim(),
                                        'price': price,
                                        'cost_price': costPrice,
                                        'compare_price': comparePrice,
                                        'floor_price': floorPrice,
                                        'allow_bargain': allowBargain,
                                        'stock': stock,
                                        'stock_quantity': stock,
                                        'unit': unit,
                                        'category': categoryCtrl.text.trim(),
                                        'barcode': barcodeCtrl.text.trim(),
                                        'sku': resolvedSku,
                                        'low_stock_threshold': lowStock,
                                        'min_stock': lowStock,
                                        'weight': weight,
                                        'images': imagesList,
                                        'is_active': isActive,
                                        'is_featured': isFeatured,
                                        'is_price_public': isPricePublic,
                                        'attributes': attr,
                                      },
                                      localImageFiles: localXFiles,
                                    );
                                  } else {
                                    prodController.addProduct(
                                      name: name,
                                      price: price,
                                      costPrice: costPrice,
                                      comparePrice: comparePrice,
                                      floorPrice: floorPrice,
                                      allowBargain: allowBargain,
                                      stock: stock,
                                      unit: unit,
                                      category: categoryCtrl.text.trim(),
                                      barcode: barcodeCtrl.text.trim(),
                                      lowStockThreshold: lowStock,
                                      description: descriptionCtrl.text.trim(),
                                      weight: weight,
                                      isFeatured: isFeatured,
                                      isPricePublic: isPricePublic,
                                      images: imagesList,
                                      localImageFiles: localXFiles,
                                      attributes: attr,
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(sheetCtx.tr('btn_save')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, dynamic productId, VoidCallback onSuccess) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ProductController>().deleteProduct(productId);
              if (success && context.mounted) {
                onSuccess();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted from catalog')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context) {
    PlatformFile? selectedFile;
    Uint8List? fileBytes;
    bool updateExisting = true;
    bool isUploading = false;
    BulkImportResult? importResult;
    String? uploadError;

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: ctx.colorSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // HEADER
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ctx.colorPrimaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.table_view_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ctx.tr('bulk_import_title'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: ctx.colorTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    ctx.tr('bulk_import_subtitle'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ctx.colorTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isUploading)
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: ctx.colorBorder),
                        const SizedBox(height: 16),

                        // RESULT SUCCESS VIEW
                        if (importResult != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
                                const SizedBox(height: 8),
                                Text(
                                  ctx.tr('bulk_import_success_title'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4 STAT METRICS CARDS
                          Row(
                            children: [
                              Expanded(
                                child: AppStatCard(
                                  title: ctx.tr('bulk_import_stat_total'),
                                  value: importResult!.totalRows.toString(),
                                  subtitle: 'Rows in file',
                                  icon: Icons.format_list_numbered_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppStatCard(
                                  title: ctx.tr('bulk_import_stat_imported'),
                                  value: importResult!.importedCount.toString(),
                                  subtitle: 'Added to catalog',
                                  icon: Icons.add_circle_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: AppStatCard(
                                  title: ctx.tr('bulk_import_stat_updated'),
                                  value: importResult!.updatedCount.toString(),
                                  subtitle: 'Stock / price updated',
                                  icon: Icons.sync_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppStatCard(
                                  title: ctx.tr('bulk_import_stat_skipped'),
                                  value: importResult!.skippedCount.toString(),
                                  subtitle: 'Duplicates / errors',
                                  icon: Icons.error_outline_rounded,
                                  isAlert: importResult!.skippedCount > 0,
                                ),
                              ),
                            ],
                          ),

                          // ROW ERRORS ACCORDION
                          if (importResult!.errors.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ctx.colorSurfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ctx.colorBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${ctx.tr('bulk_import_errors_heading')} (${importResult!.errors.length})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: ctx.colorTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 140),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: importResult!.errors.map((err) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Text(
                                              '• $err',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: ctx.colorTextSecondary,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text(ctx.tr('bulk_import_close_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.filter_list_rounded, size: 16),
                                  label: Text(
                                    ctx.isHindi ? 'सूची देखें' : 'View List',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    setState(() {
                                      _showOnlyMissingBarcode = true;
                                      _showOnlyLowStock = false;
                                      _showOnlyPriceHidden = false;
                                      _showOnlyDiscounted = false;
                                      _selectedCategory = 'All';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                                  label: Text(
                                    ctx.isHindi ? 'असेंबली स्कैन' : 'Batch Scan',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    final prodCtrl = context.read<ProductController>();
                                    final missingList = prodCtrl.products.where((item) => item.barcode.trim().isEmpty).toList();
                                    if (missingList.isNotEmpty) {
                                      _launchBatchBarcodePairing(context, missingList);
                                    } else {
                                      setState(() {
                                        _showOnlyMissingBarcode = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else if (isUploading) ...[
                          // PROCESSING & BACKGROUND PROGRESS
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(color: AppColors.primary),
                                const SizedBox(height: 20),
                                Text(
                                  ctx.tr('bulk_import_processing'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: ctx.colorTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ctx.tr('bulk_import_validating'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ctx.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // STEP 1: DOWNLOAD TEMPLATES
                          AppSectionHeader(
                            title: ctx.tr('bulk_import_step_template'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ctx.tr('bulk_import_step_template_desc'),
                            style: TextStyle(fontSize: 12, color: ctx.colorTextSecondary),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFF107C41).withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF107C41)),
                                label: Text(
                                  ctx.tr('bulk_import_download_excel'),
                                  style: const TextStyle(color: Color(0xFF107C41), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.productsImportTemplateXlsx}');
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                                label: Text(
                                  ctx.tr('bulk_import_download_csv'),
                                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.productsImportTemplateCsv}');
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // STEP 2: SELECT FILE
                          AppSectionHeader(
                            title: ctx.tr('bulk_import_step_upload'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ctx.tr('bulk_import_step_upload_desc'),
                            style: TextStyle(fontSize: 12, color: ctx.colorTextSecondary),
                          ),
                          const SizedBox(height: 10),

                          if (selectedFile == null) ...[
                            InkWell(
                              onTap: () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['xlsx', 'xls', 'csv'],
                                    withData: kIsWeb,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    final file = result.files.first;
                                    Uint8List? bytes = file.bytes;
                                    if (bytes == null && !kIsWeb && file.path != null) {
                                      final localFile = File(file.path!);
                                      if (await localFile.exists()) {
                                        bytes = await localFile.readAsBytes();
                                      }
                                    }
                                    if (bytes != null && bytes.isNotEmpty) {
                                      setModalState(() {
                                        selectedFile = file;
                                        fileBytes = bytes;
                                        uploadError = null;
                                      });
                                    } else {
                                      setModalState(() {
                                        uploadError = 'Unable to read selected file. Please select again.';
                                      });
                                    }
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    uploadError = 'Error selecting file: ${e.toString()}';
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: ctx.colorSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: ctx.colorPrimaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 28,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      ctx.tr('bulk_import_btn_browse'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Supports Excel (.xlsx, .xls) and CSV (.csv)',
                                      style: TextStyle(fontSize: 11, color: ctx.colorTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: selectedFile!.name.toLowerCase().endsWith('.xlsx')
                                          ? const Color(0xFF107C41).withValues(alpha: 0.1)
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      selectedFile!.name.toLowerCase().endsWith('.xlsx')
                                          ? Icons.table_chart_rounded
                                          : Icons.description_rounded,
                                      color: selectedFile!.name.toLowerCase().endsWith('.xlsx')
                                          ? const Color(0xFF107C41)
                                          : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedFile!.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: ctx.colorTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB • ${ctx.tr('bulk_import_file_selected')}',
                                          style: TextStyle(fontSize: 11, color: ctx.colorTextSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    color: ctx.colorTextMuted,
                                    tooltip: 'Remove',
                                    onPressed: () {
                                      setModalState(() {
                                        selectedFile = null;
                                        fileBytes = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // STEP 3: OPTIONS
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              ctx.tr('bulk_import_update_existing_title'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                            ),
                            subtitle: Text(
                              ctx.tr('bulk_import_update_existing_subtitle'),
                              style: TextStyle(fontSize: 11, color: ctx.colorTextSecondary),
                            ),
                            value: updateExisting,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              setModalState(() => updateExisting = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // ERROR DISPLAY IF ANY
                          if (uploadError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      uploadError!,
                                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // SUBMIT BUTTON
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: selectedFile == null || fileBytes == null
                                ? null
                                : () async {
                                    setModalState(() {
                                      isUploading = true;
                                      uploadError = null;
                                    });

                                    final prodController = context.read<ProductController>();
                                    final res = await prodController.bulkImportProducts(
                                      fileBytes: fileBytes!,
                                      fileName: selectedFile!.name,
                                      updateExisting: updateExisting,
                                    );

                                    setModalState(() {
                                      isUploading = false;
                                      if (res != null) {
                                        importResult = res;
                                      } else {
                                        uploadError = prodController.errorMessage ??
                                            'Failed to import file. Please verify columns and file format.';
                                      }
                                    });
                                  },
                            child: Text(
                              ctx.tr('bulk_import_btn_start'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prodController = context.watch<ProductController>();
    final allProducts = prodController.products;

    // 0ms instant cached recompute - only computes when filters or products mutate
    _recomputeFilteredProducts(allProducts);

    final sortedCategories = _cachedSortedCategories;
    final lowStockCount = _cachedLowStockCount;
    final hiddenPriceCount = _cachedHiddenPriceCount;
    final discountedCount = _cachedDiscountedCount;
    final missingBarcodeCount = _cachedMissingBarcodeCount;
    final nearExpiryCount = _cachedNearExpiryCount;
    final displayProducts = _cachedDisplayProducts;

    return MerchantShell(
      currentIndex: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: context.colorSurface,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: context.colorBorder,
              height: 1.0,
            ),
          ),
          title: Text(
            context.tr('inv_title'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colorTextPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              tooltip: context.tr('price_checker_title'),
              onPressed: () => PriceCheckerDialog.show(context),
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined, size: 22),
              tooltip: context.isHindi ? 'बारकोड प्रिंट स्टूडियो' : 'Barcode Print Studio',
              onPressed: () => BarcodeSheetStudioScreen.show(context),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
              tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              onSelected: (val) async {
                switch (val) {
                  case 'barcode_studio':
                    BarcodeSheetStudioScreen.show(context);
                    break;
                  case 'import':
                    _showBulkImportDialog(context);
                    break;
                  case 'batch_scan':
                    final unmapped = displayProducts.where((p) => p.barcode.trim().isEmpty).toList();
                    if (unmapped.isNotEmpty) {
                      _launchBatchBarcodePairing(context, unmapped);
                    } else {
                      CustomSnackbar.showSuccess(
                        context,
                        context.isHindi ? 'सभी उत्पादों में बारकोड मौजूद है' : 'All products have barcodes assigned',
                      );
                    }
                    break;
                  case 'refresh':
                    final prod = context.read<ProductController>();
                    await prod.loadProducts(forceRefresh: true);
                    if (context.mounted) {
                      if (prod.hasError) {
                        CustomSnackbar.showError(
                          context,
                          prod.errorMessage ?? (context.isHindi ? 'कैटलॉग रिफ्रेश करने में विफल' : 'Failed to refresh product catalog'),
                        );
                      } else {
                        CustomSnackbar.showSuccess(
                          context,
                          context.isHindi ? '✓ उत्पाद कैटलॉग रिफ्रेश हो गया' : '✓ Product Catalog Refreshed',
                          duration: const Duration(seconds: 1),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'barcode_studio',
                  child: Row(
                    children: [
                      const Icon(Icons.print_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'बारकोड प्रिंट स्टूडियो' : 'Barcode Print Studio'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.tr('bulk_import_open_dialog_btn')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'batch_scan',
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'असेंबली बारकोड पेयरिंग' : 'Batch Barcode Pairing'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: ctx.colorTextPrimary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'कैटलॉग रिफ्रेश करें' : 'Refresh Catalog'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            context.tr('inv_add_btn'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showAddProductDialog(context),
        ),
        body: ResponsiveContainer(
          maxWidth: 1200,
          child: Column(
            children: [
              // 1. FAST SEARCH BAR & SORT SELECTION ROW
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: AppProductSearchBar(
                        controller: _searchController,
                        hintText: context.isHindi
                            ? 'नाम, बारकोड, SKU, ब्रांड से खोजें...'
                            : 'Search by Name, Barcode, SKU, Brand...',
                        showBarcodeScanner: true,
                        onBarcodeScan: () {
                          PriceCheckerDialog.show(context, initialQuery: _searchController.text.trim());
                        },
                        onChanged: (query) {
                          setState(() {
                            _searchQuery = query.trim();
                          });
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // SORT BUTTON
                    Material(
                      color: _sortOption != InventorySortOption.newest
                          ? context.colorPrimaryLight
                          : context.colorSurface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _showSortBottomSheet(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _sortOption != InventorySortOption.newest
                                  ? AppColors.primary
                                  : context.colorBorder,
                              width: _sortOption != InventorySortOption.newest ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortOption.icon,
                                size: 17,
                                color: _sortOption != InventorySortOption.newest
                                    ? AppColors.primary
                                    : context.colorTextSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _sortOption.getShortBadge(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _sortOption != InventorySortOption.newest
                                      ? AppColors.primary
                                      : context.colorTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: _sortOption != InventorySortOption.newest
                                    ? AppColors.primary
                                    : context.colorTextMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. HORIZONTAL QUICK FILTER PILLS (All, Stock, Price Hidden, Categories)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      context: context,
                      label: context.isHindi ? 'सभी' : 'All',
                      count: allProducts.length,
                      isSelected: !_showOnlyLowStock &&
                          !_showOnlyPriceHidden &&
                          !_showOnlyDiscounted &&
                          !_showOnlyMissingBarcode &&
                          !_showOnlyNearExpiry &&
                          _selectedCategory == 'All',
                      onTap: () {
                        setState(() {
                          _showOnlyLowStock = false;
                          _showOnlyPriceHidden = false;
                          _showOnlyDiscounted = false;
                          _showOnlyMissingBarcode = false;
                          _showOnlyNearExpiry = false;
                          _selectedCategory = 'All';
                        });
                      },
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.isHindi ? 'कम स्टॉक' : 'Low Stock',
                      icon: Icons.warning_amber_rounded,
                      count: lowStockCount,
                      isSelected: _showOnlyLowStock,
                      onTap: () {
                        setState(() {
                          _showOnlyLowStock = !_showOnlyLowStock;
                        });
                      },
                    ),
                    if (nearExpiryCount > 0)
                      _buildFilterChip(
                        context: context,
                        label: context.isHindi ? 'एक्सपायरी अलर्ट' : 'Near Expiry',
                        icon: Icons.hourglass_top_rounded,
                        count: nearExpiryCount,
                        isSelected: _showOnlyNearExpiry,
                        onTap: () {
                          setState(() {
                            _showOnlyNearExpiry = !_showOnlyNearExpiry;
                          });
                        },
                      ),
                    _buildFilterChip(
                      context: context,
                      label: context.isHindi ? 'हिडन प्राइस' : 'Hidden Price',
                      icon: Icons.lock_outline_rounded,
                      count: hiddenPriceCount,
                      isSelected: _showOnlyPriceHidden,
                      onTap: () {
                        setState(() {
                          _showOnlyPriceHidden = !_showOnlyPriceHidden;
                        });
                      },
                    ),
                    if (missingBarcodeCount > 0)
                      _buildFilterChip(
                        context: context,
                        label: context.isHindi ? 'बिना बारकोड' : 'No Barcode',
                        icon: Icons.qr_code_scanner_rounded,
                        count: missingBarcodeCount,
                        isSelected: _showOnlyMissingBarcode,
                        onTap: () {
                          setState(() {
                            _showOnlyMissingBarcode = !_showOnlyMissingBarcode;
                          });
                        },
                      ),
                    if (discountedCount > 0)
                      _buildFilterChip(
                        context: context,
                        label: context.isHindi ? 'छूट / ऑफर' : 'On Sale',
                        icon: Icons.local_offer_outlined,
                        count: discountedCount,
                        isSelected: _showOnlyDiscounted,
                        onTap: () {
                          setState(() {
                            _showOnlyDiscounted = !_showOnlyDiscounted;
                          });
                        },
                      ),
                    for (final cat in sortedCategories)
                      _buildFilterChip(
                        context: context,
                        label: cat,
                        isSelected: _selectedCategory.toLowerCase() == cat.toLowerCase(),
                        onTap: () {
                          setState(() {
                            _selectedCategory = (_selectedCategory.toLowerCase() == cat.toLowerCase()) ? 'All' : cat;
                          });
                        },
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        context.isHindi ? 'कैटेगरी सेटिंग्स' : 'Categories',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                      onPressed: () => ManageCategoriesSheet.show(context),
                    ),
                  ],
                ),
              ),

              // 3. RESULTS SUMMARY STRIP
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.isHindi
                            ? '${allProducts.length} में से ${displayProducts.length} उत्पाद'
                            : 'Showing ${displayProducts.length} of ${allProducts.length} items',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _showOnlyLowStock ||
                        _showOnlyPriceHidden ||
                        _showOnlyDiscounted ||
                        _showOnlyMissingBarcode ||
                        _showOnlyNearExpiry ||
                        _selectedCategory != 'All' ||
                        _sortOption != InventorySortOption.newest)
                      InkWell(
                        onTap: _clearAllFilters,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.clear_all_rounded, size: 14, color: AppColors.error),
                              const SizedBox(width: 3),
                              Text(
                                context.isHindi ? 'फिल्टर रीसेट' : 'Reset All',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Products Catalog Grid / List
              Expanded(
                child: prodController.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : allProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 54, color: context.colorTextMuted),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('inv_empty_title'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: context.colorTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      label: Text(context.tr('inv_add_btn')),
                                      onPressed: () => _showAddProductDialog(context),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.file_upload_outlined),
                                      label: Text(context.tr('bulk_import_open_dialog_btn')),
                                      onPressed: () => _showBulkImportDialog(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : displayProducts.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Builder(
                                    builder: (ctx) {
                                      final fuzzySuggestion = _searchQuery.isNotEmpty
                                          ? SearchFuzzyUtils.findClosestFuzzySuggestion(_searchQuery, allProducts)
                                          : null;

                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off_rounded, size: 54, color: context.colorTextMuted),
                                          const SizedBox(height: 12),
                                          Text(
                                            context.isHindi ? 'कोई उत्पाद नहीं मिला' : 'No matching products found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: context.colorTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? (context.isHindi
                                                    ? '"$_searchQuery" के लिए कोई परिणाम नहीं मिला'
                                                    : 'No results found matching "$_searchQuery"')
                                                : (context.isHindi
                                                    ? 'चयनित फिल्टर के लिए कोई उत्पाद उपलब्ध नहीं है'
                                                    : 'No products match the selected filters'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                                          ),
                                          if (fuzzySuggestion != null) ...[
                                            const SizedBox(height: 14),
                                            InkWell(
                                              onTap: () {
                                                _searchController.text = fuzzySuggestion.name;
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: context.colorPrimaryLight,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      context.isHindi ? 'क्या आपका मतलब: ' : 'Did you mean: ',
                                                      style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                                                    ),
                                                    Text(
                                                      fuzzySuggestion.name,
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 16),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            alignment: WrapAlignment.center,
                                            children: [
                                              if (_searchQuery.isNotEmpty)
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  icon: const Icon(Icons.add_rounded, size: 16),
                                                  label: Text(
                                                    context.isHindi ? '+ "$_searchQuery" इन्वेंट्री में जोड़ें' : '+ Add "$_searchQuery" to Inventory',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                  ),
                                                  onPressed: () => _showAddProductDialog(context, initialName: _searchQuery),
                                                ),
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.clear_all_rounded, size: 16),
                                                label: Text(context.isHindi ? 'सभी फिल्टर हटाएं' : 'Reset Filters'),
                                                onPressed: _clearAllFilters,
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_showOnlyMissingBarcode && displayProducts.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: context.colorPrimaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.isHindi
                                                    ? 'बिना बारकोड के ${displayProducts.length} उत्पाद'
                                                    : '${displayProducts.length} Products Without Barcode',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: context.colorTextPrimary,
                                                ),
                                              ),
                                              Text(
                                                context.isHindi
                                                    ? 'कैमरा से लगातार एक-एक करके बारकोड जोड़ें'
                                                    : 'Continuous rapid conveyor-belt barcode pairing',
                                                style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                                          label: Text(
                                            context.isHindi ? 'असेंबली स्कैन' : 'Batch Scan',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _launchBatchBarcodePairing(context, displayProducts),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);
                                    final aspectRatio = width > 700 ? 0.78 : 0.67;

                                    return GridView.builder(
                                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: aspectRatio,
                                      ),
                                      itemCount: displayProducts.length,
                                      itemBuilder: (context, index) {
                                        final p = displayProducts[index];
                                        return _ProductGridCard(
                                          key: ValueKey(p.id),
                                          product: p,
                                          highlightQuery: _searchQuery,
                                          onTap: () => _navigateToProductDetails(context, p),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Production Ultra-Clean Minimalist Product Grid Card
/// Displays ONLY Image, Category, Name, and Price as requested.
class _ProductGridCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final String? highlightQuery;

  const _ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final categoryDisplay = formatCategoryName(p.category);

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. PRODUCT IMAGE CONTAINER
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colorBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppProductImage(
                    imageUrl: p.imageUrl,
                    expand: true,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(10),
                    fallbackIcon: Icons.inventory_2_outlined,
                    fallbackIconSize: 32,
                  ),
                  if (p.isExpired)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.isHindi ? 'एक्सपायर्ड' : 'Expired',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (p.isNearExpiry)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.daysUntilExpiry}d left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. CATEGORY
          if (categoryDisplay.isNotEmpty)
            Text(
              categoryDisplay,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.colorTextMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // 3. PRODUCT NAME (Clean 2-line clamping with keyword highlighting)
          AppHighlightedText(
            text: p.name,
            query: highlightQuery ?? '',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: context.colorTextPrimary,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),

          // 4. PRICE & UNIT
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${p.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: context.colorTextPrimary,
                    fontSize: 15.5,
                    letterSpacing: -0.3,
                  ),
                ),
                if (p.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    '/ ${p.unit}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.colorTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Public Top-Level Helper Function to Launch Add / Edit Product Modal Sheet across all screens
void showAddProductDialog(BuildContext context, {ProductModel? initialProduct, bool isDuplicate = false, String? initialBarcode}) {
  final state = context.findAncestorStateOfType<_InventoryScreenState>();
  if (state != null) {
    state._showAddProductDialog(context, initialProduct: initialProduct, isDuplicate: isDuplicate, initialBarcode: initialBarcode);
  } else {
    final invState = _InventoryScreenState();
    invState._showAddProductDialog(context, initialProduct: initialProduct, isDuplicate: isDuplicate, initialBarcode: initialBarcode);
  }
}
