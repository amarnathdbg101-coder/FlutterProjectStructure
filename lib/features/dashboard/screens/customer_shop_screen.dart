import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../products/models/product_model.dart';
import '../models/shop_model.dart';

class CustomerShopScreen extends StatefulWidget {
  final String slug;

  const CustomerShopScreen({super.key, required this.slug});

  @override
  State<CustomerShopScreen> createState() => _CustomerShopScreenState();
}

class _CustomerShopScreenState extends State<CustomerShopScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  String? _errorMessage;
  ShopModel? _shop;
  List<ProductModel> _products = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchShopAndProducts();
  }

  Future<void> _fetchShopAndProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch public shop by slug
      final shopRes = await _dio.get('/shops/slug/${widget.slug}');
      final rawShop = shopRes.data;
      Map<String, dynamic> shopData;
      if (rawShop is Map<String, dynamic>) {
        shopData = rawShop['shop'] ?? rawShop['data'] ?? rawShop;
      } else {
        shopData = {};
      }
      _shop = ShopModel.fromJson(shopData);

      // 2. Fetch public products for this shop
      try {
        final prodRes = await _dio.get('/shops/${widget.slug}/products');
        final rawProd = prodRes.data;
        List<dynamic> list = [];
        if (rawProd is Map<String, dynamic>) {
          final data = rawProd['data'] ?? rawProd['products'] ?? rawProd;
          if (data is Map<String, dynamic>) {
            list = data['products'] ?? [];
          } else if (data is List) {
            list = data;
          }
        } else if (rawProd is List) {
          list = rawProd;
        }
        _products = list.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _products = [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Store not found or currently unavailable.';
      });
    }
  }

  Future<void> _openWhatsApp({String? itemText}) async {
    if (_shop == null) return;
    final phone = _shop!.whatsappNumber.isNotEmpty ? _shop!.whatsappNumber : _shop!.phone;
    if (phone.isEmpty) return;

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final message = itemText != null
        ? 'Hello ${_shop!.name}, I want to order: $itemText from your ShopSilo online store.'
        : 'Hello ${_shop!.name}, I want to place an order from your ShopSilo online store.';

    final uri = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callStore() async {
    if (_shop == null || _shop!.phone.isEmpty) return;
    final uri = Uri.parse('tel:${_shop!.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showUpiDialog() {
    if (_shop == null) return;
    final upiId = _shop!.upiId;
    if (upiId == null || upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID not configured for this store yet.')),
      );
      return;
    }

    final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(_shop!.name)}&cu=INR';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ctx.tr('storefront_pay_upi'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: upiUri,
                  version: QrVersions.auto,
                  size: 180,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'UPI ID: $upiId',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              const Text('Scan with PhonePe, Google Pay, or Paytm', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy UPI ID'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: upiId));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('UPI ID copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colorBg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading store...', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _shop == null) {
      return Scaffold(
        backgroundColor: context.colorBg,
        appBar: AppBar(
          title: const Text('Storefront'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_rounded, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'Store not found', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _fetchShopAndProducts,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final shop = _shop!;
    final categories = ['All', ...{..._products.map((p) => p.category).where((c) => c.isNotEmpty)}];
    final filteredProducts = _products.where((p) {
      final matchesQuery = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: context.colorBg,
      appBar: AppBar(
        title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        elevation: 0,
        backgroundColor: context.colorSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: 'Share Store',
            onPressed: () {
              final storeUrl = 'https://shopsilo.in/shop/${shop.slug}';
              Clipboard.setData(ClipboardData(text: storeUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Store link copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. STORE HEADER CARD
              Container(
                color: context.colorSurface,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.colorPrimaryLight,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      shop.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppBadge(label: shop.category, type: AppBadgeType.primary),
                        AppBadge(
                          label: shop.isOpen ? context.tr('profile_status_open') : context.tr('profile_status_closed'),
                          type: shop.isOpen ? AppBadgeType.success : AppBadgeType.warning,
                        ),
                        if (shop.rating > 0)
                          AppBadge(label: '★ ${shop.rating.toStringAsFixed(1)}', type: AppBadgeType.neutral),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (shop.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          shop.description,
                          style: TextStyle(fontSize: 13, color: context.colorTextSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            shop.fullAddress,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          shop.formattedTimings,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer Action Buttons: WhatsApp & Call & UPI
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: Text(context.tr('storefront_order_whatsapp'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => _openWhatsApp(),
                          ),
                        ),
                        if (shop.phone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                            tooltip: context.tr('storefront_call_store'),
                            onPressed: _callStore,
                          ),
                        ],
                        if (shop.upiId?.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                            tooltip: context.tr('storefront_pay_upi'),
                            onPressed: _showUpiDialog,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. PRODUCT CATALOG SEARCH & FILTERS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products in ${shop.name}...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.colorBorder),
                        ),
                        filled: true,
                        fillColor: context.colorSurface,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    if (categories.length > 2) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final isSel = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedCategory = cat);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. PRODUCTS LIST / EMPTY STATE
              if (filteredProducts.isEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: context.colorSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('storefront_direct_order_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('storefront_direct_order_sub'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: Text(context.tr('storefront_send_list_wa')),
                        onPressed: () => _openWhatsApp(),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final prod = filteredProducts[i];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: context.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colorBorder),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AppProductImage(
                              imageUrl: prod.imageUrl,
                              width: 50,
                              height: 50,
                              expand: true,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(10),
                              fallbackIcon: Icons.shopping_bag_outlined,
                              fallbackIconSize: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '₹${prod.price.toStringAsFixed(prod.price.truncateToDouble() == prod.price ? 0 : 2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary),
                                    ),
                                    Text(
                                      ' / ${prod.unit}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: Text(context.tr('storefront_order_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _openWhatsApp(itemText: '${prod.name} (₹${prod.price}/${prod.unit})'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 36),

              // Footer
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('storefront_powered_by'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
