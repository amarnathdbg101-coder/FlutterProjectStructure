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
import '../widgets/barcode_sticker_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import 'barcode_sheet_studio_screen.dart';
import 'inventory_screen.dart' show showAddProductDialog;

/// Clean, Aesthetic, High-Vibe E-Commerce Product Details Showcase.
/// Complete parity with CustomerFrontend UI/UX while providing essential
/// merchant controls:
/// - Flipkart-style white showcase stage with live availability pill, discount tag,
///   circular floating action buttons (Favorite, Share, Zoom, Camera), rating pill,
///   animated blue dot pagination, and interactive thumbnails strip.
/// - Customer-identical Executive Pricing Hero Card with savings callout & 1-tap
///   Online Storefront Price Visibility toggle (Public vs Hidden Mandi Rate).
/// - Apparel Size & Beauty Shade Variant Matrix preview.
/// - Tactical Counter Restock Stepper & Inventory Health (Instant 0ms sync).
/// - Merchant Intelligence & Commercials Hub (Purchase Cost, Unit Margin %, Batch Retail).
/// - Structured Specifications Table & Description card matching customer side.
/// - Integrated Barcode Printing & Hardware Station.
/// - Responsive 2-column desktop/tablet layout and zero-overflow fluid mobile layout.
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

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _activeImageIndex = 0;
  bool _isTitleExpanded = false;
  bool _isProfitExpanded = false;
  String? _selectedSize;
  String? _selectedColor;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize variant selection if available
    final attrs = widget.product.attributes;
    if (attrs.containsKey('size') || attrs.containsKey('sizes')) {
      final raw = (attrs['size'] ?? attrs['sizes']).toString();
      final list = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) _selectedSize = list.first;
    }
    if (attrs.containsKey('color') || attrs.containsKey('colors')) {
      final raw = (attrs['color'] ?? attrs['colors']).toString();
      final list = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) _selectedColor = list.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
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

        final success = await prodCtrl.editProduct(p.id, updates);
        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.isHindi
                      ? '✓ बारकोड सफलतापूर्वक अपडेट हो गया!'
                      : '✓ Barcode attached successfully!',
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  prodCtrl.errorMessage ??
                      (context.isHindi ? 'बारकोड सेव नहीं हो सका' : 'Failed to update barcode'),
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

  void _shareProductViaWhatsApp(BuildContext context, ProductModel p) async {
    final currentShop = context.read<AuthController>().currentShop ?? LocalCacheService.getShop();
    final shopSlug = currentShop?.slug.isNotEmpty == true ? currentShop!.slug : '';
    final shopName = currentShop?.name.isNotEmpty == true ? currentShop!.name : 'ShopSilo';

    await WhatsAppShareHelper.shareProduct(
      context: context,
      productName: p.name,
      price: p.price,
      comparePrice: p.comparePrice,
      productId: p.id.toString(),
      shopSlug: shopSlug,
      shopName: shopName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodController = context.watch<ProductController>();
    // Synchronize with active product from controller or fallback to widget initial product
    final p = prodController.products.firstWhere(
      (item) => item.id.toString() == widget.product.id.toString(),
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
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: context.isHindi ? 'शेयर करें' : 'Share Product',
            onPressed: () => _shareProductViaWhatsApp(context, p),
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
                } else {
                  showAddProductDialog(context, initialProduct: p);
                }
              } else if (value == 'duplicate') {
                if (widget.onDuplicateRequested != null) {
                  widget.onDuplicateRequested!(context, p);
                } else {
                  showAddProductDialog(context, initialProduct: p, isDuplicate: true);
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
                      ctx.isHindi ? 'बारकोड स्टीकर प्रिंट' : 'Print Barcodes',
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
                      ctx.isHindi ? 'बारकोड प्रिंट स्टूडियो (A4)' : 'Barcode Sheet Studio',
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
                      ctx.isHindi ? 'विवरण बदलें' : 'Update Details',
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
                      ctx.isHindi ? 'कॉपी बनाएं' : 'Duplicate Product',
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
        child: Column(
          children: [
            Expanded(
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
                              // Left Column: Studio Hero Gallery & Barcode Hardware Station
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeroImageStudio(context, p, imagesList),
                                    const SizedBox(height: 16),
                                    _buildBarcodeHardwareCard(context, p),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 22),
                              // Right Column: Header, Pricing, Restock Stepper, Commercials, Specs, Notes
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildProductHeader(context, p),
                                    const SizedBox(height: 14),
                                    _buildPricingHeroCard(context, p),
                                    const SizedBox(height: 14),
                                    _buildVariantMatrix(context, p),
                                    const SizedBox(height: 14),
                                    _buildCounterRestockCard(context, p),
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
                            _buildVariantMatrix(context, p),
                            const SizedBox(height: 14),
                            _buildCounterRestockCard(context, p),
                            if (isProfitVisible) ...[
                              const SizedBox(height: 14),
                              _buildMerchantIntelligenceCard(context, p),
                            ],
                            const SizedBox(height: 14),
                            _buildSpecificationsGrid(context, p),
                            const SizedBox(height: 14),
                            _buildDescriptionCard(context, p),
                            const SizedBox(height: 14),
                            _buildBarcodeHardwareCard(context, p),
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
            // Sticky Bottom Quick Action Bar
            _buildBottomActionBar(context, p),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. STUDIO HERO GALLERY (CustomerFrontend Flipkart-Style Parity)
  // =========================================================================
  Widget _buildHeroImageStudio(BuildContext context, ProductModel p, List<String> imagesList) {
    final hasDiscount = p.hasDiscount;
    final discountPct = p.discountPct.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Showcase Stage
        Container(
          height: 340,
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

                      // Floating Top-Left Available Now Status Pill & Savings Tag
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live Availability Pill with Pulsing Dot
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: (p.isOutOfStock
                                        ? AppColors.error
                                        : (p.isLowStock ? AppColors.warning : AppColors.success))
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FadeTransition(
                                    opacity: _pulseAnimation,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
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

                            // Savings Pill
                            if (hasDiscount && discountPct >= 5) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.10),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$discountPct% ${context.isHindi ? 'छूट' : 'OFF'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Floating Top-Right Circular Action Button: Fullscreen Zoom
                      Positioned(
                        top: 14,
                        right: 14,
                        child: _buildFloatingRoundButton(
                          icon: Icons.fullscreen_rounded,
                          iconColor: const Color(0xFF475569),
                          tooltip: context.isHindi ? 'बड़ा करके देखें' : 'Zoom',
                          onTap: () => _openFullScreenImage(context, imagesList, _activeImageIndex),
                        ),
                      ),



                      // Floating Bottom-Right Photo Counter Pill (📷 1 / 4)
                      if (imagesList.length > 1)
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt_outlined, size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${_activeImageIndex + 1} / ${imagesList.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Centered Blue Dot Pagination Pills: ● ○ ○ ○ (Flipkart Style)
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
                                  color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
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
                          context.isHindi ? 'उत्पाद की फोटो नहीं है' : 'No Product Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.isHindi
                              ? 'काउंटर और ऑनलाइन स्टोर के लिए फोटो लगाएं'
                              : 'Attach photo for counter & storefront',
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
                          label: Text(
                            context.isHindi ? 'फोटो जोड़ें' : 'Add Photo',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
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

        // Gallery Thumbnails Strip (Rounded Rectangles with Blue Active Border)
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

  Widget _buildFloatingRoundButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
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
        icon: Icon(icon, color: iconColor, size: 19),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // =========================================================================
  // 2. PRODUCT HEADER: BRAND & EXPANDABLE TITLE (Customer Side Parity)
  // =========================================================================
  Widget _buildProductHeader(BuildContext context, ProductModel p) {
    final brandName = p.brand.isNotEmpty
        ? p.brand
        : (p.attributes['brand']?.toString() ?? (p.category.isNotEmpty ? p.category.toUpperCase() : 'SHOPSILO'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Eyebrow Tag
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colorPrimaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                brandName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.colorBorder),
              ),
              child: Text(
                p.category,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Product Name with ...more toggle
        GestureDetector(
          onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w700,
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
        const SizedBox(height: 8),

        // Trust Signals Row: Verified Store & Live Storefront Badges (Wrapped for zero overflow)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    context.isHindi ? 'सत्यापित स्टोर' : 'Verified Store',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: p.isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.isActive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.isActive ? AppColors.success : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    p.isActive
                        ? (context.isHindi ? 'डिजिटल स्टोर पर एक्टिव' : 'Active on Storefront')
                        : (context.isHindi ? 'ऑफलाइन (छिपा हुआ)' : 'Inactive (Offline)'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: p.isActive ? const Color(0xFF16A34A) : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 3. PRICING HERO CARD: UNIFIED ROW + ONLINE VISIBILITY TOGGLE
  // =========================================================================
  Widget _buildPricingHeroCard(BuildContext context, ProductModel p) {
    final hasDiscount = p.comparePrice > p.price;
    final savings = hasDiscount ? (p.comparePrice - p.price) : 0.0;
    final discountPct = p.discountPct.toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Unified Price Row: ₹SellingPrice  ₹MRP  ↓X% OFF
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '₹${p.price.toInt()}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.colorTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (hasDiscount) ...[
                Text(
                  '₹${p.comparePrice.toInt()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '↓$discountPct% OFF',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Savings callout banner
          if (hasDiscount) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    context.isHindi
                        ? 'बचत ₹${savings.toInt()} ($discountPct% छूट)'
                        : 'Save ₹${savings.toInt()} ($discountPct% OFF)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Subline Delivery / Pickup Fee with Chevron
          Row(
            children: [
              Expanded(
                child: Text(
                  context.isHindi
                      ? 'दुकान से पिकअप · कोई डिलीवरी चार्ज नहीं'
                      : 'Store Pickup · Ready at counter in 15 mins',
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

          const SizedBox(height: 12),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 12),

          // Online Storefront Price Visibility Control
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      p.isPricePublic ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 15,
                      color: p.isPricePublic ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.isPricePublic
                                ? (context.isHindi ? 'ऑनलाइन स्टोर: दाम दिख रहा है' : 'Online Store: Public Price')
                                : (context.isHindi ? 'ऑनलाइन स्टोर: दाम छुपा हुआ है' : 'Online Store: 🔒 Price Hidden'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.isPricePublic ? AppColors.success : AppColors.warning,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.isPricePublic
                                ? (context.isHindi ? 'ग्राहकों को दाम दिखेगा' : 'Customers can see listed price')
                                : (context.isHindi ? 'ग्राहकों को "दाम पूछें" दिखेगा' : 'Shows "Price on Request" to buyers'),
                            style: TextStyle(fontSize: 10, color: context.colorTextMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
                            ? (context.isHindi ? 'दाम ऑनलाइन ग्राहकों को दिखने लगा।' : 'Price is now visible to online customers.')
                            : (context.isHindi ? 'दाम ऑनलाइन ग्राहकों से छुपा दिया गया है।' : 'Price is now hidden from online customers.')),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    p.isPricePublic
                        ? (context.isHindi ? 'दाम छुपाएं' : 'Hide Online')
                        : (context.isHindi ? 'दाम दिखाएं' : 'Show Online'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
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

  // =========================================================================
  // 4. APPAREL SIZES & COLORS VARIANT MATRIX (Customer Parity)
  // =========================================================================
  Widget _buildVariantMatrix(BuildContext context, ProductModel p) {
    final attrs = p.attributes;
    final List<String> sizes = [];
    final List<String> colors = [];

    // Extract sizes if present
    if (attrs.containsKey('sizes') || attrs.containsKey('size')) {
      final raw = (attrs['sizes'] ?? attrs['size']).toString();
      sizes.addAll(raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    // Extract colors if present
    if (attrs.containsKey('colors') || attrs.containsKey('color')) {
      final raw = (attrs['colors'] ?? attrs['color']).toString();
      colors.addAll(raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }

    if (sizes.isEmpty && colors.isEmpty) return const SizedBox.shrink();

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
                child: const Icon(Icons.style_outlined, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.isHindi ? 'वेरिएंट एवं विकल्प (Variants & Options)' : 'Variants & Options',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sizes Row
          if (sizes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.isHindi ? 'साइज़ (Sizes)' : 'Select Size',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colorTextMuted),
                ),
                if (_selectedSize != null)
                  Text(
                    '${context.isHindi ? "चुना गया" : "Selected"}: $_selectedSize',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sizes.map((sz) {
                final isSelected = _selectedSize == sz;
                return InkWell(
                  onTap: () => setState(() => _selectedSize = sz),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? context.colorPrimaryLight : context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : context.colorBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      sz,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppColors.primary : context.colorTextPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (colors.isNotEmpty) const SizedBox(height: 14),
          ],

          // Colors Row
          if (colors.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.isHindi ? 'रंग (Colors)' : 'Select Color',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colorTextMuted),
                ),
                if (_selectedColor != null)
                  Text(
                    '${context.isHindi ? "चुना गया" : "Selected"}: $_selectedColor',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((col) {
                final isSelected = _selectedColor == col;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = col),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? context.colorPrimaryLight : context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : context.colorBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _resolveColorPreview(col),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26, width: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          col,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppColors.primary : context.colorTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _resolveColorPreview(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('red')) return Colors.red;
    if (lower.contains('blue')) return Colors.blue;
    if (lower.contains('green')) return Colors.green;
    if (lower.contains('yellow')) return Colors.amber;
    if (lower.contains('black')) return Colors.black;
    if (lower.contains('white')) return Colors.white;
    if (lower.contains('pink')) return Colors.pinkAccent;
    if (lower.contains('purple')) return Colors.purple;
    if (lower.contains('orange')) return Colors.orange;
    if (lower.contains('grey') || lower.contains('gray')) return Colors.grey;
    return AppColors.primary;
  }

  // =========================================================================
  // 5. TACTICAL COUNTER RESTOCK STEPPER & INVENTORY HEALTH (Shop Owner)
  // =========================================================================
  Widget _buildCounterRestockCard(BuildContext context, ProductModel p) {
    final prodCtrl = context.read<ProductController>();

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
                child: const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.isHindi ? 'स्टॉक एवं इन्वेंटरी' : 'Stock & Inventory',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (p.isOutOfStock
                          ? AppColors.error
                          : (p.isLowStock ? AppColors.warning : AppColors.success))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.isOutOfStock
                      ? (context.isHindi ? 'आउट ऑफ स्टॉक' : 'Out of Stock')
                      : (p.isLowStock
                          ? (context.isHindi ? 'कम स्टॉक' : 'Low Stock')
                          : (context.isHindi ? 'पर्याप्त स्टॉक' : 'In Stock')),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: p.isOutOfStock
                        ? AppColors.error
                        : (p.isLowStock ? AppColors.warning : AppColors.success),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper Row: [-]  {stock} {unit}  [+]  +  Quick Restock Chips
          Row(
            children: [
              // Decrement Stepper Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: context.colorSurfaceSubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.remove_rounded, size: 20),
                onPressed: p.stock > 0
                    ? () => prodCtrl.adjustStock(p, -1)
                    : null,
              ),
              const SizedBox(width: 8),

              // Stock Number Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${p.stock}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.colorTextPrimary,
                    ),
                  ),
                  Text(
                    p.unit.isNotEmpty ? p.unit : (context.isHindi ? 'यूनिट' : 'units'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.colorTextMuted),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Increment Stepper Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: () => prodCtrl.adjustStock(p, 1),
              ),

              const SizedBox(width: 10),

              // Quick Restock Chips: +5, +10, +25, +50
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  alignment: WrapAlignment.end,
                  children: [5, 10, 25, 50].map((qty) {
                    return InkWell(
                      onTap: () {
                        prodCtrl.adjustStock(p, qty);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.isHindi
                                  ? '+$qty यूनिट स्टॉक में जोड़ा गया!'
                                  : 'Added +$qty units to stock!',
                            ),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: context.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '+$qty',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          // Low stock alert indicator
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: context.colorTextMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  context.isHindi
                      ? 'स्टॉक ≤ ${p.lowStockThreshold} होने पर रीस्टॉक अलर्ट मिलेगा'
                      : 'Low stock alerts trigger when stock is ≤ ${p.lowStockThreshold} ${p.unit}',
                  style: TextStyle(fontSize: 10.5, color: context.colorTextMuted, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. MERCHANT INTELLIGENCE & COMMERCIALS HUB (Shop Owner Specific)
  // =========================================================================
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isHindi ? 'मुनाफा एवं व्यापारिक जानकारी' : 'Profit & Commercials Hub',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      context.isHindi ? '🔒 काउंटर प्राइवेसी (सिर्फ दुकानदार के लिए)' : '🔒 Counter Privacy (Merchant Only)',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isProfitExpanded = !_isProfitExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(
                    _isProfitExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.colorTextMuted,
                  ),
                ),
              ),
            ],
          ),

          if (_isProfitExpanded) ...[
            const SizedBox(height: 12),
            // 4 Clean Minimalist KPI Tiles
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: context.isHindi ? 'खरीद लागत' : 'Purchase Cost',
                    value: hasCost ? '₹${p.costPrice.toStringAsFixed(0)}' : '₹0',
                    subtext: context.isHindi ? 'प्रति यूनिट' : 'Per unit cost',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: context.isHindi ? 'यूनिट मुनाफा' : 'Unit Margin',
                    value: hasCost ? '+₹${p.profitAmount.toStringAsFixed(0)}' : '₹0',
                    subtext: hasCost ? '${p.profitMarginPct.toStringAsFixed(1)}% margin' : '0%',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: context.isHindi ? 'कुल स्टॉक वैल्यू' : 'Batch Retail',
                    value: '₹${totalInventoryValue.toStringAsFixed(0)}',
                    subtext: context.isHindi ? 'वर्तमान स्टॉक' : '${p.stock} in inventory',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _buildMiniStat(
                    context,
                    label: context.isHindi ? 'संभावित कुल लाभ' : 'Batch Profit',
                    value: '+₹${totalProfitPotential.toStringAsFixed(0)}',
                    subtext: context.isHindi ? 'बिक्री होने पर' : 'Upon complete sale',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),

            // Batch & Expiry Radar (if present)
            if (p.batchNo.isNotEmpty || p.expiryDate != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    if (p.batchNo.isNotEmpty) ...[
                      Text(
                        'Batch: ${p.batchNo}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (p.expiryDate != null) ...[
                      Text(
                        'Exp: ${p.expiryDate!.day}/${p.expiryDate!.month}/${p.expiryDate!.year}',
                        style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                      ),
                      if (p.daysUntilExpiry != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (p.daysUntilExpiry! <= 30 ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.daysUntilExpiry! <= 0
                                ? (context.isHindi ? 'अवधि समाप्त' : 'Expired')
                                : '${p.daysUntilExpiry} ${context.isHindi ? "दिन बाकी" : "days left"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.daysUntilExpiry! <= 30 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: context.colorTextMuted, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valueColor ?? context.colorTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 9.5, color: context.colorTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. SPECIFICATIONS & ATTRIBUTES SHOWCASE (Zero-Overflow Table Format)
  // =========================================================================
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
      specItems.add(MapEntry('Net Weight', '${p.weight} ${p.unit.isNotEmpty ? p.unit : "kg"}'));
    }

    if (p.sku.isNotEmpty) {
      specItems.add(MapEntry('SKU', p.sku));
    }

    if (p.barcode.isNotEmpty) {
      specItems.add(MapEntry('Barcode', p.barcode));
    } else {
      specItems.add(const MapEntry('Barcode', '+ Attach Barcode'));
    }

    if (p.lowStockThreshold > 0) {
      specItems.add(MapEntry('Low Stock Alert', '≤ ${p.lowStockThreshold} units'));
    }

    // 2. Dynamic Custom JSONB Attributes & Specifications
    if (p.attributes.isNotEmpty) {
      p.attributes.forEach((k, v) {
        final kLow = k.toLowerCase().trim();
        if (!CustomerPrivacyShield.blockedKeys.contains(kLow) &&
            kLow != 'brand' &&
            kLow != 'category_name' &&
            kLow != 'category' &&
            kLow != 'unit' &&
            kLow != 'size' &&
            kLow != 'sizes' &&
            kLow != 'color' &&
            kLow != 'colors' &&
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
                  context.isHindi ? 'उत्पाद विवरण एवं विशेषताएं' : 'Specifications & Details',
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
          const SizedBox(height: 14),

          // Structured Key-Value Rows with Guaranteed Zero Overflow
          Column(
            children: specItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isEven = idx % 2 == 0;
              final isAttachAction = item.key == 'Barcode' && item.value == '+ Attach Barcode';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isEven ? context.colorSurfaceSubtle.withValues(alpha: 0.5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        item.key,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.colorTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: isAttachAction
                          ? InkWell(
                              onTap: () => _attachBarcode(context, p),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                ],
                              ),
                            )
                          : Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.colorTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 8. DESCRIPTION & CATALOG NOTES
  // =========================================================================
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
                context.isHindi ? 'विवरण (About this item)' : 'About this item',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.description.trim(),
            style: TextStyle(
              fontSize: 13,
              color: context.colorTextPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 9. BARCODE HARDWARE & PRINTING STATION (Shop Owner Specific)
  // =========================================================================
  Widget _buildBarcodeHardwareCard(BuildContext context, ProductModel p) {
    final hasBarcode = p.barcode.trim().isNotEmpty;

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
                child: const Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.isHindi ? 'बारकोड एवं लेबल प्रिंट' : 'Barcode & Sticker Printing',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasBarcode) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        p.barcode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Print Actions Buttons
          Row(
            children: [
              // Single / Multi Barcode Sticker
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    context.isHindi ? 'स्टीकर प्रिंट' : 'Print Sticker',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => BarcodeStickerDialog.show(context, p),
                ),
              ),
              const SizedBox(width: 8),

              // A4 Barcode Sheet Studio
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: Text(
                    context.isHindi ? 'शीट स्टूडियो' : 'Sheet Studio',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => BarcodeSheetStudioScreen.show(context, initialProduct: p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 10. SIMILAR PRODUCTS HORIZONTAL ROW
  // =========================================================================
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: similarItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
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
                    width: 145,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.colorBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 129,
                          height: 105,
                          decoration: BoxDecoration(
                            color: context.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AppProductImage(
                            imageUrl: item.imageUrl,
                            width: 129,
                            height: 105,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.inventory_2_outlined,
                            fallbackIconSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CategoryRegistry.formatCategoryName(item.category),
                          style: TextStyle(
                            fontSize: 9.5,
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

  // =========================================================================
  // 11. STICKY BOTTOM QUICK ACTION BAR
  // =========================================================================
  Widget _buildBottomActionBar(BuildContext context, ProductModel p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        border: Border(top: BorderSide(color: context.colorBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Print Barcode Button (Height 48)
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colorBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.primary),
                label: Text(
                  context.isHindi ? 'बारकोड' : 'Barcode',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                onPressed: () => BarcodeStickerDialog.show(context, p),
              ),
            ),
            const SizedBox(width: 10),

            // Primary Update / Edit Details Button (Height 48)
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  label: Text(
                    context.isHindi ? 'विवरण बदलें (Edit)' : 'Edit Product Details',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    if (widget.onEditRequested != null) {
                      widget.onEditRequested!(context, p);
                    } else {
                      showAddProductDialog(context, initialProduct: p);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(context.isHindi ? 'उत्पाद हटाएं' : 'Delete Product'),
        content: Text(
          context.isHindi
              ? 'क्या आप निश्चित हैं कि आप इस उत्पाद को अपने कैटलॉग से हटाना चाहते हैं?'
              : 'Are you sure you want to delete this product from your catalog?',
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
              final success = await context.read<ProductController>().deleteProduct(productId);
              if (success && context.mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.isHindi ? 'उत्पाद कैटलॉग से हटा दिया गया' : 'Product deleted from catalog',
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
}
