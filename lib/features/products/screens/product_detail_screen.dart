import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../services/smart_stock_reorder_service.dart';
import '../services/smart_barcode_catalog_service.dart';
import '../widgets/barcode_sticker_dialog.dart';
import 'barcode_sheet_studio_screen.dart';

/// Clean, Aesthetic, High-Vibe E-Commerce Product Details Showcase.
/// Features studio hero gallery with tap-to-zoom fullscreen preview,
/// balanced modern typography, tactile counter restock stepper,
/// centralized profit visibility (controlled from Store Settings),
/// and a minimalist specifications chip grid.
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final Function(BuildContext context, ProductModel p)? onEditRequested;
  final Function(BuildContext context, ProductModel p)? onDuplicateRequested;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.onEditRequested,
    this.onDuplicateRequested,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  int _activeImageIndex = 0;
  bool _isTitleExpanded = false;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenImage(BuildContext context, List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (ctx, idx) {
                return Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: AppProductImage(
                      imageUrl: images[idx],
                      expand: true,
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.inventory_2_outlined,
                      fallbackIconSize: 72,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _attachBarcode(BuildContext context, ProductModel p) async {
    await MobileBarcodeScannerDialog.show(
      context,
      title: context.isHindi ? 'बारकोड जोड़ें' : 'Attach Barcode',
      subtitle: p.name,
      targetProductName: p.name,
      autoCloseOnSuccess: true,
      successMessage: context.isHindi
          ? '✓ "${p.name}" में बारकोड जुड़ गया!'
          : '✓ Attached Barcode to "${p.name}"!',
      onBarcodeScanned: (scanned) async {
        final cleanBarcode = scanned.trim();
        if (cleanBarcode.isEmpty) return false;

        final prodCtrl = context.read<ProductController>();
        final existing = prodCtrl.products.any((item) =>
            item.id.toString() != p.id.toString() &&
            item.barcode.trim().isNotEmpty &&
            item.barcode.trim().toLowerCase() == cleanBarcode.toLowerCase());

        if (existing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.isHindi
                    ? 'यह बारकोड पहले से किसी अन्य उत्पाद में जुड़ा है: $cleanBarcode'
                    : 'This barcode is already assigned to another product: $cleanBarcode',
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          return false;
        }

        final updates = <String, dynamic>{
          'barcode': cleanBarcode,
        };
        if (p.sku.trim().isEmpty) {
          updates['sku'] = cleanBarcode;
        }

        // Global Smart Barcode Auto-Fill / Master Catalog Enrichment
        final masterMatch = await SmartBarcodeCatalogService.lookup(cleanBarcode);
        String updatedDisplayName = p.name;
        if (masterMatch != null) {
          final isGenericName = p.name.trim().isEmpty ||
              p.name.trim().toLowerCase() == 'new product' ||
              p.name.trim().toLowerCase() == 'item' ||
              p.name.trim().toLowerCase().startsWith('product ');
          if (isGenericName) {
            updates['name'] = masterMatch.name;
            updatedDisplayName = masterMatch.name;
          }
          if (p.brand.trim().isEmpty && masterMatch.brand.isNotEmpty) {
            updates['brand'] = masterMatch.brand;
            final attrs = Map<String, dynamic>.from(p.attributes);
            attrs['brand'] = masterMatch.brand;
            updates['attributes'] = attrs;
          }
          if ((p.comparePrice <= 0) && masterMatch.mrp > 0) {
            updates['compare_price'] = masterMatch.mrp;
          }
          if ((p.price <= 0) && masterMatch.sellingPrice > 0) {
            updates['price'] = masterMatch.sellingPrice;
          }
          if ((p.category.trim().isEmpty || p.category.trim().toLowerCase() == 'general store') && masterMatch.category.isNotEmpty) {
            updates['category'] = CategoryRegistry.formatCategoryName(masterMatch.category);
          }
          if (p.unit.trim().isEmpty && masterMatch.unit.isNotEmpty) {
            updates['unit'] = masterMatch.unit;
          }
        }

        final success = await prodCtrl.editProduct(p.id, updates);
        if (context.mounted) {
          if (success) {
            final autoFilledNote = masterMatch != null && (updatedDisplayName != p.name || updates.length > 2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  autoFilledNote
                      ? (context.isHindi
                          ? '⚡ "$updatedDisplayName" में बारकोड ($cleanBarcode) जुड़ा और मास्टर कैटलॉग से विवरण ऑटो-फिल हुआ!'
                          : '⚡ Attached Barcode ($cleanBarcode) & Auto-Filled details for "$updatedDisplayName"!')
                      : (context.isHindi
                          ? '✓ "$updatedDisplayName" में बारकोड ($cleanBarcode) जुड़ गया'
                          : '✓ Attached Barcode ($cleanBarcode) to "$updatedDisplayName"'),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  prodCtrl.errorMessage ??
                      (context.isHindi ? 'बारकोड सेव करने में विफल' : 'Failed to save barcode'),
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return success;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodController = context.watch<ProductController>();
    // Synchronize with active product from controller or fallback to widget initial product
    final p = prodController.products.firstWhere(
      (item) => item.id == widget.product.id,
      orElse: () => widget.product,
    );

    final imagesList = p.images.isNotEmpty
        ? p.images
        : (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty ? [p.imageUrl!] : <String>[]);

    final isProfitVisible = prodController.showProfitMargins;

    return Scaffold(
      backgroundColor: context.colorSurface,
      appBar: AppBar(
        backgroundColor: context.colorSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary, size: 22),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/merchant/inventory');
            }
          },
        ),
        title: Text(
          p.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: context.colorTextPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Print Barcode Stickers',
            icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppColors.primary),
            onPressed: () => BarcodeStickerDialog.show(context, p),
          ),
          IconButton(
            tooltip: 'Edit Product',
            icon: const Icon(Icons.edit_note_rounded, size: 24, color: AppColors.primary),
            onPressed: () {
              if (widget.onEditRequested != null) {
                widget.onEditRequested!(context, p);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colorSurface,
            onSelected: (value) {
              if (value == 'attach_barcode') {
                _attachBarcode(context, p);
              } else if (value == 'edit') {
                if (widget.onEditRequested != null) {
                  widget.onEditRequested!(context, p);
                }
              } else if (value == 'duplicate') {
                if (widget.onDuplicateRequested != null) {
                  widget.onDuplicateRequested!(context, p);
                }
              } else if (value == 'barcode') {
                BarcodeStickerDialog.show(context, p);
              } else if (value == 'barcode_studio') {
                BarcodeSheetStudioScreen.show(context, initialProduct: p);
              } else if (value == 'delete') {
                _confirmDelete(context, p.id);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'attach_barcode',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      p.barcode.trim().isEmpty
                          ? (ctx.isHindi ? 'बारकोड जोड़ें' : 'Attach Barcode')
                          : (ctx.isHindi ? 'बारकोड बदलें' : 'Change Barcode'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.barcode.trim().isEmpty ? AppColors.primary : ctx.colorTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'barcode',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Print Barcodes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'barcode_studio',
                child: Row(
                  children: [
                    const Icon(Icons.print_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      ctx.isHindi ? 'बारकोड प्रिंट स्टूडियो' : 'Barcode Sheet Studio',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18, color: ctx.colorTextPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Update Details',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18, color: ctx.colorTextPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Duplicate Product',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Delete Product',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 840;

                  if (isDesktop) {
                    // DESKTOP / TABLET 2-COLUMN STUDIO LAYOUT
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Studio Hero Gallery
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroImageStudio(context, p, imagesList),
                            ],
                          ),
                        ),
                        const SizedBox(width: 22),
                        // Right Column: Header, Pricing, Inventory & Stock, Commercials (if enabled), Specs, Notes
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProductHeader(context, p),
                              const SizedBox(height: 14),
                              _buildPricingHeroCard(context, p),
                              const SizedBox(height: 14),
                              _buildStockManagementCard(context, p),
                              const SizedBox(height: 14),
                              _buildBatchExpiryCard(context, p),
                              if (isProfitVisible) ...[
                                const SizedBox(height: 14),
                                _buildMerchantIntelligenceCard(context, p),
                              ],
                              const SizedBox(height: 14),
                              _buildSpecificationsGrid(context, p),
                              const SizedBox(height: 14),
                              _buildDescriptionCard(context, p),
                              const SizedBox(height: 18),
                              _buildSimilarProductsRow(context, p),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // MOBILE FLUID SINGLE-COLUMN LAYOUT
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroImageStudio(context, p, imagesList),
                      const SizedBox(height: 14),
                      _buildProductHeader(context, p),
                      const SizedBox(height: 14),
                      _buildPricingHeroCard(context, p),
                      const SizedBox(height: 14),
                      _buildStockManagementCard(context, p),
                      const SizedBox(height: 14),
                      _buildBatchExpiryCard(context, p),
                      if (isProfitVisible) ...[
                        const SizedBox(height: 14),
                        _buildMerchantIntelligenceCard(context, p),
                      ],
                      const SizedBox(height: 14),
                      _buildSpecificationsGrid(context, p),
                      const SizedBox(height: 14),
                      _buildDescriptionCard(context, p),
                      const SizedBox(height: 18),
                      _buildSimilarProductsRow(context, p),
                      const SizedBox(height: 36),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. STUDIO HERO GALLERY (Flipkart Style: Clean White Showcase, Floating Heart & Share, Rating Pill, Centered Blue Dot Pagination) ---
  Widget _buildHeroImageStudio(BuildContext context, ProductModel p, List<String> imagesList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Showcase Stage
        Container(
          height: 330,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colorBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imagesList.isNotEmpty
                ? Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Interactive Swipe Carousel
                      PageView.builder(
                        controller: _pageController,
                        itemCount: imagesList.length,
                        onPageChanged: (idx) => setState(() => _activeImageIndex = idx),
                        itemBuilder: (context, idx) {
                          return GestureDetector(
                            onTap: () => _openFullScreenImage(context, imagesList, idx),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Hero(
                                tag: 'product_img_${p.id}_$idx',
                                child: AppProductImage(
                                  imageUrl: imagesList[idx],
                                  expand: true,
                                  fit: BoxFit.contain,
                                  borderRadius: BorderRadius.circular(14),
                                  fallbackIcon: Icons.inventory_2_outlined,
                                  fallbackIconSize: 64,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Floating Top-Left Available Now Status Pill
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: (p.isOutOfStock
                                    ? AppColors.error
                                    : (p.isLowStock ? AppColors.warning : AppColors.success))
                                .withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                p.isOutOfStock
                                    ? (context.isHindi ? 'आउट ऑफ स्टॉक' : 'Out of Stock')
                                    : (p.isLowStock
                                        ? (context.isHindi ? 'कम स्टॉक (${p.stock})' : 'Low Stock (${p.stock})')
                                        : (context.isHindi ? 'उपलब्ध है (${p.stock})' : 'In Stock (${p.stock})')),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating Top-Right Circular Action Buttons: Wishlist & Share (Flipkart Style)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _isWishlisted ? const Color(0xFFEF4444) : const Color(0xFF475569),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isWishlisted = !_isWishlisted),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.share_outlined, color: Color(0xFF475569), size: 19),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.isHindi ? 'उत्पाद लिंक कॉपी हो गया!' : 'Product Link Copied!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Floating Bottom-Left Rating Pill: 4.4 ★ | 14 (Flipkart Style)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '4.4',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.star_rounded, color: Color(0xFF16A34A), size: 14),
                              SizedBox(width: 4),
                              Text(
                                '|  14',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Edit / Change Photos Button
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.onEditRequested != null) {
                              widget.onEditRequested!(context, p);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Edit Photos',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Animated Blue Dot Pagination Pills: ● ○ ○ ○ (Flipkart Style)
                      if (imagesList.length > 1)
                        Positioned(
                          bottom: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(imagesList.length, (idx) {
                              final isSelected = _activeImageIndex == idx;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isSelected ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colorPrimaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No Product Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Attach photo for counter & storefront',
                          style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 15, color: AppColors.primary),
                          label: const Text('Add Photo', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (widget.onEditRequested != null) {
                              widget.onEditRequested!(context, p);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Gallery Thumbnails Strip
        if (imagesList.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagesList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = _activeImageIndex == idx;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeImageIndex = idx);
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : context.colorBorder,
                        width: isSelected ? 2 : 1,
                      ),
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: AppProductImage(
                        imageUrl: imagesList[idx],
                        width: 56,
                        height: 56,
                        expand: true,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.image_rounded,
                        fallbackIconSize: 18,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // --- 2. PRODUCT HEADER: BRAND & EXPANDABLE TITLE (Flipkart Style) ---
  Widget _buildProductHeader(BuildContext context, ProductModel p) {
    final brandName = p.brand.isNotEmpty
        ? p.brand
        : (p.attributes['brand']?.toString() ?? (p.category.isNotEmpty ? p.category.toUpperCase() : 'SHOPSILO'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Name (Bold Header Subtitle like Flipkart)
        Text(
          brandName,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),

        // Product Name with ...more toggle (Flipkart Style)
        GestureDetector(
          onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: context.colorTextPrimary,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: _isTitleExpanded || p.name.length <= 60
                      ? p.name
                      : '${p.name.substring(0, 60)}...',
                ),
                if (p.name.length > 60)
                  TextSpan(
                    text: _isTitleExpanded
                        ? (context.isHindi ? '  कम दिखाएं' : '  less')
                        : (context.isHindi ? '  ...और' : '  ...more'),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. PRICING HERO CARD: UNIFIED FLIPKART ROW (↓70%  3,999  ₹1,199) ---
  Widget _buildPricingHeroCard(BuildContext context, ProductModel p) {
    final hasDiscount = p.comparePrice > p.price;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Unified Flipkart Price Row: ↓70% 3,999 ₹1,199
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hasDiscount) ...[
                Text(
                  '↓${p.discountPct.toInt()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${p.comparePrice.toInt()}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '₹${p.price.toInt()}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: context.colorTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Subline Delivery / Pickup Fee with Chevron
          Row(
            children: [
              Expanded(
                child: Text(
                  '+ ₹0 Delivery Fee • Counter Pickup In Stock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 14, color: context.colorTextMuted),
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      p.isPricePublic ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 14,
                      color: p.isPricePublic ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        p.isPricePublic
                            ? 'Online Storefront: Public Price'
                            : 'Online Storefront: 🔒 Price Hidden',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: p.isPricePublic ? AppColors.success : AppColors.warning,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final newStatus = !p.isPricePublic;
                  final success = await context.read<ProductController>().editProduct(
                    p.id,
                    {'is_price_public': newStatus},
                  );
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newStatus
                            ? 'Price is now visible to online customers.'
                            : 'Price is now hidden from online customers (Shows "Price on Request").'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    p.isPricePublic ? 'Hide Online' : 'Show Online',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4B. INVENTORY STOCK MANAGEMENT & WHOLESALE REORDER ---
  Widget _buildStockManagementCard(BuildContext context, ProductModel p) {
    final isOutOfStock = p.isOutOfStock;
    final isLowStock = p.isLowStock;
    final isHindi = context.isHindi;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? context.colorErrorLight
                            : (isLowStock ? context.colorWarningLight : context.colorPrimaryLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOutOfStock
                            ? Icons.error_outline_rounded
                            : (isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined),
                        size: 16,
                        color: isOutOfStock
                            ? AppColors.error
                            : (isLowStock ? AppColors.warning : AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isHindi ? 'इन्वेंटरी स्टॉक' : 'Inventory Stock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.colorTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? context.colorErrorLight
                      : (isLowStock ? context.colorWarningLight : context.colorSurfaceSubtle),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOutOfStock
                        ? AppColors.error.withValues(alpha: 0.3)
                        : (isLowStock ? AppColors.warning.withValues(alpha: 0.3) : context.colorBorder),
                  ),
                ),
                child: Text(
                  isOutOfStock
                      ? (isHindi ? '❌ स्टॉक समाप्त' : '❌ Out of Stock')
                      : (isLowStock
                          ? (isHindi ? '⚠️ कम स्टॉक (${p.stock})' : '⚠️ Low Stock (${p.stock})')
                          : (isHindi ? '✓ उपलब्ध: ${p.stock}' : '✓ In Stock: ${p.stock}')),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOutOfStock
                        ? AppColors.error
                        : (isLowStock ? AppColors.warning : AppColors.success),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper + Quick Restock Chips Row
          Row(
            children: [
              Text(
                '${context.tr('stock_quick_restock')}:',
                style: TextStyle(fontSize: 11.5, color: context.colorTextMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDeltaChip(context, p, -1, isNegative: true),
                      _buildDeltaChip(context, p, 1),
                      _buildDeltaChip(context, p, 5),
                      _buildDeltaChip(context, p, 10),
                      _buildDeltaChip(context, p, 25),
                      _buildDeltaChip(context, p, 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 10),

          // 1-Tap Wholesale Reorder Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.playlist_add_rounded, size: 16, color: AppColors.primary),
            label: Text(
              context.tr('stock_reorder_btn'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            onPressed: () {
              SmartStockReorderService.addToProcurementList(context, p);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaChip(BuildContext context, ProductModel p, int delta, {bool isNegative = false}) {
    final label = delta > 0 ? '+$delta' : '$delta';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          if (p.stock + delta >= 0) {
            context.read<ProductController>().adjustStock(p, delta);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isNegative ? AppColors.error.withValues(alpha: 0.08) : context.colorPrimaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isNegative ? AppColors.error.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isNegative ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  // --- 4C. BATCH & EXPIRY TRACKING & CLEARANCE MARKDOWN ---
  void _applyClearanceDiscount(ProductModel p, double discountPercent) async {
    final prodCtrl = context.read<ProductController>();
    final oldPrice = p.price;
    final newPrice = (oldPrice * (1.0 - (discountPercent / 100.0))).roundToDouble();
    final comparePrice = p.comparePrice > oldPrice ? p.comparePrice : oldPrice;

    final success = await prodCtrl.editProduct(p.id, {
      'price': newPrice,
      'compare_price': comparePrice,
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isHindi
                  ? '✓ ${discountPercent.toInt()}% क्लीयरेंस डिस्काउंट लागू! नई कीमत: ₹${newPrice.toStringAsFixed(0)} (MRP: ₹${comparePrice.toStringAsFixed(0)})'
                  : '✓ Applied ${discountPercent.toInt()}% Clearance Markdown! New Price: ₹${newPrice.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prodCtrl.errorMessage ?? 'Failed to apply clearance markdown'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditBatchExpirySheet(BuildContext context, ProductModel p) {
    final batchController = TextEditingController(text: p.batchNo);
    DateTime? selectedExpiry = p.expiryDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isHindi = ctx.isHindi;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            decoration: BoxDecoration(
              color: ctx.colorSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHindi ? 'बैच और एक्सपायरी सेट करें' : 'Batch & Expiry Setup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ctx.colorTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: batchController,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'बैच नंबर (Batch No.)' : 'Batch Number (Optional)',
                    hintText: 'e.g. BATCH-2026-A',
                    prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedExpiry ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedExpiry = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: ctx.colorBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedExpiry != null
                                ? '${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}'
                                : (isHindi ? 'एक्सपायरी तिथि चुनें (Select Expiry Date)' : 'Select Expiry Date'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selectedExpiry != null ? FontWeight.bold : FontWeight.normal,
                              color: ctx.colorTextPrimary,
                            ),
                          ),
                        ),
                        if (selectedExpiry != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setSheetState(() => selectedExpiry = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final updatedAttributes = Map<String, dynamic>.from(p.attributes);
                    final bText = batchController.text.trim();
                    if (bText.isNotEmpty) {
                      updatedAttributes['batch_no'] = bText;
                    } else {
                      updatedAttributes.remove('batch_no');
                    }
                    if (selectedExpiry != null) {
                      updatedAttributes['expiry_date'] = selectedExpiry!.toIso8601String().split('T').first;
                    } else {
                      updatedAttributes.remove('expiry_date');
                    }

                    Navigator.pop(sheetCtx);
                    await context.read<ProductController>().editProduct(p.id, {
                      'attributes': updatedAttributes,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isHindi ? 'सेव करें (Save)' : 'Save Batch & Expiry',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBatchExpiryCard(BuildContext context, ProductModel p) {
    final isHindi = context.isHindi;
    final exp = p.expiryDate;
    final hasBatch = p.batchNo.isNotEmpty;
    final hasExpiry = exp != null;
    final isExp = p.isExpired;
    final isNearExp = p.isNearExpiry;

    Color badgeBg;
    Color badgeFg;
    String statusText;
    IconData statusIcon;

    if (isExp) {
      badgeBg = AppColors.error.withValues(alpha: 0.12);
      badgeFg = AppColors.error;
      statusText = isHindi ? '⚠️ एक्सपायर्ड (${p.daysUntilExpiry?.abs()} दिन पहले)' : '⚠️ Expired (${p.daysUntilExpiry?.abs()}d ago)';
      statusIcon = Icons.error_outline_rounded;
    } else if (isNearExp) {
      badgeBg = Colors.orange.withValues(alpha: 0.14);
      badgeFg = Colors.orange.shade900;
      statusText = isHindi ? '⏳ एक्सपायरी नजदीक (${p.daysUntilExpiry} दिन बाकी)' : '⏳ Expiring Soon (${p.daysUntilExpiry}d left)';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (hasExpiry) {
      badgeBg = AppColors.success.withValues(alpha: 0.12);
      badgeFg = AppColors.success;
      statusText = isHindi ? '✓ वैध उत्पाद (${p.daysUntilExpiry} दिन)' : '✓ Fresh / Valid (${p.daysUntilExpiry}d left)';
      statusIcon = Icons.verified_rounded;
    } else {
      badgeBg = context.colorSurfaceSubtle;
      badgeFg = context.colorTextMuted;
      statusText = isHindi ? 'एक्सपायरी सेट नहीं है' : 'Expiry Not Set';
      statusIcon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isExp || isNearExp) ? badgeFg.withValues(alpha: 0.4) : context.colorBorder,
          width: (isExp || isNearExp) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, size: 16, color: badgeFg),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHindi ? 'बैच और एक्सपायरी ट्रैकिंग' : 'Batch & Expiry Alert',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.colorTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showEditBatchExpirySheet(context, p),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        isHindi ? 'बदलें' : 'Edit',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'बैच नंबर' : 'Batch No',
                        style: TextStyle(fontSize: 10.5, color: context.colorTextMuted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBatch ? p.batchNo : '—',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'एक्सपायरी डेट' : 'Expiry Date',
                        style: TextStyle(fontSize: 10.5, color: context.colorTextMuted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasExpiry ? '${exp.day}/${exp.month}/${exp.year}' : '—',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: badgeFg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 1-Tap Clearance Markdown Buttons
          const SizedBox(height: 12),
          Text(
            isHindi ? '⚡ 1-टैप क्लीयरेंस डिस्काउंट (Clearance Sale Markdown)' : '⚡ 1-Tap Clearance Markdown',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildClearanceMarkdownBtn(context, p, 10),
              const SizedBox(width: 6),
              _buildClearanceMarkdownBtn(context, p, 20),
              const SizedBox(width: 6),
              _buildClearanceMarkdownBtn(context, p, 30),
              const SizedBox(width: 6),
              _buildClearanceMarkdownBtn(context, p, 50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearanceMarkdownBtn(BuildContext context, ProductModel p, int pct) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _applyClearanceDiscount(p, pct.toDouble()),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Text(
          '$pct% Off',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // --- 5. MERCHANT INTELLIGENCE & PROFIT HUB (Centrally Controlled from Settings) ---
  Widget _buildMerchantIntelligenceCard(BuildContext context, ProductModel p) {
    final hasCost = p.costPrice > 0;
    final totalInventoryValue = p.price * p.stock;
    final totalProfitPotential = p.profitAmount * p.stock;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.analytics_outlined, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Profit & Commercials Hub',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Clean Minimalist KPI Tiles (Balanced scale)
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'Purchase Cost',
                  value: hasCost ? '₹${p.costPrice.toStringAsFixed(0)}' : '₹0',
                  subtext: 'Per unit cost',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'Unit Margin',
                  value: hasCost ? '+₹${p.profitAmount.toStringAsFixed(0)}' : '₹0',
                  subtext: hasCost ? '${p.profitMarginPct.toStringAsFixed(1)}% margin' : '0%',
                  valueColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _buildMiniStat(
                  context,
                  label: 'Batch Retail',
                  value: '₹${totalInventoryValue.toStringAsFixed(0)}',
                  subtext: '+₹${totalProfitPotential.toStringAsFixed(0)} profit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required String subtext,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.colorTextMuted, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: valueColor ?? context.colorTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            subtext,
            style: TextStyle(fontSize: 9, color: context.colorTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 6. SPECIFICATIONS & ATTRIBUTES SHOWCASE ---
  Widget _buildSpecificationsGrid(BuildContext context, ProductModel p) {
    final specItems = <MapEntry<String, String>>[];

    // 1. Core Identity & Classification
    final brandVal = p.brand.isNotEmpty
        ? p.brand
        : (p.attributes['brand']?.toString().trim() ?? '');
    if (brandVal.isNotEmpty) {
      specItems.add(MapEntry('Brand', brandVal));
    }

    specItems.add(MapEntry('Category', p.category));
    specItems.add(MapEntry('Unit', p.unit));

    if (p.weight > 0) {
      specItems.add(MapEntry('Net Weight', '${p.weight} ${p.unit.isNotEmpty ? p.unit : "g"}'));
    }

    if (p.sku.isNotEmpty) {
      specItems.add(MapEntry('SKU', p.sku));
    }

    if (p.barcode.isNotEmpty) {
      specItems.add(MapEntry('Barcode', p.barcode));
    } else {
      specItems.add(const MapEntry('Barcode', '+ Attach Barcode'));
    }

    // 2. Pricing & Negotiation Rules
    if (p.floorPrice > 0) {
      specItems.add(MapEntry('Floor Price', '₹${p.floorPrice.toStringAsFixed(0)}'));
    }

    if (p.allowBargain) {
      specItems.add(const MapEntry('Bargain', 'Allowed'));
    }

    if (p.lowStockThreshold > 0) {
      specItems.add(MapEntry('Low Stock Alert', '≤ ${p.lowStockThreshold} units'));
    }

    // 3. Dynamic Custom JSONB Attributes & Merchant Specifications
    if (p.attributes.isNotEmpty) {
      p.attributes.forEach((k, v) {
        final kLow = k.toLowerCase().trim();
        if (kLow != 'brand' &&
            kLow != 'category_name' &&
            kLow != 'category' &&
            kLow != 'unit' &&
            v != null &&
            v.toString().trim().isNotEmpty) {
          final formattedKey = k
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
              .join(' ');
          specItems.add(MapEntry(formattedKey, v.toString().trim()));
        }
      });
    }

    if (specItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Specifications & Attributes',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.colorBorder),
                ),
                child: Text(
                  '${specItems.length} specs',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specItems.map((item) {
              final isAttachAction = item.key == 'Barcode' && item.value == '+ Attach Barcode';
              return InkWell(
                onTap: isAttachAction ? () => _attachBarcode(context, p) : null,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isAttachAction ? context.colorPrimaryLight : context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isAttachAction ? AppColors.primary.withValues(alpha: 0.4) : context.colorBorder,
                      width: isAttachAction ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAttachAction) ...[
                        const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          context.isHindi ? 'बारकोड जोड़ें' : 'Attach Barcode',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '${item.key}: ',
                          style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                        ),
                        Flexible(
                          child: Text(
                            item.value,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- 7. DESCRIPTION & CATALOG NOTES ---
  Widget _buildDescriptionCard(BuildContext context, ProductModel p) {
    if (p.description.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.notes_rounded, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Text(
                'Description',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p.description.trim(),
            style: TextStyle(
              fontSize: 12.5,
              color: context.colorTextPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // --- 8. SIMILAR PRODUCTS HORIZONTAL ROW ---
  Widget _buildSimilarProductsRow(BuildContext context, ProductModel currentProduct) {
    final allProducts = context.watch<ProductController>().products;
    final cleanCat = CategoryRegistry.formatCategoryName(currentProduct.category);
    final cleanBrand = currentProduct.brand.trim().toLowerCase();

    final similarItems = allProducts.where((item) {
      if (item.id.toString() == currentProduct.id.toString()) return false;
      final itemCat = CategoryRegistry.formatCategoryName(item.category);
      final itemBrand = item.brand.trim().toLowerCase();

      final sameCat = cleanCat.isNotEmpty && (itemCat == cleanCat || CategoryRegistry.isCategoryMatch(item.category, currentProduct.category));
      final sameBrand = cleanBrand.isNotEmpty && itemBrand == cleanBrand;
      return sameCat || sameBrand;
    }).take(10).toList();

    if (similarItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.isHindi ? 'मिलते-जुलते उत्पाद (Similar Products)' : 'Similar Products',
          trailing: AppBadge(
            label: '${similarItems.length} ${context.isHindi ? 'उत्पाद' : 'Items'}',
            type: AppBadgeType.neutral,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: similarItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: item,
                          onEditRequested: widget.onEditRequested,
                          onDuplicateRequested: widget.onDuplicateRequested,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 124,
                          height: 100,
                          decoration: BoxDecoration(
                            color: context.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AppProductImage(
                            imageUrl: item.imageUrl,
                            width: 124,
                            height: 100,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.inventory_2_outlined,
                            fallbackIconSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CategoryRegistry.formatCategoryName(item.category),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.colorTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${item.price.toStringAsFixed(0)} / ${item.unit}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
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
    );
  }


  void _confirmDelete(BuildContext context, dynamic productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ProductController>().deleteProduct(productId);
              if (success && context.mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
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
}
