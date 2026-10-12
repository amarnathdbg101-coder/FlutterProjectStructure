import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:url_launcher/url_launcher.dart';
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
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import 'product_detail_screen.dart';

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
  InventorySortOption _sortOption = InventorySortOption.newest;
  String _selectedCategory = 'All';
  bool _showOnlyLowStock = false;
  bool _showOnlyPriceHidden = false;
  bool _showOnlyDiscounted = false;
  bool _hideProfitMargin = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductController>().loadProducts();
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['filter'] == 'low_stock') {
        setState(() => _showOnlyLowStock = true);
      }
    });
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text != _searchQuery) {
      setState(() {
        _searchQuery = text;
      });
    }
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _showOnlyLowStock = false;
      _showOnlyPriceHidden = false;
      _showOnlyDiscounted = false;
      _selectedCategory = 'All';
      _sortOption = InventorySortOption.newest;
    });
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
                              ctx.isHindi ? 'इन्वेंट्री क्रमबद्ध करें (Sort By)' : 'Sort Inventory Catalog',
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: isSelected ? context.colorPrimaryLight : context.colorSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.colorBorder,
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
                  color: isSelected ? AppColors.primary : context.colorTextSecondary,
                ),
                const SizedBox(width: 4.5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : context.colorTextPrimary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : context.colorSurfaceSubtle,
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
        ),
      ),
    );
  }

  // Directly launches Device Gallery / File Picker (Camera Option Removed)
  void _pickImagesFromDevice(
    BuildContext context, {
    required Function(List<XFile> files) onFilesSelected,
    int maxAllowed = 10,
    int currentCount = 0,
  }) async {
    try {
      final picker = ImagePicker();
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
      debugPrint('[InventoryScreen] Image picker warning: $e');
      try {
        final picker = ImagePicker();
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

  void _showAddProductDialog(BuildContext context, {ProductModel? initialProduct}) {
    final isEdit = initialProduct != null;
    final nameCtrl = TextEditingController(text: initialProduct?.name ?? '');
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
    final barcodeCtrl = TextEditingController(text: initialProduct?.barcode ?? '');
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
    List<String> productImages = List<String>.from(initialProduct?.images ?? []);
    final Map<String, XFile> pendingXFiles = {};
    bool isSaving = false;

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

    // Expanded Retail Business Categories List
    final categoriesList = [
      'General Store',
      'Grocery & Staples',
      'Snacks & Munchies',
      'Beverages & Drinks',
      'Dairy, Bakery & Frozen',
      'Personal Care & Beauty',
      'Household & Cleaning',
      'Fruits & Vegetables',
      'Electronics & Appliances',
      'Mobile & Accessories',
      'Clothing & Fashion',
      'Footwear & Leather',
      'Stationery & Office Supplies',
      'Hardware & Building Material',
      'Medicine & Healthcare',
      'Toys & Baby Products',
      'Sports & Fitness',
      'Automotive & Spare Parts',
      'Pet Supplies',
      'Services & Others',
    ];

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
                            isEdit ? Icons.edit_note_rounded : Icons.add_box_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Product Details' : 'Add New Product',
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
                              _pickImagesFromDevice(
                                sheetCtx,
                                maxAllowed: 10,
                                currentCount: productImages.length,
                                onFilesSelected: (files) {
                                  setModalState(() {
                                    for (final f in files) {
                                      if (productImages.length < 10) {
                                        final key = f.path.isNotEmpty
                                            ? f.path
                                            : 'upload_${DateTime.now().microsecondsSinceEpoch}_${f.name}';
                                        productImages.add(key);
                                        pendingXFiles[key] = f;
                                      }
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
                                  _pickImagesFromDevice(
                                    sheetCtx,
                                    maxAllowed: 10,
                                    currentCount: productImages.length,
                                    onFilesSelected: (files) {
                                      setModalState(() {
                                        for (final f in files) {
                                          if (productImages.length < 10) {
                                            final key = f.path.isNotEmpty
                                                ? f.path
                                                : 'upload_${DateTime.now().microsecondsSinceEpoch}_${f.name}';
                                            productImages.add(key);
                                            pendingXFiles[key] = f;
                                          }
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
                    const SizedBox(height: 16),

                    // SECTION 2: BASIC PRODUCT INFORMATION
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: '${sheetCtx.tr('inv_field_name')} *',
                        hintText: sheetCtx.tr('inv_field_name_hint'),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      key: const ValueKey('inv_add_category_dropdown'),
                      isExpanded: true,
                      initialValue: categoriesList.contains(categoryCtrl.text)
                          ? categoryCtrl.text
                          : 'General Store',
                      decoration: InputDecoration(labelText: '${sheetCtx.tr('inv_field_category')} *'),
                      items: categoriesList
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) categoryCtrl.text = val;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: brandCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Brand / Company',
                        hintText: 'e.g. Fortune, Amul, Tata',
                      ),
                    ),
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
                            key: const ValueKey('inv_edit_unit_dropdown'),
                            isExpanded: true,
                            initialValue: unit,
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
                              if (val != null) unit = val;
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
                            decoration: InputDecoration(
                              labelText: sheetCtx.tr('inv_field_barcode'),
                              hintText: 'e.g. FORTUNE-RICE-389 or 890123456789',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
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
                                              isEdit
                                                  ? context.tr('inv_toast_updated')
                                                  : context.tr('inv_toast_added'),
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
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(ctx.tr('bulk_import_close_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

    // 1. Compute dynamic filter metrics & categories
    final availableCategories = <String>{};
    int lowStockCount = 0;
    int hiddenPriceCount = 0;
    int discountedCount = 0;

    for (final p in allProducts) {
      final cat = formatCategoryName(p.category);
      if (cat.isNotEmpty && cat != 'General Store') {
        availableCategories.add(cat);
      }
      if (p.isLowStock || p.isOutOfStock) {
        lowStockCount++;
      }
      if (!p.isPricePublic) {
        hiddenPriceCount++;
      }
      if (p.comparePrice > p.price) {
        discountedCount++;
      }
    }

    final sortedCategories = availableCategories.toList()..sort();

    // 2. Tokenized multi-field search matching (0ms instant in-memory)
    final queryTokens = _searchQuery.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    List<ProductModel> displayProducts = allProducts.where((p) {
      if (_showOnlyLowStock && !(p.isLowStock || p.isOutOfStock)) {
        return false;
      }
      if (_showOnlyPriceHidden && p.isPricePublic) {
        return false;
      }
      if (_showOnlyDiscounted && p.comparePrice <= p.price) {
        return false;
      }
      if (_selectedCategory != 'All') {
        if (formatCategoryName(p.category).toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }
      if (queryTokens.isNotEmpty) {
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
      return true;
    }).toList();

    // 3. Instant Multi-Criteria Sorting
    switch (_sortOption) {
      case InventorySortOption.newest:
        break;
      case InventorySortOption.stockLowHigh:
        displayProducts.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case InventorySortOption.stockHighLow:
        displayProducts.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case InventorySortOption.priceHighLow:
        displayProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case InventorySortOption.priceLowHigh:
        displayProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case InventorySortOption.marginHighLow:
        displayProducts.sort((a, b) => b.profitMarginPct.compareTo(a.profitMarginPct));
        break;
      case InventorySortOption.nameAZ:
        displayProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case InventorySortOption.nameZA:
        displayProducts.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case InventorySortOption.bargainFirst:
        displayProducts.sort((a, b) {
          final aScore = (!a.isPricePublic || a.allowBargain) ? 1 : 0;
          final bScore = (!b.isPricePublic || b.allowBargain) ? 1 : 0;
          return bScore.compareTo(aScore);
        });
        break;
    }

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
                context.go('/merchant');
              }
            },
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
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh Product Catalog',
              onPressed: () async {
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
              },
            ),
            IconButton(
              icon: Icon(
                _hideProfitMargin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _hideProfitMargin ? AppColors.warning : context.colorTextSecondary,
              ),
              tooltip: _hideProfitMargin ? 'Show Profit Margins' : 'Hide Profit Margins (Customer Mode)',
              onPressed: () {
                setState(() {
                  _hideProfitMargin = !_hideProfitMargin;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_hideProfitMargin ? 'Profit margins hidden for customer safety' : 'Profit margins visible'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: context.tr('bulk_import_open_dialog_btn'),
              onPressed: () => _showBulkImportDialog(context),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: context.colorTextSecondary),
              tooltip: context.tr('inv_refresh_tooltip'),
              onPressed: () => prodController.loadProducts(),
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
                          final text = _searchController.text.trim();
                          if (text.isNotEmpty) {
                            setState(() => _searchQuery = text);
                          }
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
                          _selectedCategory == 'All',
                      onTap: () {
                        setState(() {
                          _showOnlyLowStock = false;
                          _showOnlyPriceHidden = false;
                          _showOnlyDiscounted = false;
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
                  ],
                ),
              ),

              // 3. RESULTS SUMMARY STRIP
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Text(
                      context.isHindi
                          ? '${allProducts.length} में से ${displayProducts.length} उत्पाद'
                          : 'Showing ${displayProducts.length} of ${allProducts.length} items',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextMuted,
                      ),
                    ),
                    const Spacer(),
                    if (_searchQuery.isNotEmpty ||
                        _showOnlyLowStock ||
                        _showOnlyPriceHidden ||
                        _showOnlyDiscounted ||
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
                                  child: Column(
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
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                                        label: Text(context.isHindi ? 'सभी फिल्टर हटाएं' : 'Reset Filters'),
                                        onPressed: _clearAllFilters,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 3 : 2);
                              final aspectRatio = width > 700 ? 0.76 : 0.68;

                              return GridView.builder(
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
                                  return _buildCleanProductCard(context, p);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ultra-Clean & Beautiful Product Card (Name, Price & Image Only)
  Widget _buildCleanProductCard(BuildContext context, ProductModel p) {
    final isOutOfStock = p.isOutOfStock;

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => _navigateToProductDetails(context, p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CLEAN PRODUCT IMAGE WITH DISCOUNT / OUT OF STOCK BADGE
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colorBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppProductImage(
                      imageUrl: p.imageUrl,
                      expand: true,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                      fallbackIcon: Icons.inventory_2_outlined,
                      fallbackIconSize: 36,
                    ),
                  ),
                ),
                if (isOutOfStock)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: const AppBadge(
                      label: 'Out of Stock',
                      type: AppBadgeType.error,
                    ),
                  ),
                if (p.comparePrice > p.price)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AppBadge(
                      label: '${p.discountPct.toStringAsFixed(0)}% OFF',
                      type: AppBadgeType.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. PRODUCT NAME
          Text(
            p.name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: context.colorTextPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // 3. PRODUCT SELLING PRICE & MRP
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
                    fontSize: 17,
                  ),
                ),
                if (p.comparePrice > p.price) ...[
                  const SizedBox(width: 6),
                  Text(
                    '₹${p.comparePrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: context.colorTextMuted,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Text(
                  '/ ${p.unit}',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.isPricePublic
                        ? context.colorSuccessLight
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: p.isPricePublic
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.isPricePublic ? Icons.language_rounded : Icons.lock_rounded,
                        size: 10,
                        color: p.isPricePublic ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 2.5),
                      Text(
                        p.isPricePublic ? 'Public' : 'Private',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: p.isPricePublic ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 4. STOCK LEVEL BADGE & QUICK UPDATE (+/-) BUTTON
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stock Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? context.colorErrorLight
                      : (p.isLowStock ? context.colorWarningLight : context.colorSurfaceSubtle),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOutOfStock
                        ? AppColors.error.withValues(alpha: 0.3)
                        : (p.isLowStock
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : context.colorBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOutOfStock
                          ? Icons.remove_circle_outline_rounded
                          : (p.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined),
                      size: 10,
                      color: isOutOfStock
                          ? AppColors.error
                          : (p.isLowStock ? AppColors.warning : context.colorTextSecondary),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isOutOfStock
                          ? 'Out of Stock'
                          : (p.isLowStock ? 'Low: ${p.stock}' : 'Stock: ${p.stock}'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? AppColors.error
                            : (p.isLowStock ? AppColors.warning : context.colorTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Stock Adjuster (+/-) Action Button
              InkWell(
                onTap: () => _showQuickStockSheet(context, p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 12, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text(
                        '+/-',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1-Tap Quick Stock Adjuster Bottom Sheet
  void _showQuickStockSheet(BuildContext context, ProductModel p) {
    int currentStock = p.stock;
    final stockCtrl = TextEditingController(text: currentStock.toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void updateCount(int delta) {
            final val = (int.tryParse(stockCtrl.text.trim()) ?? currentStock) + delta;
            final nextVal = val >= 0 ? val : 0;
            setSheetState(() {
              stockCtrl.text = nextVal.toString();
              currentStock = nextVal;
            });
          }

          return Container(
            decoration: BoxDecoration(
              color: ctx.colorSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: ctx.colorBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ctx.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ctx.colorBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AppProductImage(
                          imageUrl: p.imageUrl,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.inventory_2_outlined,
                          fallbackIconSize: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: ctx.colorTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${p.price.toStringAsFixed(0)} / ${p.unit} • Current: ${p.stock} units',
                              style: TextStyle(
                                fontSize: 11.5,
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
                  const SizedBox(height: 16),
                  Divider(height: 1, color: ctx.colorBorder),
                  const SizedBox(height: 16),

                  Text(
                    ctx.tr('inv_quick_stock_title'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ctx.colorTextMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Big Interactive Stepper Counter
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ctx.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ctx.colorBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: ctx.colorSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.remove_rounded, color: AppColors.error),
                          onPressed: () => updateCount(-1),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              final numVal = int.tryParse(val) ?? 0;
                              currentStock = numVal >= 0 ? numVal : 0;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: ctx.colorSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_rounded, color: AppColors.success),
                          onPressed: () => updateCount(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Delta Chips (-5, -1, +5, +10, +25, +50)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickStockChip(ctx, '-5', () => updateCount(-5), isNegative: true),
                        _buildQuickStockChip(ctx, '-1', () => updateCount(-1), isNegative: true),
                        _buildQuickStockChip(ctx, '+5', () => updateCount(5)),
                        _buildQuickStockChip(ctx, '+10', () => updateCount(10)),
                        _buildQuickStockChip(ctx, '+25', () => updateCount(25)),
                        _buildQuickStockChip(ctx, '+50', () => updateCount(50)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Stock Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final finalStock = int.tryParse(stockCtrl.text.trim()) ?? currentStock;
                            setSheetState(() => isSaving = true);
                            Navigator.pop(ctx);

                            final prodCtrl = context.read<ProductController>();
                            final success = await prodCtrl.editProduct(
                              p.id,
                              {'stock': finalStock, 'stock_quantity': finalStock},
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? context.tr('inv_quick_stock_saved')
                                        : 'Failed to update stock',
                                  ),
                                  backgroundColor: success ? AppColors.success : AppColors.error,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            context.tr('btn_save'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStockChip(BuildContext context, String label, VoidCallback onTap, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isNegative
                ? AppColors.error.withValues(alpha: 0.1)
                : context.colorPrimaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isNegative
                  ? AppColors.error.withValues(alpha: 0.25)
                  : AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isNegative ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Public Top-Level Helper Function to Launch Add / Edit Product Modal Sheet across all screens
void showAddProductDialog(BuildContext context, {ProductModel? initialProduct}) {
  final state = context.findAncestorStateOfType<_InventoryScreenState>();
  if (state != null) {
    state._showAddProductDialog(context, initialProduct: initialProduct);
  } else {
    final invState = _InventoryScreenState();
    invState._showAddProductDialog(context, initialProduct: initialProduct);
  }
}
