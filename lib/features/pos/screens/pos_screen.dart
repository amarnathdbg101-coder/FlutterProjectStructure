import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../khata/models/khata_model.dart';
import '../../products/models/product_model.dart';
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _scanController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cashController = TextEditingController();

  List<ProductModel> _matchingSearchResults = [];
  bool _isSearchingLocal = false;

  KhataCustomerModel? _matchedKhataCustomer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().searchProducts('');
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _phoneController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String query, PosController pos) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _matchingSearchResults = [];
        _isSearchingLocal = false;
      });
      return;
    }

    final matches = pos.products.where((p) {
      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final sku = p.sku.toLowerCase();
      final category = p.category.toLowerCase();
      return name.contains(clean) || barcode.contains(clean) || sku.contains(clean) || category.contains(clean);
    }).take(6).toList();

    setState(() {
      _matchingSearchResults = matches;
      _isSearchingLocal = true;
    });
  }

  void _onCustomerPhoneChanged(String phone, PosController pos) {
    pos.setCustomerPhone(phone);
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.length >= 4) {
      final cachedKhata = LocalCacheService.getKhataCustomers();
      final match = cachedKhata.firstWhere(
        (c) => c.mobile.contains(cleanPhone) || c.name.toLowerCase().contains(phone.trim().toLowerCase()),
        orElse: () => KhataCustomerModel(id: '', name: '', mobile: '', balance: 0),
      );

      if (match.mobile.isNotEmpty) {
        setState(() {
          _matchedKhataCustomer = match;
        });
        pos.setCustomerName(match.name);
        return;
      }
    }

    setState(() {
      _matchedKhataCustomer = null;
    });
  }

  /// Adds item via Barcode, SKU, or Product Name from input box
  Future<void> _handleScanOrAdd(PosController pos) async {
    final query = _scanController.text.trim();
    if (query.isEmpty) return;

    final success = await pos.scanAndAddToCart(query);
    if (success) {
      _scanController.clear();
      setState(() {
        _matchingSearchResults = [];
        _isSearchingLocal = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added to active bill!'),
            duration: Duration(milliseconds: 800),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pos_product_not_found')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Opens Quick Add Custom Item Modal for loose charges or unlisted items
  void _showAddCustomItemDialog(BuildContext context) {
    final customNameCtrl = TextEditingController();
    final customPriceCtrl = TextEditingController();
    final customQtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Custom Loose Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Name / Description *',
                hintText: 'e.g. Loose Samosa, Packing Charge',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: customQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final name = customNameCtrl.text.trim();
              final price = double.tryParse(customPriceCtrl.text) ?? 0.0;
              final qty = int.tryParse(customQtyCtrl.text) ?? 1;

              if (price <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(ctx.tr('pos_val_price'))),
                );
                return;
              }

              context.read<PosController>().addCustomItem(
                name: name.isNotEmpty ? name : 'Custom Item',
                price: price,
                quantity: qty > 0 ? qty : 1,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  /// Opens Completed Bill Success Receipt Modal with WhatsApp Sharing
  void _showSuccessReceipt(BuildContext context, SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 54),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bill Generated Successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Bill #${sale.billNumber ?? "1001"}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ctx.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ctx.colorBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${sale.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Mode:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(sale.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (sale.customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Customer Mobile:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(sale.customerPhone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Share via WhatsApp Button
            if (sale.customerPhone.trim().length >= 10) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size(double.infinity, 44),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: const Text('Share Bill on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final phone = sale.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                  final msg = Uri.encodeComponent(
                    '🧾 *ShopSilo POS Receipt*\nBill #${sale.billNumber ?? "1001"}\nTotal: ₹${sale.totalAmount.toStringAsFixed(2)}\nPayment: ${sale.paymentMethod.toUpperCase()}\n\nThank you for shopping with us!',
                  );
                  final url = Uri.parse('https://wa.me/91$phone?text=$msg');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // Print Thermal Receipt PDF Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
              label: const Text('Print / Save Thermal Receipt PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final shop = context.read<AuthController>().currentShop;
                final shopName = shop?.name ?? 'ShopSilo Retail Store';
                context.read<PosController>().generateThermalReceiptPdf(context, sale, shopName);
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Start Next Bill', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final isWide = Responsive.isWide(context);
    final today24hRevenue = pos.today24hRevenue;

    return MerchantShell(
      currentIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: context.colorSurface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: context.colorBorder, height: 1.0),
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
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'POS Billing Counter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${pos.totalItemCount} Items',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                if (today24hRevenue > 0) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => context.go('/merchant/today-sales'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Today 24h: ₹${today24hRevenue.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.success),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (pos.cart.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
                label: const Text('Clear Bill', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onPressed: () {
                  pos.clearCart();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('POS Cart Cleared!'), duration: Duration(milliseconds: 800)),
                  );
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ResponsiveContainer(
            maxWidth: 1240,
            child: isWide ? _buildDesktopTerminal(context, pos) : _buildMobileTerminal(context, pos),
          ),
        ),
      ),
    );
  }

  /// Responsive Desktop 2-Column POS Billing Terminal Layout
  Widget _buildDesktopTerminal(BuildContext context, PosController pos) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Main Column: Fast Scan Bar & Active Bill Table
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFastScanBar(context, pos),
                const SizedBox(height: 12),
                Expanded(child: _buildActiveBillTable(context, pos)),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: context.colorBorder),

        // Right Column: Customer, Payment & Checkout Summary
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCheckoutPanel(context, pos),
          ),
        ),
      ],
    );
  }

  /// Responsive Mobile Single Column POS Billing Terminal Layout
  Widget _buildMobileTerminal(BuildContext context, PosController pos) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildFastScanBar(context, pos),
        ),
        Expanded(child: _buildActiveBillTable(context, pos)),
        _buildMobileBottomCheckoutBar(context, pos),
      ],
    );
  }

  /// Fast Scan & Search Bar with Auto-Add and Live Overlay Matches
  Widget _buildFastScanBar(BuildContext context, PosController pos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scanController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Scan Barcode, SKU or type item name...',
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                    suffixIcon: _scanController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _scanController.clear();
                              setState(() {
                                _matchingSearchResults = [];
                                _isSearchingLocal = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => _onSearchQueryChanged(val, pos),
                  onSubmitted: (_) => _handleScanOrAdd(pos),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(90, 48),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                onPressed: () => _handleScanOrAdd(pos),
              ),
            ],
          ),

          // LIVE AUTO-COMPLETE MATCHES OVERLAY
          if (_isSearchingLocal && _matchingSearchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _matchingSearchResults.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: context.colorBorder),
                itemBuilder: (ctx, idx) {
                  final p = _matchingSearchResults[idx];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colorSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colorBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppProductImage(
                        imageUrl: p.imageUrl,
                        width: 36,
                        height: 36,
                        expand: true,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                        fallbackIcon: Icons.inventory_2_outlined,
                        fallbackIconSize: 18,
                      ),
                    ),
                    title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: context.colorTextPrimary)),
                    subtitle: Text('${p.category} • ₹${p.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(60, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        pos.addToCart(p);
                        _scanController.clear();
                        setState(() {
                          _matchingSearchResults = [];
                          _isSearchingLocal = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${p.name} added to bill!'),
                            duration: const Duration(milliseconds: 800),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      child: const Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Quick Action Bar: Custom Item & Fast Shortcuts (Zero Overflow Scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                  label: const Text('+ Loose / Custom Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddCustomItemDialog(context),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.go('/merchant/today-sales'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.history_toggle_off_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Today 24h Sales Summary', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Active Bill Receipt Table with Proper Item Deletion & Steppers
  Widget _buildActiveBillTable(BuildContext context, PosController pos) {
    if (pos.cart.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.point_of_sale_rounded, size: 54, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'POS Billing Counter Ready',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan product barcode, SKU or type item name above to start billing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('+ Add Loose Charge'),
                    onPressed: () => _showAddCustomItemDialog(context),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history_toggle_off_rounded, size: 18),
                    label: Text(context.tr('today_sales_title')),
                    onPressed: () => context.go('/merchant/today-sales'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        children: [
          // Table Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: context.colorBorder)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('ITEM NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted))),
                Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted))),
                Expanded(flex: 3, child: Text('PRICE (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted))),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // Table Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: pos.cart.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.colorBorder),
              itemBuilder: (context, idx) {
                final item = pos.cart[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Item Name & Category
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.colorTextPrimary),
                            ),
                            Text(
                              '₹${item.customPrice.toStringAsFixed(0)} / ${item.product.unit}',
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                            ),
                          ],
                        ),
                      ),

                      // Quantity Stepper
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                final itemName = item.product.name;
                                pos.decrementQuantity(item);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Updated quantity for "$itemName"'),
                                    duration: const Duration(milliseconds: 600),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.colorSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: context.colorBorder),
                                ),
                                child: const Icon(Icons.remove_rounded, size: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                pos.incrementQuantity(item);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.colorPrimaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Item Total
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${item.total.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: context.colorTextPrimary),
                        ),
                      ),

                      // 🗑️ PROPER ITEM DELETION BUTTON WITH INSTANT FEEDBACK
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                        tooltip: 'Remove Item',
                        onPressed: () {
                          final removedName = item.product.name;
                          pos.removeFromCart(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item "$removedName" removed from bill'),
                              duration: const Duration(milliseconds: 800),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Full Checkout Summary Panel with Khata Auto-Link
  Widget _buildCheckoutPanel(BuildContext context, PosController pos) {
    _phoneController.text = pos.customerPhone;
    final shop = context.watch<AuthController>().currentShop;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CUSTOMER LINK & KHATA
          Text('CUSTOMER MOBILE (OPTIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Enter 10-digit customer mobile...',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
            ),
            onChanged: (val) => _onCustomerPhoneChanged(val, pos),
          ),

          // KHATA CUSTOMER LINKED BADGE
          if (_matchedKhataCustomer != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colorPrimaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Khata Linked: ${_matchedKhataCustomer!.name}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Udhar: ₹${_matchedKhataCustomer!.balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _matchedKhataCustomer!.hasPendingUdhar ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 2. PAYMENT METHOD SELECTOR
          Text('PAYMENT METHOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              _PaymentModeChip(
                label: '💵 Cash',
                selected: pos.paymentMethod == 'cash',
                onTap: () => pos.setPaymentMethod('cash'),
              ),
              const SizedBox(width: 8),
              _PaymentModeChip(
                label: '📱 UPI QR',
                selected: pos.paymentMethod == 'upi',
                onTap: () {
                  pos.setPaymentMethod('upi');
                  if (shop != null) {
                    showStoreQrDialog(context, shop);
                  }
                },
              ),
              const SizedBox(width: 8),
              _PaymentModeChip(
                label: '📖 Khata Udhar',
                selected: pos.paymentMethod == 'khata',
                onTap: () => pos.setPaymentMethod('khata'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cash Tendered & Change Due Calculator (Only for Cash Payment)
          if (pos.paymentMethod == 'cash' && pos.cart.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cash Received (Tendered):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      if (pos.changeDue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Change Due: ₹${pos.changeDue.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 500',
                      prefixText: '₹ ',
                    ),
                    onChanged: (val) {
                      final c = double.tryParse(val) ?? 0.0;
                      pos.setCashTendered(c);
                    },
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCashChip(context, 'Exact (₹${pos.grandTotal.toStringAsFixed(0)})', pos.grandTotal, pos),
                        _buildCashChip(context, '₹100', 100, pos),
                        _buildCashChip(context, '₹200', 200, pos),
                        _buildCashChip(context, '₹500', 500, pos),
                        _buildCashChip(context, '₹2000', 2000, pos),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. BILL BREAKDOWN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal (${pos.totalItemCount} items):', style: TextStyle(color: context.colorTextMuted)),
                    Text('₹${pos.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount:', style: TextStyle(color: context.colorTextMuted)),
                    Text('-₹${pos.discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(height: 16, color: context.colorBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(
                      '₹${pos.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (pos.hasError) ...[
            Text(pos.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
          ],

          // COMPLETE SALE BUTTON
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (pos.cart.isEmpty || pos.isLoading)
                ? null
                : () async {
                    final sale = await pos.completeSale();
                    if (sale != null && context.mounted) {
                      _cashController.clear();
                      _showSuccessReceipt(context, sale);
                    }
                  },
            child: pos.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('COMPLETE SALE (₹${pos.grandTotal.toStringAsFixed(2)})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCashChip(BuildContext context, String label, double amount, PosController pos) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          _cashController.text = amount.toStringAsFixed(0);
          pos.setCashTendered(amount);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.colorBorder),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextPrimary)),
        ),
      ),
    );
  }

  /// Mobile Bottom Checkout Bar
  Widget _buildMobileBottomCheckoutBar(BuildContext context, PosController pos) {
    if (pos.cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        border: Border(top: BorderSide(color: context.colorBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${pos.totalItemCount} Items in Bill', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
              Text('₹${pos.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(160, 46),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  decoration: BoxDecoration(
                    color: ctx.colorSurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    top: 20, left: 20, right: 20,
                  ),
                  child: _buildCheckoutPanel(ctx, pos),
                ),
              );
            },
            child: const Text('Checkout Bill', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PaymentModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.colorPrimaryLight : context.colorSurface,
            border: Border.all(
              color: selected ? AppColors.primary : context.colorBorder,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              color: selected ? AppColors.primary : context.colorTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
