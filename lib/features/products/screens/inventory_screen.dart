import 'dart:async';
import 'dart:convert' show base64Encode, base64Decode;
import 'dart:io' show File;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../dashboard/repositories/ai_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../models/bulk_import_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/pending_product_image.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/manage_categories_sheet.dart';
import '../widgets/color_shade_selector.dart';
import 'product_photo_capture_screen.dart';
import '../../../core/widgets/price_checker_dialog.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../widgets/batch_barcode_pairing_dialog.dart';
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
      _checkAndRecoverLostCameraData();
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

  /// Recovers camera photo if Android OS destroyed MainActivity to free RAM on low-spec phones (e.g. Vivo T3x)
  Future<void> _checkAndRecoverLostCameraData() async {
    if (kIsWeb) return;
    try {
      final picker = ImagePicker();
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final (normalizedFile, normalizedBytes) =
            await normalizeXFile(response.file!);
        if (mounted) {
          _showAddProductDialog(
            context,
            initialImages: [(normalizedFile, normalizedBytes)],
          );
        }
      } else if (response.files != null && response.files!.isNotEmpty) {
        final List<(XFile, Uint8List?)> recovered = [];
        for (final f in response.files!) {
          final (normF, normBytes) = await normalizeXFile(f);
          recovered.add((normF, normBytes));
        }
        if (mounted && recovered.isNotEmpty) {
          _showAddProductDialog(context, initialImages: recovered);
        }
      }
    } catch (e) {
      debugPrint('[InventoryScreen] retrieveLostData check: $e');
    }
  }

  /// Displays a clean bottom sheet modal offering Camera capture or Device Gallery selection
  void _showProductImageSourceSheet(
    BuildContext context, {
    required Function(List<(XFile, Uint8List?)> files) onFilesSelected,
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
      builder: (sheetCtx) => Material(
        color: sheetCtx.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
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
                  sheetCtx.isHindi ? '📸 AI मैजिक कैमरा (स्टूडियो बैकग्राउंड + विवरण)' : '📸 AI Magic Camera (Studio Photo + Details)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: sheetCtx.colorTextPrimary),
                ),
                subtitle: Text(
                  sheetCtx.tr('inv_camera_capture_subtitle'),
                  style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    final capturedFiles = await Navigator.of(context).push<
                      List<(XFile, Uint8List?)>
                    >(
                      MaterialPageRoute(
                        builder: (_) => ProductPhotoCaptureScreen(
                          maxPhotos: maxAllowed - currentCount,
                        ),
                      ),
                    );
                    if (capturedFiles != null &&
                        capturedFiles.isNotEmpty &&
                        context.mounted) {
                      onFilesSelected(capturedFiles);
                    }
                  } catch (e) {
                    debugPrint('[InventoryScreen] Camera picker error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.isHindi
                                ? 'कैमरा से फोटो लेने में समस्या आई। कृपया दोबारा प्रयास करें।'
                                : 'Failed to capture photo. Please try again.',
                          ),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
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
                      maxWidth: 1600,
                      maxHeight: 1600,
                      requestFullMetadata: false,
                    );
                    if (pickedFiles.isNotEmpty) {
                      final remaining = maxAllowed - currentCount;
                      final selected = pickedFiles.take(remaining).toList();
                      final List<(XFile, Uint8List?)> resultList = [];
                      for (final f in selected) {
                        final (normalizedFile, normalizedBytes) =
                            await normalizeXFile(f);
                        resultList.add((normalizedFile, normalizedBytes));
                      }
                      onFilesSelected(resultList);
                    }
                  } on PlatformException catch (pe) {
                    debugPrint('[InventoryScreen] MultiImage PlatformException: ${pe.code} - ${pe.message}');
                    if (context.mounted) {
                      final msg = pe.code == 'photo_access_denied'
                          ? (context.isHindi
                              ? 'गैलरी परमिशन नहीं मिली। कृपया सेटिंग्स से परमिशन दें।'
                              : 'Photo permission denied. Please allow photos access.')
                          : (context.isHindi
                              ? 'गैलरी खोलने में समस्या आई: ${pe.message ?? pe.code}'
                              : 'Could not open gallery: ${pe.message ?? pe.code}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('[InventoryScreen] MultiImage picker error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.isHindi
                                ? 'गैलरी से फोटो लोड करने में समस्या आई।'
                                : 'Failed to select photos from gallery.',
                          ),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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

  Widget _buildPhotoGuideChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
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
    List<(XFile, Uint8List?)>? initialImages,
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
    final batchCtrl = TextEditingController(
      text: initialProduct?.attributes['batch_number']?.toString() ?? '',
    );
    final expiryCtrl = TextEditingController(
      text: initialProduct?.attributes['expiry_date']?.toString() ?? '',
    );

    bool isQuickMode = !isEdit;
    ProductModel? matchedProduct;
    bool isCheckingBarcode = false;
    bool didInitialCheck = false;

    bool isActive = initialProduct?.isActive ?? true;
    bool isFeatured = initialProduct?.isFeatured ?? false;
    bool isPricePublic = initialProduct?.isPricePublic ?? true;
    String unit = initialProduct?.unit ?? 'g';

    List<String> productImages = List<String>.from(initialProduct?.images ?? []);
    final Map<String, XFile> pendingXFiles = {};
    // In-memory bytes cache: fixes Android camera content:// URI display bug
    // where File().existsSync() returns false for content:// paths
    final Map<String, Uint8List> pendingImageBytes = {};

    // Seed recovered lost camera images if activity was destroyed by Android OS
    if (initialImages != null && initialImages.isNotEmpty) {
      for (final (f, bytes) in initialImages) {
        registerPendingProductImage(
          images: productImages,
          files: pendingXFiles,
          bytesByKey: pendingImageBytes,
          sourceFile: f,
          bytes: bytes,
        );
      }
    }
    bool isSaving = false;
    bool isAiScanning = false;
    ColorShadeModel? activeColorShade;
    List<ColorShadeModel> activeColorAlternatives = [];

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

    final boxCostCtrl = TextEditingController();
    final boxQtyCtrl = TextEditingController();
    bool showCartonConverter = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          final boxCostVal = double.tryParse(boxCostCtrl.text.trim()) ?? 0.0;
          final boxQtyVal = double.tryParse(boxQtyCtrl.text.trim()) ?? 0.0;
          final calculatedUnitCost = (boxCostVal > 0 && boxQtyVal > 0) ? (boxCostVal / boxQtyVal) : 0.0;

          Future<void> checkBarcodeDuplicate(String code) async {
            final clean = code.trim();
            if (clean.isEmpty) {
              setModalState(() {
                matchedProduct = null;
                isCheckingBarcode = false;
              });
              return;
            }
            setModalState(() => isCheckingBarcode = true);
            try {
              final prodController = Provider.of<ProductController>(context, listen: false);
              final found = await prodController.findProductByBarcode(clean);
              if (sheetCtx.mounted) {
                setModalState(() {
                  isCheckingBarcode = false;
                  if (found != null && found.id.toString() != initialProduct?.id.toString()) {
                    matchedProduct = found;
                  } else {
                    matchedProduct = null;
                  }
                });
              }
            } catch (_) {
              if (sheetCtx.mounted) {
                setModalState(() => isCheckingBarcode = false);
              }
            }
          }

          if (!didInitialCheck && initialBarcodeVal.isNotEmpty) {
            didInitialCheck = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              checkBarcodeDuplicate(initialBarcodeVal);
            });
          }

          Widget buildInShopDuplicateBanner(ProductModel matched) {
            final currentStock = matched.stock;
            final currentUnit = matched.unit.isNotEmpty ? matched.unit : 'pcs';
            final currentPrice = matched.price > 0 ? '₹${matched.price.toStringAsFixed(0)}' : '';

            return Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sheetCtx.isHindi
                              ? '⚡ यह उत्पाद आपकी दुकान में पहले से मौजूद है!'
                              : '⚡ Already in your shop inventory!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${matched.name} ${currentPrice.isNotEmpty ? '• $currentPrice' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: sheetCtx.colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sheetCtx.isHindi
                        ? 'वर्तमान स्टॉक: $currentStock $currentUnit'
                        : 'Current Stock: $currentStock $currentUnit',
                    style: TextStyle(
                      fontSize: 12,
                      color: sheetCtx.colorTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sheetCtx.isHindi
                        ? '🚀 1-टैप में स्टॉक बढ़ाएं (Quick Restock):'
                        : '🚀 1-Tap Quick Restock:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: sheetCtx.colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [5, 10, 25, 50, 100].map((addQty) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final prodController = Provider.of<ProductController>(context, listen: false);
                          await prodController.adjustStock(matched, addQty);
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sheetCtx.isHindi
                                            ? '✓ ${matched.name} में +$addQty स्टॉक जोड़ा गया! (नया स्टॉक: ${currentStock + addQty})'
                                            : '✓ Added +$addQty to ${matched.name}! (New Stock: ${currentStock + addQty})',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text(
                          '+$addQty',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          sheetCtx.isHindi ? 'इस उत्पाद को संपादित करें (Edit)' : 'Edit This Product',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showAddProductDialog(context, initialProduct: matched);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
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

          bool isEnhancingImage = false;

          Future<Uint8List?> resolveImageBytes(String imagePathOrKey) async {
            try {
              if (pendingImageBytes.containsKey(imagePathOrKey) && pendingImageBytes[imagePathOrKey]!.isNotEmpty) {
                return pendingImageBytes[imagePathOrKey]!;
              }
              if (pendingXFiles.containsKey(imagePathOrKey)) {
                return await pendingXFiles[imagePathOrKey]!.readAsBytes();
              }
              if (!imagePathOrKey.startsWith('http') && !imagePathOrKey.startsWith('/images') && !kIsWeb) {
                final file = File(imagePathOrKey);
                if (await file.exists()) {
                  return await file.readAsBytes();
                }
              }
              if (imagePathOrKey.startsWith('http') || imagePathOrKey.startsWith('/images')) {
                final fullUrl = formatImageUrl(imagePathOrKey);
                final client = Dio();
                final res = await client.get<List<int>>(
                  fullUrl,
                  options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 15)),
                );
                if (res.data != null && res.data!.isNotEmpty) {
                  return Uint8List.fromList(res.data!);
                }
              }
            } catch (e) {
              debugPrint('[InventoryScreen] Failed to resolve bytes for $imagePathOrKey: $e');
            }
            return null;
          }

          Future<void> enhanceImage(String imageKey, {required String mode}) async {
            if (isEnhancingImage) return;
            setModalState(() => isEnhancingImage = true);
            try {
              final rawBytes = await resolveImageBytes(imageKey);
              if (rawBytes == null || rawBytes.isEmpty) {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(sheetCtx.isHindi ? 'फोटो लोड नहीं हो सकी' : 'Could not load photo'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              Uint8List? enhancedBytes;
              if (mode == 'bokeh') {
                final dummyXFile = XFile.fromData(rawBytes, name: 'bokeh.jpg', mimeType: 'image/jpeg');
                final (_, styledBytes) = await applyPhotoStyle(dummyXFile, rawBytes, ProductPhotoStyle.dslrBokeh);
                enhancedBytes = styledBytes;
              } else if (mode == 'studio_white') {
                try {
                  final client = Dio();
                  final res = await client.post(
                    '${ApiConstants.baseUrl}/api/v1/ai/enhance-product-image',
                    data: {
                      'image_base64': base64Encode(rawBytes),
                      'mode': 'studio_white',
                    },
                    options: Options(receiveTimeout: const Duration(seconds: 25)),
                  );
                  if (res.statusCode == 200 && res.data != null) {
                    final data = res.data['data'] ?? res.data;
                    final b64 = data['image_base64']?.toString() ?? '';
                    if (b64.isNotEmpty) {
                      enhancedBytes = base64Decode(b64);
                    }
                  }
                } catch (apiErr) {
                  debugPrint('[InventoryScreen] Backend studio enhance notice: $apiErr');
                }
                if (enhancedBytes == null || enhancedBytes.isEmpty) {
                  final dummyXFile = XFile.fromData(rawBytes, name: 'hdr.jpg', mimeType: 'image/jpeg');
                  final (_, styledBytes) = await applyPhotoStyle(dummyXFile, rawBytes, ProductPhotoStyle.studioHdr);
                  enhancedBytes = styledBytes;
                }
              }

              if (enhancedBytes != null && enhancedBytes.isNotEmpty) {
                setModalState(() {
                  pendingImageBytes[imageKey] = enhancedBytes!;
                });
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(mode == 'bokeh'
                          ? (sheetCtx.isHindi ? '✨ DSLR बैकग्राउंड ब्लर सफलतापूर्वक लागू हुआ!' : '✨ DSLR Background Blur Applied!')
                          : (sheetCtx.isHindi ? '🎨 स्टूडियो बैकग्राउंड सफलतापूर्वक लागू हुआ!' : '🎨 Studio Background Applied!')),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('[InventoryScreen] Enhance image failed: $e');
            } finally {
              if (sheetCtx.mounted) {
                setModalState(() => isEnhancingImage = false);
              }
            }
          }

          Future<void> runAiAutofill([String? primaryTarget]) async {
            if (isAiScanning) return;

            final targetKey = primaryTarget ??
                (productImages.isNotEmpty
                    ? productImages.lastWhere(
                        (p) => pendingImageBytes.containsKey(p) || pendingXFiles.containsKey(p) || isLocalFilePath(p),
                        orElse: () => productImages.first,
                      )
                    : null);

            if (targetKey == null || targetKey.isEmpty) {
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

            setModalState(() {
              isAiScanning = true;
            });

            try {
              final rawBytes = await resolveImageBytes(targetKey);
              if (rawBytes == null || rawBytes.isEmpty) {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(
                      content: Text(sheetCtx.isHindi ? 'तस्वीर लोड नहीं हो सकी' : 'Could not load photo'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              // Fast downscale (max 800px, 75% quality) for quick upload & optimal AI vision tokens
              final normalized = await normalizeBytes(rawBytes, maxDimension: 800, quality: 75);
              final base64String = base64Encode(normalized);
              final String mimeType = targetKey.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
              final aiRepo = AiRepository();

              final resp = await aiRepo.scanProduct(imageBase64: base64String, mimeType: mimeType);

              if (resp.success && resp.data != null) {
                final rawPayload = resp.data!;
                final Map<String, dynamic> data = (rawPayload['scan_data'] is Map)
                    ? Map<String, dynamic>.from(rawPayload['scan_data'] as Map)
                    : rawPayload;

                final studioImageUrl = rawPayload['studio_image_url']?.toString().trim() ?? '';

                setModalState(() {
                  if (studioImageUrl.isNotEmpty && (studioImageUrl.startsWith('http') || studioImageUrl.startsWith('/images/'))) {
                    final idx = productImages.indexOf(targetKey);
                    if (idx != -1) {
                      productImages[idx] = studioImageUrl;
                      pendingImageBytes[studioImageUrl] = rawBytes;
                    } else if (!productImages.contains(studioImageUrl)) {
                      productImages.insert(0, studioImageUrl);
                      pendingImageBytes[studioImageUrl] = rawBytes;
                    }
                  }
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

                  // 4. Weight (populate if detected and empty)
                  final rawWeight = data['weight'];
                  if (rawWeight != null && weightCtrl.text.trim().isEmpty) {
                    final w = double.tryParse(rawWeight.toString()) ?? 0;
                    if (w > 0) {
                      weightCtrl.text = (w == w.roundToDouble()) ? w.toStringAsFixed(0) : w.toString();
                    }
                  }

                  // 5. Unit: Intelligent mapping to valid inventory dropdown values ('g', 'kg', 'ml', 'litre', 'pcs', 'pack', 'box', 'dozen')
                  final rawUnit = data['unit']?.toString().toLowerCase().trim() ?? '';
                  if (rawUnit == 'g' || rawUnit == 'gm' || rawUnit == 'gram' || rawUnit == 'grams') {
                    unit = 'g';
                  } else if (rawUnit == 'kg' || rawUnit == 'kilo' || rawUnit == 'kilogram') {
                    unit = 'kg';
                  } else if (rawUnit == 'ml' || rawUnit == 'millilitre') {
                    unit = 'ml';
                  } else if (rawUnit == 'l' || rawUnit == 'litre' || rawUnit == 'liter') {
                    unit = 'litre';
                  } else if (rawUnit == 'pcs' || rawUnit == 'piece' || rawUnit == 'pieces' || rawUnit == 'pair' || rawUnit == 'meter') {
                    unit = 'pcs';
                  } else if (rawUnit == 'pack' || rawUnit == 'packet' || rawUnit == 'pouch' || rawUnit == 'bottle') {
                    unit = 'pack';
                  } else if (rawUnit == 'box' || rawUnit == 'peti') {
                    unit = 'box';
                  } else if (rawUnit == 'dozen') {
                    unit = 'dozen';
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

                  // 8. Cost Price (Wholesale Procurement Estimate)
                  final rawCost = data['estimated_cost'];
                  if (rawCost != null) {
                    final cp = double.tryParse(rawCost.toString()) ?? 0;
                    if (cp > 0) {
                      costPriceCtrl.text = cp.toStringAsFixed(0);
                    }
                  }

                  // 9. Minimum Stock Alert
                  final rawMinStock = data['min_stock_alert'];
                  if (rawMinStock != null && (lowStockCtrl.text.trim().isEmpty || lowStockCtrl.text.trim() == '5')) {
                    final ms = int.tryParse(rawMinStock.toString()) ?? 0;
                    if (ms > 0) {
                      lowStockCtrl.text = ms.toString();
                    }
                  }

                  // 10. Description & Key Features
                  var fullDesc = data['description']?.toString().trim() ?? '';
                  if (data['key_features'] is List && (data['key_features'] as List).isNotEmpty) {
                    final bullets = (data['key_features'] as List)
                        .map((e) => '• ${e.toString().trim()}')
                        .where((s) => s.length > 2)
                        .join('\n');
                    if (bullets.isNotEmpty) {
                      if (fullDesc.isNotEmpty) {
                        fullDesc = '$fullDesc\n\nKey Highlights:\n$bullets';
                      } else {
                        fullDesc = bullets;
                      }
                    }
                  }
                  if (fullDesc.isNotEmpty) {
                    descriptionCtrl.text = fullDesc;
                  }

                  // 11. Barcode / SKU
                  if (barcodeCtrl.text.trim().isEmpty) {
                    final rawBarcode = data['barcode']?.toString().trim() ?? '';
                    final rawSku = data['suggested_sku']?.toString().trim() ?? '';
                    if (rawBarcode.isNotEmpty) {
                      barcodeCtrl.text = rawBarcode;
                    } else if (rawSku.isNotEmpty) {
                      barcodeCtrl.text = rawSku;
                    }
                  }

                  // Helper function to test if an attribute is high-value & required (avoids useless boilerplate)
                  bool isUsefulAttribute(String k, String v) {
                    final kClean = k.toLowerCase().trim();
                    final vClean = v.toLowerCase().trim();
                    if (kClean.isEmpty || vClean.isEmpty) return false;

                    // 1. Reject placeholder/dummy values
                    const dummyValues = {
                      'n/a', 'na', 'none', 'unknown', 'null', 'not specified',
                      'not applicable', 'standard', 'generic', '-', '--', 'nil',
                      'undefined', 'default', 'regular', 'general'
                    };
                    if (dummyValues.contains(vClean)) return false;

                    // 2. Reject overly long values (> 45 chars) — custom attributes should be concise specs
                    if (vClean.length > 45) return false;

                    // 3. Reject generic advice, warnings, or storage sentences
                    if (vClean.contains('store in') ||
                        vClean.contains('keep away') ||
                        vClean.contains('keep out') ||
                        vClean.contains('as directed') ||
                        vClean.contains('refer pack') ||
                        vClean.contains('sunlight') ||
                        vClean.contains('consult')) {
                      return false;
                    }

                    // 4. Reject redundant or useless keys
                    const uselessKeys = {
                      'storage instructions', 'storage', 'usage', 'how to use',
                      'instructions', 'directions', 'care instructions', 'wash care',
                      'warning', 'safety warning', 'caution', 'disclaimer', 'notice',
                      'country of origin', 'origin',
                      // Redundant with primary form fields:
                      'name', 'product name', 'brand', 'category', 'subcategory',
                      'sub category', 'mrp', 'price', 'selling price', 'cost price',
                      'weight', 'net weight', 'unit', 'net quantity', 'barcode',
                      'sku', 'description', 'highlights'
                    };
                    if (uselessKeys.contains(kClean)) return false;

                    return true;
                  }

                  // Helper closure to inject or update custom attribute pair in UI
                  void setCustomAttr(String key, String val) {
                    final cleanK = key.trim();
                    final cleanV = val.trim();
                    if (!isUsefulAttribute(cleanK, cleanV)) return;

                    final formattedKey = cleanK.contains(' ')
                        ? cleanK
                        : cleanK.split(RegExp(r'[\s_]+')).map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');

                    final existing = customAttrPairs.firstWhere(
                      (p) => p.key.text.toLowerCase().trim() == formattedKey.toLowerCase().trim(),
                      orElse: () => MapEntry(TextEditingController(text: ''), TextEditingController(text: '')),
                    );
                    if (existing.key.text.isEmpty) {
                      if (customAttrPairs.length < 6) { // Max 6 high-value specs to prevent UI bloat
                        customAttrPairs.add(MapEntry(
                          TextEditingController(text: formattedKey),
                          TextEditingController(text: cleanV),
                        ));
                      }
                    } else if (existing.value.text.trim().isEmpty) {
                      existing.value.text = cleanV;
                    }
                  }

                  // 12. Indian Trade Color Details & Calibration (Only for Color-Critical Items)
                  final isColorCritical = isColorCriticalProduct(
                    category: categoryCtrl.text,
                    name: nameCtrl.text,
                  );

                  if (isColorCritical) {
                    if (data['color_details'] is Map) {
                      final cd = Map<String, dynamic>.from(data['color_details'] as Map);
                      if (cd['primary_shade'] is Map) {
                        activeColorShade = ColorShadeModel.fromMap(Map<String, dynamic>.from(cd['primary_shade'] as Map));
                      }
                      if (cd['alternatives'] is List) {
                        activeColorAlternatives = (cd['alternatives'] as List)
                            .whereType<Map>()
                            .map((m) => ColorShadeModel.fromMap(Map<String, dynamic>.from(m)))
                            .toList();
                      }
                    } else {
                      final rawColor = data['attributes']?['Color']?.toString() ?? '';
                      if (rawColor.isNotEmpty) {
                        activeColorShade = kIndianTextileShadeRegistry.firstWhere(
                          (s) => rawColor.toLowerCase().contains(s.shadeName.toLowerCase()) || rawColor.toLowerCase().contains(s.hindiName.toLowerCase()),
                          orElse: () => ColorShadeModel(shadeName: rawColor, hindiName: '', hexCode: '#808080'),
                        );
                      }
                    }

                    if (activeColorShade != null) {
                      setCustomAttr('Color', activeColorShade!.displayName);
                    }
                  } else {
                    // Non-color product (Grocery, FMCG, Medicine, Hardware) -> Never attach color
                    activeColorShade = null;
                    activeColorAlternatives = [];
                    customAttrPairs.removeWhere((p) {
                      final k = p.key.text.toLowerCase().trim();
                      return k == 'color' || k == 'colour';
                    });
                  }

                  // 13. Specialized Product Attributes from AI (Filtered for high-value specs only)
                  if (data['attributes'] is Map) {
                    final attrMap = Map<String, dynamic>.from(data['attributes'] as Map);
                    attrMap.forEach((k, v) {
                      if (v != null && v.toString().trim().isNotEmpty) {
                        setCustomAttr(k.toString(), v.toString());
                      }
                    });
                  }

                  // 13. Key Ingredients / Composition (Only if concise, clean, and not boilerplate)
                  final rawIngredients = data['ingredients']?.toString().trim() ?? '';
                  if (rawIngredients.isNotEmpty && rawIngredients.length <= 40 && !rawIngredients.toLowerCase().contains('standard')) {
                    setCustomAttr('Ingredients', rawIngredients);
                  }

                  // 14. HSN Code & GST Rate (Only if genuine valid values)
                  final rawHsn = data['hsn_code']?.toString().trim() ?? '';
                  if (rawHsn.isNotEmpty && rawHsn.length >= 4 && RegExp(r'^\d+$').hasMatch(rawHsn) && rawHsn != '0000') {
                    setCustomAttr('HSN Code', rawHsn);
                  }
                  final rawGst = data['gst_rate'];
                  if (rawGst != null) {
                    final g = double.tryParse(rawGst.toString()) ?? 0;
                    if (g > 0 && g <= 28) {
                      setCustomAttr('GST Rate', '${g.toStringAsFixed(0)}%');
                    }
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
                                  ? '✨ AI ने प्रोडक्ट विवरण ऑटो-भर दिया: ${data['name'] ?? ''}'
                                  : '✨ AI Auto-Filled Details: ${data['name'] ?? ''}',
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
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Text(sheetCtx.isHindi ? 'त्रुटि: $err' : 'Error: $err'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } finally {
              if (sheetCtx.mounted) {
                setModalState(() {
                  isAiScanning = false;
                });
              }
            }
          }

          void addProductImages(List<(XFile, Uint8List?)> files) {
            if (files.isEmpty) return;
            var addedKeys = <String>[];

            setModalState(() {
              addedKeys = registerPendingProductImages(
                images: productImages,
                files: pendingXFiles,
                bytesByKey: pendingImageBytes,
                captures: files,
              );
            });

            if (addedKeys.isNotEmpty) {
              runAiAutofill(addedKeys.first);
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

                    // ⚡ DUAL-MODE TOGGLE: Quick 15-Sec Add vs Full Catalog Mode
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: sheetCtx.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sheetCtx.colorBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => isQuickMode = true),
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isQuickMode ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: isQuickMode
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: isQuickMode ? Colors.white : sheetCtx.colorTextSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sheetCtx.isHindi ? '⚡ 15-सेकंड क्विक ऐड' : '⚡ 15-Sec Quick Add',
                                      style: TextStyle(
                                        fontWeight: isQuickMode ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12.5,
                                        color: isQuickMode ? Colors.white : sheetCtx.colorTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => isQuickMode = false),
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isQuickMode ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !isQuickMode
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.format_list_bulleted_rounded,
                                      size: 16,
                                      color: !isQuickMode ? Colors.white : sheetCtx.colorTextSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sheetCtx.isHindi ? '📦 विस्तृत कैटलॉग' : '📦 Full Details',
                                      style: TextStyle(
                                        fontWeight: !isQuickMode ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12.5,
                                        color: !isQuickMode ? Colors.white : sheetCtx.colorTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isQuickMode) ...[
                      // 1. PRODUCT NAME (with Speech-to-Text Mic)
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: '${sheetCtx.tr('inv_field_name')} *',
                          hintText: sheetCtx.isHindi
                              ? 'उदा. Fortune Refined Sunflower Oil 1L'
                              : 'e.g. Fortune Refined Sunflower Oil 1L',
                          suffixIcon: AppVoiceIconButton(
                            controller: nameCtrl,
                            hint: sheetCtx.tr('inv_field_name'),
                            onSubmitted: (_) => setModalState(() {}),
                          ),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // 2. BARCODE / SKU (with Scanner & In-Shop Duplicate Restock Banner)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: barcodeCtrl,
                              onChanged: (val) {
                                setModalState(() {});
                                checkBarcodeDuplicate(val);
                              },
                              decoration: InputDecoration(
                                labelText: sheetCtx.tr('inv_field_barcode'),
                                hintText: 'Scan or type barcode / SKU',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCheckingBarcode)
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    IconButton(
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
                                              barcodeCtrl.text = clean;
                                              await checkBarcodeDuplicate(clean);
                                            }
                                            return true;
                                          },
                                        );
                                      },
                                    ),
                                  ],
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
                            label: const Text('Auto SKU'),
                            onPressed: () {
                              final generatedSku = _generateSmartSku(nameCtrl.text);
                              barcodeCtrl.text = generatedSku;
                              checkBarcodeDuplicate(generatedSku);
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
                      if (matchedProduct != null) buildInShopDuplicateBanner(matchedProduct!),
                      const SizedBox(height: 12),

                      // 3. SELLING PRICE & COST PRICE
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
                      const SizedBox(height: 8),

                      // Auto Margin Chips (Quick Mode)
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
                        const SizedBox(height: 8),
                      ],

                      // Live Margins / Error Badges
                      if (isCostInvalid || hasProfit) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (isCostInvalid)
                              AppBadge.warning(
                                '⚠️ Kharid Price (₹${liveCost.toStringAsFixed(0)}) Selling Price se zyada hai!',
                              ),
                            if (hasProfit)
                              AppBadge.success(
                                'Est. Profit: +₹${(livePrice - liveCost).toStringAsFixed(0)} (${(((livePrice - liveCost) / livePrice) * 100).toStringAsFixed(1)}% Margin)',
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 4. STOCK & UNIT DROPDOWN
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
                              key: ValueKey('inv_quick_unit_dropdown_$unit'),
                              isExpanded: true,
                              initialValue: ['g', 'gm', 'kg', 'ml', 'litre', 'l', 'pcs', 'piece', 'packet', 'pack', 'box', 'dozen'].contains(unit) ? unit : 'pcs',
                              decoration: InputDecoration(labelText: sheetCtx.tr('inv_field_unit')),
                              items: [
                                DropdownMenuItem(value: 'pcs', child: Text(sheetCtx.tr('inv_unit_piece'), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'pack', child: Text(sheetCtx.tr('inv_unit_packet'), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'kg', child: Text(sheetCtx.tr('inv_unit_kg'), overflow: TextOverflow.ellipsis)),
                                const DropdownMenuItem(value: 'g', child: Text('g (Gram)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'litre', child: Text(sheetCtx.tr('inv_unit_litre'), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'ml', child: Text('ml (mL)', overflow: TextOverflow.ellipsis)),
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Accordion / Switch to Full Catalog Mode
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: Text(
                          sheetCtx.isHindi
                              ? '➕ फोटो, एक्सपायरी व अतिरिक्त विवरण जोड़ें (Full Mode)'
                              : '➕ Add Photos, Expiry, Category & Full Details',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setModalState(() => isQuickMode = false);
                        },
                      ),
                      const SizedBox(height: 8),
                    ] else ...[

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
                                onFilesSelected: addProductImages,
                              );
                            },
                          ),
                      ],
                    ),
                    // Proposal 5: Guided Photo Angle Chips
                    if (productImages.length < 3) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPhotoGuideChip(
                              sheetCtx,
                              icon: Icons.camera_alt_outlined,
                              label: sheetCtx.isHindi ? '📷 1. मुख्य फोटो (Front)' : '📷 1. Front Pack',
                              onTap: () => _showProductImageSourceSheet(
                                sheetCtx,
                                maxAllowed: 10,
                                currentCount: productImages.length,
                                onFilesSelected: addProductImages,
                              ),
                            ),
                            _buildPhotoGuideChip(
                              sheetCtx,
                              icon: Icons.photo_library_outlined,
                              label: sheetCtx.isHindi ? '📷 2. सामग्री / MRP (Back)' : '📷 2. Back / Ingredients',
                              onTap: () => _showProductImageSourceSheet(
                                sheetCtx,
                                maxAllowed: 10,
                                currentCount: productImages.length,
                                onFilesSelected: addProductImages,
                              ),
                            ),
                            _buildPhotoGuideChip(
                              sheetCtx,
                              icon: Icons.qr_code_scanner_rounded,
                              label: sheetCtx.isHindi ? '📷 3. बारकोड (Barcode Tag)' : '📷 3. Barcode Tag',
                              onTap: () => _showProductImageSourceSheet(
                                sheetCtx,
                                maxAllowed: 10,
                                currentCount: productImages.length,
                                onFilesSelected: addProductImages,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

                              Widget thumbnailChild;
                              if (pendingImageBytes.containsKey(path) && pendingImageBytes[path]!.isNotEmpty) {
                                thumbnailChild = Image.memory(
                                  pendingImageBytes[path]!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Icon(
                                    Icons.image_rounded,
                                    color: sheetCtx.colorTextMuted,
                                    size: 24,
                                  ),
                                );
                              } else if (pendingXFiles.containsKey(path)) {
                                final xfile = pendingXFiles[path]!;
                                thumbnailChild = FutureBuilder<Uint8List>(
                                  future: xfile.readAsBytes(),
                                  builder: (ctx, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                      pendingImageBytes[path] = snapshot.data!;
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Icon(
                                          Icons.image_rounded,
                                          color: sheetCtx.colorTextMuted,
                                          size: 24,
                                        ),
                                      );
                                    }
                                    if (xfile.path.isNotEmpty) {
                                      try {
                                        final file = File(xfile.path);
                                        return Image.file(
                                          file,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Icon(
                                            Icons.image_rounded,
                                            color: sheetCtx.colorTextMuted,
                                            size: 24,
                                          ),
                                        );
                                      } catch (_) {}
                                    }
                                    return const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      ),
                                    );
                                  },
                                );
                              } else {
                                thumbnailChild = AppProductImage(
                                  imageUrl: path,
                                  width: 64,
                                  height: 64,
                                  expand: true,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.image_rounded,
                                  fallbackIconSize: 24,
                                );
                              }

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
                                        child: thumbnailChild,
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
                                            pendingImageBytes.remove(removed);
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
                                    onFilesSelected: addProductImages,
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
                                        ? '⚡ AI स्टूडियो: बैकग्राउंड हटा रहा है और 10+ विवरण भर रहा है...'
                                        : '⚡ AI Studio: Enhancing studio photo & extracting 10+ details...')
                                    : (sheetCtx.isHindi
                                        ? '✨ AI स्टूडियो और ऑटो-भरें (फोटो + 10+ विवरण)'
                                        : '✨ AI Studio & Auto-Fill (Photo + 10+ Details)'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (!isAiScanning)
                              InkWell(
                                onTap: () {
                                  // Prefer latest added unprocessed/local image, or first image
                                  final target = productImages.lastWhere(
                                    (p) => pendingImageBytes.containsKey(p) || pendingXFiles.containsKey(p) || isLocalFilePath(p),
                                    orElse: () => productImages.first,
                                  );
                                  runAiAutofill(target);
                                },
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

                      // DSLR & STUDIO PHOTO ENHANCE CONTROLS
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sheetCtx.colorSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.shade700.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isEnhancingImage)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                              )
                            else
                              const Icon(Icons.camera_enhance_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    sheetCtx.isHindi ? 'DSLR फोटो पॉलिश' : 'DSLR Studio Polish',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    isEnhancingImage
                                        ? (sheetCtx.isHindi ? 'बैकग्राउंड को प्रोसेस कर रहा है...' : 'Processing background...')
                                        : (sheetCtx.isHindi ? 'बैकग्राउंड ब्लर करें या स्टूडियो लुक दें' : 'Blur BG or Studio White'),
                                    style: TextStyle(fontSize: 10, color: sheetCtx.colorTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (!isEnhancingImage) ...[
                              InkWell(
                                onTap: () => enhanceImage(productImages.first, mode: 'bokeh'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.blur_on_rounded, color: Colors.white, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        sheetCtx.isHindi ? 'DSLR ब्लर' : 'DSLR Blur',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => enhanceImage(productImages.first, mode: 'studio_white'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        sheetCtx.isHindi ? 'स्टूडियो व्हाइट' : 'Studio White',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                              suffixIcon: AppVoiceIconButton(
                                controller: brandCtrl,
                                hint: sheetCtx.isHindi ? 'ब्रांड' : 'Brand',
                                onSubmitted: (_) => setModalState(() {}),
                              ),
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
                        suffixIcon: AppVoiceIconButton(
                          controller: nameCtrl,
                          hint: sheetCtx.tr('inv_field_name'),
                          onSubmitted: (_) => setModalState(() {}),
                        ),
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

                    // 📦 PROPOSAL 3: WHOLESALE CARTON / BOX PACK RATIO CONVERTER
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          showCartonConverter = !showCartonConverter;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sheetCtx.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sheetCtx.colorBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  sheetCtx.isHindi
                                      ? '📦 थोक पेटी/बॉक्स मूल्य कैलकुलेटर'
                                      : '📦 Wholesale Box/Peti Pack Ratio Converter',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: sheetCtx.colorTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              showCartonConverter ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18,
                              color: sheetCtx.colorTextMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showCartonConverter) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sheetCtx.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: boxCostCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: sheetCtx.isHindi ? 'पेटी की कुल खरीद (₹)' : 'Box Cost (₹)',
                                      hintText: 'e.g. 240',
                                      prefixText: '₹ ',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: boxQtyCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: sheetCtx.isHindi ? 'एक पेटी में कुल पीस' : 'Items in Box',
                                      hintText: 'e.g. 24',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            if (calculatedUnitCost > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    sheetCtx.isHindi
                                        ? 'एक पीस की खरीद: ₹${calculatedUnitCost.toStringAsFixed(2)}'
                                        : 'Unit Cost: ₹${calculatedUnitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        costPriceCtrl.text = calculatedUnitCost.toStringAsFixed(2);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        sheetCtx.isHindi ? 'लागू करें' : 'Apply',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

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

                    TextField(
                      controller: comparePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'MRP / Compare Price',
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),

                    // LIVE PRICING DATA INTEGRITY FEEDBACK BADGES
                    if (isMrpInvalid || isCostInvalid || hasProfit || hasDiscount) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (isMrpInvalid)
                            AppBadge.danger(
                              '⚠️ MRP (₹${liveMrp.toStringAsFixed(0)}) Selling Price se kam hai!',
                            ),
                          if (isCostInvalid)
                            AppBadge.warning(
                              '⚠️ Cost Price (₹${liveCost.toStringAsFixed(0)}) Selling Price se zyada hai!',
                            ),
                          if (hasProfit)
                            AppBadge.success(
                              'Est. Profit: +₹${(livePrice - liveCost).toStringAsFixed(0)} (${(((livePrice - liveCost) / livePrice) * 100).toStringAsFixed(1)}% Margin)',
                            ),
                          if (hasDiscount)
                            AppBadge.primary(
                              'Discount: ${(((liveMrp - livePrice) / liveMrp) * 100).toStringAsFixed(0)}% OFF MRP',
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
                            initialValue: ['g', 'gm', 'kg', 'ml', 'litre', 'l', 'pcs', 'piece', 'packet', 'pack', 'box', 'dozen'].contains(unit) ? unit : 'g',
                            decoration: InputDecoration(labelText: sheetCtx.tr('inv_field_unit')),
                            items: [
                              const DropdownMenuItem(value: 'g', child: Text('g (Gram)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'kg', child: Text(sheetCtx.tr('inv_unit_kg'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'ml', child: Text('ml (mL)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'litre', child: Text(sheetCtx.tr('inv_unit_litre'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'pcs', child: Text(sheetCtx.tr('inv_unit_piece'), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'pack', child: Text(sheetCtx.tr('inv_unit_packet'), overflow: TextOverflow.ellipsis)),
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
                            decoration: InputDecoration(
                              labelText: 'Weight / Vol ($unit)',
                              hintText: unit == 'g' || unit == 'gm' ? '500' : '1.0',
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
                              setModalState(() {});
                              checkBarcodeDuplicate(val);
                            },
                            decoration: InputDecoration(
                              labelText: sheetCtx.tr('inv_field_barcode'),
                              hintText: 'e.g. FORTUNE-RICE-389 or 890123456789',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCheckingBarcode)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  IconButton(
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
                                            barcodeCtrl.text = clean;
                                            await checkBarcodeDuplicate(clean);
                                          }
                                          return true;
                                        },
                                      );
                                    },
                                  ),
                                ],
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
                            checkBarcodeDuplicate(generatedSku);
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
                    if (matchedProduct != null) buildInShopDuplicateBanner(matchedProduct!),
                    const SizedBox(height: 12),

                    // 🎨 INDIAN TRADE COLOR SHADE CALIBRATOR (Only for Color-Critical Products)
                    if (activeColorShade != null &&
                        isColorCriticalProduct(category: categoryCtrl.text, name: nameCtrl.text)) ...[
                      ColorShadeSelector(
                        initialShade: activeColorShade!,
                        alternatives: activeColorAlternatives,
                        onShadeSelected: (newShade) {
                          setModalState(() {
                            activeColorShade = newShade;
                            final existing = customAttrPairs.firstWhere(
                              (p) => p.key.text.toLowerCase().trim() == 'color',
                              orElse: () => MapEntry(TextEditingController(text: ''), TextEditingController(text: '')),
                            );
                            if (existing.key.text.isEmpty) {
                              customAttrPairs.add(MapEntry(
                                TextEditingController(text: 'Color'),
                                TextEditingController(text: newShade.displayName),
                              ));
                            } else {
                              existing.value.text = newShade.displayName;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 📅 OPTIONAL BATCH NUMBER & EXPIRY DATE TRACKING (Kirana / FMCG / Perishables)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: batchCtrl,
                            decoration: InputDecoration(
                              labelText: sheetCtx.isHindi ? 'बैच नंबर (Batch No.)' : 'Batch Number (Optional)',
                              hintText: 'e.g. B-102',
                              prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: expiryCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: sheetCtx.isHindi ? 'एक्सपायरी डेट (Expiry)' : 'Expiry Date (Optional)',
                              hintText: 'YYYY-MM-DD',
                              prefixIcon: const Icon(Icons.event_outlined, size: 18),
                              suffixIcon: expiryCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        expiryCtrl.clear();
                                        setModalState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: sheetCtx,
                                initialDate: now.add(const Duration(days: 90)),
                                firstDate: now.subtract(const Duration(days: 30)),
                                lastDate: now.add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                expiryCtrl.text = picked.toIso8601String().split('T').first;
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                      ],
                    ),
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

                    // TOGGLES ROW (Show Price Online, Featured)
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Show Price to Customers (Online)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isPricePublic
                              ? 'Price is publicly visible online on digital storefront'
                              : '🔒 Price Hidden online (Shows "Mandi Rate / Price on Request" - Best for loose commodities)',
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
                    ],
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
                        AppButton.outline(
                          text: sheetCtx.tr('btn_cancel'),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          text: sheetCtx.tr('btn_save'),
                          isLoading: isSaving,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  final price = double.tryParse(priceCtrl.text) ?? 0.0;
                                  final costPrice = double.tryParse(costPriceCtrl.text) ?? 0.0;
                                  final comparePrice = double.tryParse(comparePriceCtrl.text) ?? 0.0;
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
                                  if (batchCtrl.text.trim().isNotEmpty) {
                                    attr['batch_number'] = batchCtrl.text.trim();
                                  }
                                  if (expiryCtrl.text.trim().isNotEmpty) {
                                    attr['expiry_date'] = expiryCtrl.text.trim();
                                  }
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
                                        'stock': stock,
                                        'stock_quantity': stock,
                                        'unit': unit,
                                        'category': categoryCtrl.text.trim().isNotEmpty ? categoryCtrl.text.trim() : 'General Store',
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
                                      stock: stock,
                                      unit: unit,
                                      category: categoryCtrl.text.trim().isNotEmpty ? categoryCtrl.text.trim() : 'General Store',
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
          AppButton.outline(
            text: 'Cancel',
            size: AppButtonSize.sm,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton.danger(
            text: 'Delete',
            size: AppButtonSize.sm,
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
                          AppButton(
                            text: ctx.tr('bulk_import_btn_start'),
                            isFullWidth: true,
                            isLoading: isUploading,
                            onPressed: selectedFile == null || fileBytes == null || isUploading
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
          leading: const AppBackButton(fallbackRoute: '/merchant'),
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
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _showSortBottomSheet(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _sortOption != InventorySortOption.newest
                                  ? AppColors.primary
                                  : context.colorBorder,
                              width: _sortOption != InventorySortOption.newest ? 1.5 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
