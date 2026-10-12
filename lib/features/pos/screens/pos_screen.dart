import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/dynamic_upi_qr_dialog.dart';
import '../../../core/widgets/merchant_shell.dart';
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

class _PosScreenState extends State<PosScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _scanController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cashController = TextEditingController();

  List<ProductModel> _matchingSearchResults = [];
  bool _isSearchingLocal = false;
  String _selectedPosCategory = 'All';

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

  /// Opens Discount Dialog to apply a flat discount (₹)
  void _showDiscountDialog(BuildContext context, PosController pos) {
    final discountCtrl = TextEditingController(
      text: pos.discount > 0 ? pos.discount.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.discount_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Apply Bill Discount (₹)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: discountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount Amount (₹)',
                prefixText: '₹ ',
                hintText: 'e.g. 50',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickDiscountChip(ctx, discountCtrl, '₹10', 10),
                  _buildQuickDiscountChip(ctx, discountCtrl, '₹20', 20),
                  _buildQuickDiscountChip(ctx, discountCtrl, '₹50', 50),
                  _buildQuickDiscountChip(ctx, discountCtrl, '₹100', 100),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              pos.setDiscount(0);
              Navigator.pop(ctx);
            },
            child: const Text('Remove Discount', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final d = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              pos.setDiscount(d);
              Navigator.pop(ctx);
            },
            child: const Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDiscountChip(BuildContext context, TextEditingController ctrl, String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => ctrl.text = amount.toStringAsFixed(0),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: context.colorPrimaryLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
      ),
    );
  }

  /// Opens Held Bills Bottom Sheet to recall or discard parked counter bills
  void _showHeldBillsSheet(BuildContext context, PosController pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final bills = pos.heldBills;
          return Container(
            decoration: BoxDecoration(
              color: sheetCtx.colorSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
              maxWidth: 580,
            ),
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
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pause_circle_filled_rounded, color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sheetCtx.isHindi ? 'पार्क किए गए बिल' : 'Parked / Held Bills',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: sheetCtx.colorTextPrimary,
                            ),
                          ),
                          Text(
                            sheetCtx.isHindi ? 'बिल दोबारा शुरू करने के लिए चुनें' : 'Select a bill to resume billing at counter',
                            style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (bills.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        sheetCtx.isHindi ? 'कोई पार्क किया गया बिल नहीं है' : 'No held bills at the moment',
                        style: TextStyle(color: sheetCtx.colorTextMuted),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: bills.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final b = bills[idx];
                        final diffMinutes = DateTime.now().difference(b.heldAt).inMinutes;
                        final timeAgo = diffMinutes < 1 ? 'Just now' : '${diffMinutes}m ago';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: sheetCtx.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: sheetCtx.colorBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '₹${b.grandTotal.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: sheetCtx.colorTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${b.totalItemCount} Items',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          timeAgo,
                                          style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      b.customerName.isNotEmpty
                                          ? '${b.customerName} (${b.customerPhone})'
                                          : (b.customerPhone.isNotEmpty ? b.customerPhone : (sheetCtx.isHindi ? 'ग्राहक' : 'Walk-in Customer')),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sheetCtx.colorTextSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      b.items.map((i) => '${i.quantity}x ${i.product.name}').join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                tooltip: 'Discard Held Bill',
                                onPressed: () {
                                  pos.deleteHeldBill(b);
                                  if (pos.heldBills.isEmpty) {
                                    Navigator.pop(sheetCtx);
                                  } else {
                                    setSheetState(() {});
                                  }
                                },
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: const Size(60, 36),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  pos.recallHeldBill(b);
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.isHindi ? '✓ बिल वापस रीस्टोर कर दिया गया' : '✓ Bill restored to active cart'),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                },
                                child: Text(sheetCtx.isHindi ? 'बिल करें' : 'Resume', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        },
      ),
    );
  }

  Widget _buildPosCategoryPill(BuildContext context, String catName, PosController pos) {
    final isSel = _selectedPosCategory.toLowerCase() == catName.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPosCategory = catName;
            if (catName == 'All') {
              _matchingSearchResults = [];
              _isSearchingLocal = false;
            } else {
              _matchingSearchResults = pos.products
                  .where((p) => p.category.toLowerCase().contains(catName.toLowerCase()))
                  .take(8)
                  .toList();
              _isSearchingLocal = true;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSel ? context.colorPrimaryLight : context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? AppColors.primary : context.colorBorder,
            ),
          ),
          child: Text(
            catName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
              color: isSel ? AppColors.primary : context.colorTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Formats an executive, clean itemized receipt text for WhatsApp & Clipboard
  String _formatBillReceiptText(BuildContext context, SaleModel sale) {
    final shop = context.read<AuthController>().currentShop;
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Retail Store';
    final shopAddress = shop?.address.isNotEmpty == true ? shop!.address : '';
    final shopPhone = shop?.phone.isNotEmpty == true ? shop!.phone : '';
    final isHindi = context.isHindi;

    final buffer = StringBuffer();
    buffer.writeln('🧾 *${shopName.toUpperCase()}*');
    if (shopAddress.isNotEmpty) {
      buffer.writeln('📍 $shopAddress');
    }
    if (shopPhone.isNotEmpty) {
      buffer.writeln('📞 Ph: $shopPhone');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('${isHindi ? "बिल संख्या" : "Bill No"}: #${sale.billNumber ?? "1001"}');
    buffer.writeln('${isHindi ? "दिनांक" : "Date"}: ${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year}');
    if (sale.customerPhone.isNotEmpty) {
      buffer.writeln('${isHindi ? "ग्राहक" : "Customer"}: ${sale.customerPhone}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(isHindi ? '*सामान की सूची:*' : '*ITEMS PURCHASED:*');

    for (int i = 0; i < sale.items.length; i++) {
      final item = sale.items[i];
      final itemName = item.product.name.trim();
      final qty = item.quantity;
      final unitPrice = item.customPrice.toStringAsFixed(0);
      final total = item.total.toStringAsFixed(0);
      buffer.writeln('${i + 1}. $itemName\n    $qty x ₹$unitPrice = *₹$total*');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('${isHindi ? "उप-योग" : "Subtotal"}: ₹${sale.subtotal.toStringAsFixed(2)}');
    if (sale.discountAmount > 0) {
      buffer.writeln('${isHindi ? "छूट" : "Discount"}: -₹${sale.discountAmount.toStringAsFixed(2)}');
    }
    buffer.writeln('*${isHindi ? "कुल राशि (TOTAL)" : "GRAND TOTAL"}: ₹${sale.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('${isHindi ? "भुगतान माध्यम" : "Payment Mode"}: ${sale.paymentMethod.toUpperCase()}');
    buffer.writeln('--------------------------------');
    buffer.writeln(isHindi
        ? '🙏 हमारे यहाँ पधारने के लिए धन्यवाद!\nफिर मिलेंगे!'
        : '🙏 Thank you for shopping with us!\nVisit again!');

    return buffer.toString();
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

            // 1. Share via WhatsApp Button (with formatted rich itemized receipt)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: const Text('Share Bill on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final receiptText = _formatBillReceiptText(ctx, sale);
                final cleanPhone = sale.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
                final encodedMsg = Uri.encodeComponent(receiptText);

                final Uri url;
                if (formattedPhone.isNotEmpty && formattedPhone.length >= 10) {
                  url = Uri.parse('https://wa.me/$formattedPhone?text=$encodedMsg');
                } else {
                  url = Uri.parse('https://wa.me/?text=$encodedMsg');
                }

                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(ctx.tr('khata_whatsapp_not_installed'))),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),

            // 2. 1-Tap Copy Bill Receipt to Clipboard
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
              ),
              icon: const Icon(Icons.copy_rounded, size: 17, color: AppColors.primary),
              label: Text(ctx.tr('pos_btn_copy_bill'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final receiptText = _formatBillReceiptText(ctx, sale);
                Clipboard.setData(ClipboardData(text: receiptText));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(ctx.tr('pos_bill_copied')),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // 3. Print Thermal Receipt PDF Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 17, color: AppColors.primary),
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
    super.build(context);
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
            if (pos.heldBills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: InkWell(
                  onTap: () => _showHeldBillsSheet(context, pos),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause_circle_filled_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Held (${pos.heldBills.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (pos.cart.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning, size: 20),
                tooltip: 'Hold / Park Active Bill',
                onPressed: () {
                  final ok = pos.holdCurrentBill();
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.isHindi ? '✓ बिल पार्क कर दिया गया (Hold)' : '✓ Active bill parked on hold'),
                        backgroundColor: AppColors.warning,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
              tooltip: 'Refresh Billing Catalog',
              onPressed: () async {
                await context.read<PosController>().loadCatalog();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ POS Billing Catalog Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                  );
                }
              },
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppProductSearchBar(
          controller: _scanController,
          autoFocus: true,
          hintText: 'Scan Barcode, SKU or type item name...',
          showBarcodeScanner: true,
          onBarcodeScan: () => _handleScanOrAdd(pos),
          onChanged: (val) => _onSearchQueryChanged(val, pos),
          onClear: () {
            setState(() {
              _matchingSearchResults = [];
              _isSearchingLocal = false;
            });
          },
        ),

        // 1-Tap Quick Category Shortcuts Bar
        if (pos.products.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPosCategoryPill(context, 'All', pos),
                _buildPosCategoryPill(context, 'Grocery', pos),
                _buildPosCategoryPill(context, 'Dairy', pos),
                _buildPosCategoryPill(context, 'Snacks', pos),
                _buildPosCategoryPill(context, 'Beverages', pos),
                _buildPosCategoryPill(context, 'Personal Care', pos),
                _buildPosCategoryPill(context, 'Household', pos),
              ],
            ),
          ),
        ],

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
                      // Item Image Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppProductImage(
                          imageUrl: item.product.imageUrl,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Item Name & Unit Price
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
                            const SizedBox(height: 2),
                            Text(
                              '₹${item.customPrice.toStringAsFixed(0)} / ${item.product.unit}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextMuted),
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
                  showDynamicUpiQrDialog(context, amount: pos.grandTotal);
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
          if (pos.paymentMethod == 'upi' && pos.cart.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => showDynamicUpiQrDialog(context, amount: pos.grandTotal),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('pos_show_upi_qr'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            context.tr('pos_upi_qr_subtitle'),
                            style: TextStyle(fontSize: 10, color: context.colorTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${pos.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Discount:', style: TextStyle(color: context.colorTextMuted)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showDiscountDialog(context, pos),
                          child: const Text('✏️ Edit Discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    Text('-₹${pos.discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(height: 18, color: context.colorBorder),
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

          // COMPLETE SALE & PRINT BILL BUTTON
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            icon: pos.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
            label: Text(
              pos.isLoading ? 'Processing Sale...' : '⚡ Complete Sale & Print Bill (₹${pos.grandTotal.toStringAsFixed(0)})',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            onPressed: (pos.cart.isEmpty || pos.isLoading)
                ? null
                : () async {
                    final sale = await pos.completeSale();
                    if (sale != null && context.mounted) {
                      _cashController.clear();
                      _showSuccessReceipt(context, sale);
                    } else if (context.mounted && pos.hasError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(pos.errorMessage ?? 'Sale generation failed'),
                          backgroundColor: AppColors.error,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
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
