import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../services/barcode_generator_service.dart';

/// Multi-Product Barcode Print Studio & Sheet Generator Screen
class BarcodeSheetStudioScreen extends StatefulWidget {
  final List<ProductModel>? initialProducts;
  final ProductModel? initialProduct;

  const BarcodeSheetStudioScreen({
    super.key,
    this.initialProducts,
    this.initialProduct,
  });

  static Future<void> show(
    BuildContext context, {
    List<ProductModel>? initialProducts,
    ProductModel? initialProduct,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeSheetStudioScreen(
          initialProducts: initialProducts,
          initialProduct: initialProduct,
        ),
      ),
    );
  }

  @override
  State<BarcodeSheetStudioScreen> createState() => _BarcodeSheetStudioScreenState();
}

class _BarcodeSheetStudioScreenState extends State<BarcodeSheetStudioScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();

  BarcodeLabelFormat _selectedFormat = BarcodeLabelFormat.a4Sheet65; // Default micro-labels for 1-2 items
  final List<ProductModel> _queue = [];
  final Map<String, int> _quantities = {};

  bool _showShopName = true;
  bool _showPrice = true;
  bool _showPkd = true;
  bool _isProcessing = false;
  int _activePreviewPage = 1;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    // Initialize initial products if passed
    if (widget.initialProduct != null) {
      _addProduct(widget.initialProduct!, count: 1);
    }
    if (widget.initialProducts != null) {
      for (final p in widget.initialProducts!) {
        _addProduct(p, count: 1);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = context.read<AuthController>().currentShop;
      if (shop != null && shop.name.trim().isNotEmpty) {
        _shopNameController.text = shop.name.trim().toUpperCase();
      } else {
        _shopNameController.text = 'SHOPSILO STORE';
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _addProduct(ProductModel product, {int count = 1}) {
    setState(() {
      final existingIndex = _queue.indexWhere((p) => p.id == product.id);
      if (existingIndex >= 0) {
        _quantities[product.id] = (_quantities[product.id] ?? 1) + count;
      } else {
        _queue.add(product);
        _quantities[product.id] = count;
      }
    });
  }

  void _updateQuantity(String productId, int newCount) {
    setState(() {
      if (newCount <= 0) {
        _queue.removeWhere((p) => p.id == productId);
        _quantities.remove(productId);
      } else {
        _quantities[productId] = newCount.clamp(1, 999);
      }
    });
  }

  void _clearQueue() {
    setState(() {
      _queue.clear();
      _quantities.clear();
      _activePreviewPage = 1;
    });
  }

  void _addAllInStock(List<ProductModel> allProducts) {
    setState(() {
      for (final p in allProducts) {
        if (p.stock > 0 && !_queue.any((item) => item.id == p.id)) {
          _queue.add(p);
          _quantities[p.id] = 1;
        }
      }
    });
  }

  int get _totalStickers {
    return _queue.fold(0, (sum, p) => sum + (_quantities[p.id] ?? 1));
  }

  List<BarcodeLabelItem> _generateFlatLabelItems(String shopName) {
    final list = <BarcodeLabelItem>[];
    for (final product in _queue) {
      final count = _quantities[product.id] ?? 1;
      final labelItem = BarcodeLabelItem.fromProduct(
        product: product,
        shopName: shopName,
        showShopName: _showShopName,
        showPrice: _showPrice,
        showPkd: _showPkd,
      );
      for (int i = 0; i < count; i++) {
        list.add(labelItem);
      }
    }
    return list;
  }

  Future<void> _handlePrint() async {
    if (_queue.isEmpty || _totalStickers == 0) {
      CustomSnackbar.showWarning(context, context.isHindi ? 'कृपया प्रिंट करने के लिए उत्पाद जोड़ें' : 'Please add products to print queue');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final shopName = _shopNameController.text.trim().isNotEmpty
          ? _shopNameController.text.trim().toUpperCase()
          : 'SHOPSILO STORE';
      final items = _generateFlatLabelItems(shopName);

      await BarcodeGeneratorService.printLabels(
        items: items,
        format: _selectedFormat,
        jobName: 'ShopSilo_Barcode_Batch_${items.length}',
      );
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSharePdf() async {
    if (_queue.isEmpty || _totalStickers == 0) {
      CustomSnackbar.showWarning(context, context.isHindi ? 'कृपया प्रिंट करने के लिए उत्पाद जोड़ें' : 'Please add products to print queue');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final shopName = _shopNameController.text.trim().isNotEmpty
          ? _shopNameController.text.trim().toUpperCase()
          : 'SHOPSILO STORE';
      final items = _generateFlatLabelItems(shopName);

      await BarcodeGeneratorService.shareLabelsPdf(
        items: items,
        format: _selectedFormat,
        filename: 'ShopSilo_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) CustomSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final allProducts = context.watch<ProductController>().products;
    final stats = BarcodeGeneratorService.calculatePacking(
      totalStickers: _totalStickers,
      format: _selectedFormat,
    );

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: context.colorBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? '🖨️ बारकोड प्रिंट स्टूडियो' : '🖨️ Barcode Print Studio',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              isHindi ? 'मल्टीपल उत्पाद स्टीकर शीट और लेआउट' : 'Multi-product sticker sheet layout & printing',
              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
            ),
          ],
        ),
        actions: [
          if (_queue.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
              label: Text(
                isHindi ? 'खाली करें' : 'Clear',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              onPressed: _clearQueue,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Product Selector & Queue
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildQueueAndPickerSection(context, allProducts),
                    ),
                  ),
                  VerticalDivider(width: 1, color: context.colorBorder),
                  // Right Side: Format, Packing Dashboard & Visual Sheet Preview
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildFormatAndPreviewSection(context, stats),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _buildQueueAndPickerSection(context, allProducts),
                    Divider(height: 24, color: context.colorBorder),
                    _buildFormatAndPreviewSection(context, stats),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context, stats),
    );
  }

  // =========================================================================
  // LEFT: PRODUCT SEARCH & PRINT QUEUE
  // =========================================================================
  Widget _buildQueueAndPickerSection(BuildContext context, List<ProductModel> allProducts) {
    final isHindi = context.isHindi;

    // Filter products based on search text
    final query = _searchFilter.trim().toLowerCase();
    final filteredCatalog = query.isEmpty
        ? allProducts.take(8).toList()
        : allProducts
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.barcode.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query) ||
                p.category.toLowerCase().contains(query))
            .take(15)
            .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar to add products to queue
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.colorSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isHindi
                          ? 'सामान खोजें (नाम, बारकोड या SKU)...'
                          : 'Search product to add (Name, Barcode, SKU)...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() => _searchFilter = val);
                    },
                  ),
                ),
                if (_searchFilter.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchFilter = '');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Catalog quick add matches (horizontal scroll chips or dropdown)
          if (filteredCatalog.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Quick add all in stock
                  ActionChip(
                    avatar: const Icon(Icons.playlist_add_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      isHindi ? '+ सभी स्टॉक वाले' : '+ All In-Stock',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: context.colorPrimaryLight,
                    side: const BorderSide(color: AppColors.primary),
                    onPressed: () => _addAllInStock(allProducts),
                  ),
                  const SizedBox(width: 8),
                  ...filteredCatalog.map((product) {
                    final inQueue = _queue.any((p) => p.id == product.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: inQueue,
                        avatar: inQueue
                            ? const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white)
                            : const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                        label: Text(
                          '${product.name} (₹${product.price.toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: inQueue ? FontWeight.bold : FontWeight.w500,
                            color: inQueue ? Colors.white : context.colorTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: context.colorSurfaceSubtle,
                        side: BorderSide(color: inQueue ? AppColors.primary : context.colorBorder),
                        onSelected: (_) => _addProduct(product, count: 1),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Print Queue Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isHindi
                      ? 'प्रिंट सूची (${_queue.length} उत्पाद, $_totalStickers स्टीकर)'
                      : 'Print Queue (${_queue.length} items, $_totalStickers stickers)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_queue.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  isHindi ? 'प्रति उत्पाद संख्या बदलें' : 'Set count per item',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 4. Print Queue List
          if (_queue.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colorBorder, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    isHindi ? 'प्रिंट सूची खाली है' : 'Print Queue is Empty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHindi
                        ? 'ऊपर से किसी भी सामान को सर्च करके जोड़ें और जितने चाहे उतने स्टीकर (1, 2, 5...) प्रिंट करें।'
                        : 'Search and tap any product above to queue stickers. Print 1, 2, or any custom count without wasting paper!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _queue.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final product = _queue[index];
                final count = _quantities[product.id] ?? 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colorSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppProductImage(
                          imageUrl: product.imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name & Barcode
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '₹${product.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: context.colorSurfaceSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: context.colorBorder),
                                    ),
                                    child: Text(
                                      product.barcode.isNotEmpty ? product.barcode : product.sku,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: context.colorTextMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Stepper: [-] count [+]
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateQuantity(product.id, count - 1),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            alignment: Alignment.center,
                            child: Text(
                              '$count',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateQuantity(product.id, count + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateQuantity(product.id, 0),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT: FORMAT SELECTION, UTILIZATION DASHBOARD & VISUAL SHEET PREVIEW
  // =========================================================================
  Widget _buildFormatAndPreviewSection(BuildContext context, SheetPackingStats stats) {
    final isHindi = context.isHindi;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Format Selection Header
          Text(
            isHindi ? '1. स्टीकर शीट फॉर्मेट चुनें' : '1. Select Sticker Sheet Format',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Format Cards
          _buildFormatOptionCard(
            context,
            format: BarcodeLabelFormat.a4Sheet65,
            badge: isHindi ? '⭐ छोटे 1-2 सामान के लिए' : '⭐ Best for 1-2 small items',
          ),
          const SizedBox(height: 6),
          _buildFormatOptionCard(
            context,
            format: BarcodeLabelFormat.a4Sheet40,
          ),
          const SizedBox(height: 6),
          _buildFormatOptionCard(
            context,
            format: BarcodeLabelFormat.a4Sheet24,
            badge: 'Standard Desmat/Avery',
          ),
          const SizedBox(height: 6),
          _buildFormatOptionCard(
            context,
            format: BarcodeLabelFormat.thermalRoll50x25,
          ),
          const SizedBox(height: 16),

          // 2. Customization Toggles
          Text(
            isHindi ? '2. स्टीकर पर क्या दिखाना है?' : '2. Label Elements',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                selected: _showShopName,
                label: Text(isHindi ? 'दुकान का नाम' : 'Shop Name'),
                onSelected: (val) => setState(() => _showShopName = val),
              ),
              FilterChip(
                selected: _showPrice,
                label: Text(isHindi ? 'मूल्य (₹)' : 'Price (₹)'),
                onSelected: (val) => setState(() => _showPrice = val),
              ),
              FilterChip(
                selected: _showPkd,
                label: Text(isHindi ? 'पैकिंग तारीख (PKD)' : 'Packing Date'),
                onSelected: (val) => setState(() => _showPkd = val),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Live Sheet Packing & Paper Utilization Dashboard
          Text(
            isHindi ? '3. शीट उपयोग और पेपर हिसाब' : '3. Sheet Utilization & Paper Stats',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        label: isHindi ? 'कुल स्टीकर' : 'Total Stickers',
                        value: '${stats.totalStickers}',
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        label: isHindi ? 'प्रति शीट' : 'Per Sheet',
                        value: '${stats.labelsPerPage}',
                        color: context.colorTextPrimary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        context,
                        label: isHindi ? 'कुल A4 पेज' : 'Pages Needed',
                        value: '${stats.pagesNeeded}',
                        color: stats.pagesNeeded > 0 ? AppColors.success : context.colorTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stats.pagesNeeded > 0 ? (stats.utilizationPercentage / 100.0).clamp(0.05, 1.0) : 0,
                    minHeight: 8,
                    backgroundColor: context.colorSurfaceSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      stats.utilizationPercentage > 80 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFormat.isA4Sheet
                      ? (isHindi
                          ? '✓ कुल ${stats.totalStickers} स्टीकर ${stats.pagesNeeded} A4 पेज पर प्रिंट होंगे। शीट पर ${stats.emptySlotsOnLastPage} खाली जगह बचेंगी जिसे आप बाद में इस्तेमाल कर सकते हैं।'
                          : '✓ ${stats.totalStickers} stickers fit across ${stats.pagesNeeded} page(s). ${stats.emptySlotsOnLastPage} blank slots remain on the last sheet for future use.')
                      : (isHindi
                          ? '✓ थर्मल प्रिंटर पर कुल ${stats.totalStickers} स्टीकर एक-एक करके प्रिंट होंगे।'
                          : '✓ ${stats.totalStickers} individual labels will be spooled to the thermal printer.'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Interactive Visual Sheet Mini-Map Preview
          if (_selectedFormat.isA4Sheet && stats.totalStickers > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHindi ? 'शीट पूर्वावलोकन (Sheet Layout)' : 'Sheet Layout Preview',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (stats.pagesNeeded > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        onPressed: _activePreviewPage > 1
                            ? () => setState(() => _activePreviewPage--)
                            : null,
                      ),
                      Text(
                        'Page $_activePreviewPage / ${stats.pagesNeeded}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        onPressed: _activePreviewPage < stats.pagesNeeded
                            ? () => setState(() => _activePreviewPage++)
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInteractiveSheetMiniMap(context, stats),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatOptionCard(
    BuildContext context, {
    required BarcodeLabelFormat format,
    String? badge,
  }) {
    final isSel = _selectedFormat == format;
    final isHindi = context.isHindi;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = format;
          _activePreviewPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? context.colorPrimaryLight : context.colorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? AppColors.primary : context.colorBorder,
            width: isSel ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSel ? AppColors.primary : context.colorTextMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        format.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSel ? AppColors.primary : context.colorTextPrimary,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHindi ? format.subtitleHi : format.subtitleEn,
                    style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
        ),
      ],
    );
  }

  // =========================================================================
  // INTERACTIVE MINI-MAP OF THE A4 SHEET
  // =========================================================================
  Widget _buildInteractiveSheetMiniMap(BuildContext context, SheetPackingStats stats) {
    final perPage = _selectedFormat.labelsPerPage;
    final cols = _selectedFormat.columns;
    final rows = _selectedFormat.rows;

    final flatItems = _generateFlatLabelItems(_shopNameController.text.trim());
    final startIndex = (_activePreviewPage - 1) * perPage;

    return Center(
      child: AspectRatio(
        aspectRatio: 210 / 297, // Real A4 paper ratio
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: perPage,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: (210 / cols) / (297 / rows),
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemBuilder: (ctx, slotIdx) {
              final globalItemIdx = startIndex + slotIdx;
              final isFilled = globalItemIdx < flatItems.length;

              if (isFilled) {
                final item = flatItems[globalItemIdx];
                return Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 0.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 5.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      Text(
                        '₹${item.sellingPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 1),
                        height: 4,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                );
              } else {
                // Empty blank slot on physical sticker sheet
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text(
                      '${slotIdx + 1}',
                      style: TextStyle(fontSize: 5, color: Colors.grey.shade400),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BOTTOM FLOATING ACTION BAR
  // =========================================================================
  Widget _buildBottomActionBar(BuildContext context, SheetPackingStats stats) {
    final isHindi = context.isHindi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        border: Border(top: BorderSide(color: context.colorBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Share PDF
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: context.colorBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  isHindi ? 'PDF शेयर करें' : 'Share PDF',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessing ? null : _handleSharePdf,
              ),
            ),
            const SizedBox(width: 10),

            // Direct Print
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  isHindi
                      ? 'प्रिंट बारकोड शीट ($_totalStickers)'
                      : 'Print Barcode Sheet ($_totalStickers)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isProcessing ? null : _handlePrint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
