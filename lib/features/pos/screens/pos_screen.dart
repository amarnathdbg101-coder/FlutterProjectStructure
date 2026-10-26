import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/services/floor_token_cards_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/search_fuzzy_utils.dart';
import '../../../core/widgets/app_highlighted_text.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/dynamic_upi_qr_dialog.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../../../core/widgets/price_checker_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../khata/models/khata_model.dart';
import '../../products/controllers/category_controller.dart';
import '../../products/models/product_model.dart';
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';
import '../widgets/day_close_reconciliation_sheet.dart';
import '../widgets/smart_sauda_modal.dart';

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
  Timer? _posSearchDebounceTimer;

  final FocusNode _searchFocusNode = FocusNode();
  int _highlightedMatchIndex = -1;
  ProductModel? _didYouMeanSuggestion;

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
    _posSearchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _scanController.dispose();
    _phoneController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String query, PosController pos) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      _posSearchDebounceTimer?.cancel();
      setState(() {
        _matchingSearchResults = [];
        _isSearchingLocal = false;
        _highlightedMatchIndex = -1;
        _didYouMeanSuggestion = null;
      });
      return;
    }

    // 1. Immediate in-memory match (0ms)
    final matches = pos.products.where((p) {
      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      final sku = p.sku.toLowerCase();
      final category = p.category.toLowerCase();
      return name.contains(clean) || barcode.contains(clean) || sku.contains(clean) || category.contains(clean);
    }).take(6).toList();

    // Check for "Did you mean" typo suggestion if immediate matches are empty
    ProductModel? fuzzy;
    if (matches.isEmpty && clean.length >= 3) {
      fuzzy = SearchFuzzyUtils.findClosestFuzzySuggestion(clean, pos.products);
    }

    setState(() {
      _matchingSearchResults = matches;
      _isSearchingLocal = true;
      _highlightedMatchIndex = matches.isNotEmpty ? 0 : -1;
      _didYouMeanSuggestion = fuzzy;
    });

    // 2. Debounced server database query (300ms) to search full database beyond initial batch
    _posSearchDebounceTimer?.cancel();
    if (clean.length >= 2) {
      _posSearchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted || _scanController.text.trim().toLowerCase() != clean) return;
        await pos.searchProducts(clean);
        if (mounted && _scanController.text.trim().toLowerCase() == clean) {
          // Products returned from server are already matched & ranked by PostgreSQL's trigram fuzzy search
          final serverResults = pos.products.take(8).toList();
          ProductModel? serverFuzzy;
          if (serverResults.isEmpty && clean.length >= 3) {
            serverFuzzy = SearchFuzzyUtils.findClosestFuzzySuggestion(clean, pos.products);
          }
          setState(() {
            _matchingSearchResults = serverResults;
            _didYouMeanSuggestion = serverFuzzy;
            if (_highlightedMatchIndex >= serverResults.length) {
              _highlightedMatchIndex = serverResults.isNotEmpty ? 0 : -1;
            }
          });
        }
      });
    }
  }

  void _handleSearchSubmit(PosController pos) {
    if (_matchingSearchResults.isNotEmpty) {
      final targetIdx = (_highlightedMatchIndex >= 0 && _highlightedMatchIndex < _matchingSearchResults.length)
          ? _highlightedMatchIndex
          : 0;
      final selected = _matchingSearchResults[targetIdx];
      pos.addToCart(selected);
      _scanController.clear();
      setState(() {
        _matchingSearchResults = [];
        _isSearchingLocal = false;
        _highlightedMatchIndex = -1;
        _didYouMeanSuggestion = null;
      });
      _searchFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.isHindi ? '${selected.name} बिल में जोड़ दिया गया!' : '${selected.name} added to bill!'),
          duration: const Duration(milliseconds: 700),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (_didYouMeanSuggestion != null) {
      final selected = _didYouMeanSuggestion!;
      pos.addToCart(selected);
      _scanController.clear();
      setState(() {
        _matchingSearchResults = [];
        _isSearchingLocal = false;
        _highlightedMatchIndex = -1;
        _didYouMeanSuggestion = null;
      });
      _searchFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.isHindi ? '${selected.name} बिल में जोड़ दिया गया!' : '${selected.name} added to bill!'),
          duration: const Duration(milliseconds: 700),
          backgroundColor: AppColors.success,
        ),
      );
    }
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



  /// Opens Live Camera Barcode Scanner Viewfinder with continuous scanning
  void _openCameraScanner(BuildContext context, PosController pos) {
    MobileBarcodeScannerDialog.show(
      context,
      initialToken: pos.currentActiveToken,
      onBarcodeScanned: (barcode) async {
        final success = await pos.scanAndAddToCart(barcode);
        return success;
      },
      onRegisterNewProduct: (barcode, name, price, mrp) async {
        final success = await pos.quickRegisterBarcodeAndAddToCart(
          barcode: barcode,
          name: name,
          price: price,
          mrp: mrp,
        );
        return success;
      },
    );
  }

  /// Opens Quick Add Custom Item Modal for loose charges or unlisted items
  void _showAddCustomItemDialog(BuildContext context, {String? initialName}) {
    final customNameCtrl = TextEditingController(text: initialName ?? '');
    final customPriceCtrl = TextEditingController();
    final customQtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              ctx.isHindi ? 'अतिरिक्त वस्तु जोड़ें' : 'Add Custom Loose Item',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customNameCtrl,
              decoration: InputDecoration(
                labelText: ctx.isHindi ? 'वस्तु का नाम / विवरण *' : 'Item Name / Description *',
                hintText: ctx.isHindi ? 'उदा. समोसा, पैकिंग शुल्क' : 'e.g. Loose Samosa, Packing Charge',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: ctx.isHindi ? 'मूल्य (₹) *' : 'Price (₹) *',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: customQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: ctx.isHindi ? 'मात्रा' : 'Quantity',
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
            child: Text(ctx.isHindi ? 'रद्द करें' : 'Cancel'),
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
                name: name.isNotEmpty ? name : (ctx.isHindi ? 'अतिरिक्त वस्तु' : 'Custom Item'),
                price: price,
                quantity: qty > 0 ? qty : 1,
              );
              Navigator.pop(ctx);
            },
            child: Text(ctx.isHindi ? 'बिल में जोड़ें' : 'Add to Bill'),
          ),
        ],
      ),
    );
  }

  /// Smart Parchi Auto-Cart Dialog (Parse multiline WhatsApp or grocery list)
  void _showParchiParserDialog(BuildContext context, PosController pos) {
    final parchiCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sheetCtx.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheetCtx.isHindi ? 'स्मार्ट पर्ची बिलिंग' : 'Smart Parchi Auto-Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sheetCtx.colorTextPrimary,
                          ),
                        ),
                        Text(
                          sheetCtx.isHindi ? 'व्हाट्सएप या ग्राहक की पर्ची का टेक्स्ट पेस्ट करें' : 'Paste customer grocery list or WhatsApp message',
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
              TextField(
                controller: parchiCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: sheetCtx.isHindi
                      ? 'उदा:\n2 kg आटा\n1 L तेल\n1 पैकेट नमक'
                      : 'e.g.:\n2 kg Atta\n1 L Oil\n1 pkt Salt',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                label: Text(
                  sheetCtx.isHindi ? 'पर्ची से सामान बिल में जोड़ें' : 'Parse List to Cart',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                onPressed: () {
                  final text = parchiCtrl.text.trim();
                  if (text.isEmpty) return;

                  final lines = text.split(RegExp(r'[\r\n]+'));
                  int addedCount = 0;

                  for (final line in lines) {
                    final clean = line.trim();
                    if (clean.isEmpty) continue;

                    // Match item in catalog
                    final match = pos.products.firstWhere(
                      (p) => p.name.toLowerCase().contains(clean.toLowerCase()) ||
                          clean.toLowerCase().contains(p.name.toLowerCase()),
                      orElse: () => ProductModel(id: '', name: '', price: 0, stock: 0, category: ''),
                    );

                    if (match.id.isNotEmpty) {
                      pos.addToCart(match);
                      addedCount++;
                    } else {
                      pos.addCustomItem(name: clean, price: 10, quantity: 1);
                      addedCount++;
                    }
                  }

                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sheetCtx.isHindi ? '$addedCount वस्तुएं बिल में जोड़ी गईं!' : '$addedCount items added to POS cart!'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
          children: [
            const Icon(Icons.discount_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              ctx.isHindi ? 'बिल पर छूट लगाएं (₹)' : 'Apply Bill Discount (₹)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
              decoration: InputDecoration(
                labelText: ctx.isHindi ? 'छूट की राशि (₹)' : 'Discount Amount (₹)',
                prefixText: '₹ ',
                hintText: ctx.isHindi ? 'उदा. 50' : 'e.g. 50',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
            child: Text(ctx.isHindi ? 'छूट हटाएं' : 'Remove Discount', style: const TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final d = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              pos.setDiscount(d);
              Navigator.pop(ctx);
            },
            child: Text(ctx.isHindi ? 'छूट लागू करें' : 'Apply Discount'),
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
                        final timeAgo = diffMinutes < 1
                            ? (sheetCtx.isHindi ? 'अभी-अभी' : 'Just now')
                            : '$diffMinutes${sheetCtx.isHindi ? "मि पूर्व" : "m ago"}';

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
                                            '${b.totalItemCount} ${sheetCtx.isHindi ? "वस्तुएं" : "Items"}',
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
                                tooltip: sheetCtx.isHindi ? 'पार्क बिल हटाएं' : 'Discard Held Bill',
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
    final displayTitle = catName == 'All' ? (context.isHindi ? 'सभी' : 'All') : catName;
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
                  .where((p) => p.category.toLowerCase().trim() == catName.toLowerCase().trim())
                  .take(12)
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
            displayTitle,
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
    final payModeDisplay = sale.paymentMethod == 'split'
        ? (isHindi
            ? 'स्प्लिट (नकद ₹${sale.splitPayments?.cashAmount.toStringAsFixed(0) ?? "0"} + UPI ₹${sale.splitPayments?.onlineAmount.toStringAsFixed(0) ?? "0"})'
            : 'SPLIT (Cash ₹${sale.splitPayments?.cashAmount.toStringAsFixed(0) ?? "0"} + UPI ₹${sale.splitPayments?.onlineAmount.toStringAsFixed(0) ?? "0"})')
        : sale.paymentMethod.toUpperCase();
    buffer.writeln('${isHindi ? "भुगतान माध्यम" : "Payment Mode"}: $payModeDisplay');
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
            Text(
              ctx.isHindi ? 'बिल सफलतापूर्वक बन गया!' : 'Bill Generated Successfully!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${ctx.isHindi ? "बिल संख्या" : "Bill"} #${sale.billNumber ?? "1001"}',
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
                      Text(ctx.isHindi ? 'कुल राशि:' : 'Total Amount:', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                      Text(ctx.isHindi ? 'भुगतान माध्यम:' : 'Payment Mode:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        sale.paymentMethod == 'split'
                            ? (ctx.isHindi
                                ? 'स्प्लिट (नकद ₹${sale.splitPayments?.cashAmount.toStringAsFixed(0) ?? "0"} + UPI ₹${sale.splitPayments?.onlineAmount.toStringAsFixed(0) ?? "0"})'
                                : 'SPLIT (Cash ₹${sale.splitPayments?.cashAmount.toStringAsFixed(0) ?? "0"} + UPI ₹${sale.splitPayments?.onlineAmount.toStringAsFixed(0) ?? "0"})')
                            : sale.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (sale.customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ctx.isHindi ? 'ग्राहक मोबाइल:' : 'Customer Mobile:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              label: Text(ctx.isHindi ? 'व्हाट्सएप पर बिल भेजें' : 'Share Bill on WhatsApp', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // 3. Print Thermal Receipt Button (58mm / 80mm ESC-POS)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
              ),
              icon: const Icon(Icons.print_rounded, size: 17, color: AppColors.primary),
              label: Text(ctx.isHindi ? 'थर्मल रसीद प्रिंट करें (58mm/80mm)' : 'Print Thermal Slip (58mm/80mm)', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final shop = context.read<AuthController>().currentShop;
                final shopName = shop?.name ?? 'ShopSilo Retail Store';
                context.read<PosController>().generateThermalReceiptPdf(
                  context,
                  sale,
                  shopName,
                  shopAddress: shop?.address ?? '',
                  shopPhone: shop?.phone ?? '',
                  shopGstin: shop?.gstin ?? '',
                  upiId: shop?.upiId ?? '',
                );
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
            child: Text(ctx.isHindi ? 'अगला बिल शुरू करें' : 'Start Next Bill', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pos = context.watch<PosController>();
    context.watch<LanguageController>();
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
            tooltip: context.isHindi ? 'वापस' : 'Back',
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
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Text(
                  context.isHindi ? 'पीओएस बिलिंग काउंटर' : 'POS Billing Counter',
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
                    '${pos.totalItemCount} ${context.isHindi ? "सामान" : "Items"}',
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
                            '${context.isHindi ? "24h बिक्री" : "Today 24h"}: ₹${today24hRevenue.toStringAsFixed(0)}',
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
                          '${context.isHindi ? "पार्क" : "Held"} (${pos.heldBills.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Primary 1-Tap Action: Camera Barcode Scanner
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: AppColors.primary),
              tooltip: context.isHindi ? 'कैमरा बारकोड स्कैनर' : 'Camera Barcode Scanner',
              onPressed: () => _openCameraScanner(context, pos),
            ),
            // Clean 3-Dot Overflow Menu for Secondary & Management Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
              tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              onSelected: (val) async {
                switch (val) {
                  case 'hold':
                    final ok = pos.holdCurrentBill();
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.isHindi ? '✓ बिल पार्क कर दिया गया' : '✓ Active bill parked on hold'),
                          backgroundColor: AppColors.warning,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    break;
                  case 'parchi':
                    _showParchiParserDialog(context, pos);
                    break;
                  case 'day_close':
                    DayCloseReconciliationSheet.show(context);
                    break;
                  case 'refresh':
                    await context.read<PosController>().loadCatalog();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.isHindi ? '✓ पीओएस कैटलॉग रीफ्रेश हुआ' : '✓ POS Billing Catalog Refreshed'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                    break;
                  case 'clear':
                    pos.clearCart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.isHindi ? 'बिल साफ़ कर दिया गया' : 'POS Cart Cleared!'),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (pos.cart.isNotEmpty)
                  PopupMenuItem(
                    value: 'hold',
                    child: Row(
                      children: [
                        const Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Text(ctx.isHindi ? 'चालू बिल पार्क करें (Hold)' : 'Hold / Park Active Bill'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'parchi',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'स्मार्ट पर्ची / लिस्ट से बिल' : 'Smart Parchi Auto-Cart'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'day_close',
                  child: Row(
                    children: [
                      const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'दुकान बंद / गल्ला मिलान' : 'Day Close & Reconciliation'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: ctx.colorTextPrimary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'कैटलॉग रीफ्रेश करें' : 'Refresh Catalog'),
                    ],
                  ),
                ),
                if (pos.cart.isNotEmpty) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          ctx.isHindi ? 'बिल साफ़ करें' : 'Clear Active Bill',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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

  /// Real-Time Multi-Basket Floor Selling Running Tabs Bar
  Widget _buildActiveTokensBar(BuildContext context, PosController pos) {
    final activeBaskets = pos.activeBaskets;
    final currentToken = pos.currentActiveToken;

    // Collect all unique tokens to display horizontally:
    // 1. Current token
    // 2. Any tokens currently running on server / other family members' devices
    // 3. Quick slots T-01 through T-06
    final Set<String> tokenSet = {};
    tokenSet.add(currentToken);
    for (final b in activeBaskets) {
      if (b.label.trim().isNotEmpty) {
        tokenSet.add(b.label.trim().toUpperCase());
      }
    }
    for (int i = 1; i <= 6; i++) {
      tokenSet.add('T-${i.toString().padLeft(2, '0')}');
    }

    final tokens = tokenSet.toList();
    tokens.sort((a, b) {
      if (a == currentToken) return -1;
      if (b == currentToken) return 1;
      final aRunning = activeBaskets.any((x) => x.label.toUpperCase() == a && x.items.isNotEmpty);
      final bRunning = activeBaskets.any((x) => x.label.toUpperCase() == b && x.items.isNotEmpty);
      if (aRunning && !bRunning) return -1;
      if (!aRunning && bRunning) return 1;
      return a.compareTo(b);
    });

    final isHindi = context.isHindi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorSurface,
        border: Border(
          bottom: BorderSide(color: context.colorBorder.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isHindi ? 'लाइव फ्लोर बास्केट्स' : 'Live Floor Baskets',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (activeBaskets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${activeBaskets.length} ${isHindi ? "सक्रिय" : "Active"}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // + New Token button
                InkWell(
                  onTap: () => _showTokenPickerSheet(context, pos),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: context.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          isHindi ? 'नया टोकन' : '+ Token',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Horizontal scroll of tokens
                ...tokens.map((tok) {
                  final isSelected = tok == currentToken;
                  final runningBasket = activeBaskets.firstWhere(
                    (b) => b.label.toUpperCase() == tok,
                    orElse: () => PosParkedBill(id: '', label: '', items: [], totalAmount: 0),
                  );
                  final hasItems = isSelected ? pos.cart.isNotEmpty : runningBasket.items.isNotEmpty;
                  final itemCount = isSelected ? pos.totalItemCount : runningBasket.totalItemCount;
                  final totalAmt = isSelected ? pos.grandTotal : runningBasket.totalAmount;
                  final elapsedMinutes = (hasItems && runningBasket.id.isNotEmpty)
                      ? DateTime.now().difference(runningBasket.updatedAt).inMinutes
                      : 0;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => pos.switchToken(tok),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (hasItems ? AppColors.warning.withValues(alpha: 0.12) : context.colorSurfaceSubtle),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (hasItems ? AppColors.warning.withValues(alpha: 0.5) : context.colorBorder),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tok,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (hasItems ? context.colorTextPrimary : context.colorTextMuted),
                              ),
                            ),
                            if (hasItems) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : AppColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '$itemCount • ₹${totalAmt.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.warning,
                                  ),
                                ),
                              ),
                              if (elapsedMinutes >= 15) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : (elapsedMinutes >= 30
                                            ? AppColors.error.withValues(alpha: 0.2)
                                            : AppColors.warning.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${elapsedMinutes >= 30 ? "🚨" : "⏱️"}${elapsedMinutes}m',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : (elapsedMinutes >= 30 ? AppColors.error : AppColors.warning),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens interactive Running Token Picker modal with 20 quick tokens & custom names
  void _showTokenPickerSheet(BuildContext context, PosController pos) {
    final customCtrl = TextEditingController();
    final isHindi = context.isHindi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final activeBaskets = pos.activeBaskets;

          return Container(
            decoration: BoxDecoration(
              color: ctx.colorSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 16,
              left: 20,
              right: 20,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              maxWidth: 580,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ctx.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'ग्राहक बिलिंग टोकन चुनें' : 'Select Customer Basket Token',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ctx.colorTextPrimary,
                              ),
                            ),
                            Text(
                              isHindi
                                  ? 'दुकान में घूमते ग्राहक को टोकन दें और सामान स्कैन करते रहें'
                                  : 'Assign a floor token while scanning items for parallel customers',
                              style: TextStyle(fontSize: 11, color: ctx.colorTextMuted),
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
                  const SizedBox(height: 16),

                  // Custom Name / Token Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: isHindi ? 'कस्टम टोकन या ग्राहक का नाम' : 'Custom Token or Customer Name',
                            hintText: isHindi ? 'उदा. T-25, रमेश' : 'e.g. T-25, Ramesh',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final val = customCtrl.text.trim();
                          if (val.isNotEmpty) {
                            pos.switchToken(val);
                            Navigator.pop(sheetCtx);
                          }
                        },
                        child: Text(isHindi ? 'शुरू करें' : 'Switch'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    isHindi ? 'त्वरित टोकन स्लॉट (T-01 से T-20):' : 'Quick Token Slots (T-01 to T-20):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ctx.colorTextSecondary),
                  ),
                  const SizedBox(height: 10),

                  // 4-column Grid of Tokens T-01 to T-20
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(20, (index) {
                      final tokenLabel = 'T-${(index + 1).toString().padLeft(2, '0')}';
                      final isSelected = tokenLabel == pos.currentActiveToken;
                      final running = activeBaskets.firstWhere(
                        (b) => b.label.toUpperCase() == tokenLabel,
                        orElse: () => PosParkedBill(id: '', label: '', items: [], totalAmount: 0),
                      );
                      final hasItems = isSelected ? pos.cart.isNotEmpty : running.items.isNotEmpty;
                      final count = isSelected ? pos.totalItemCount : running.totalItemCount;
                      final amt = isSelected ? pos.grandTotal : running.totalAmount;

                      final elapsed = (hasItems && running.id.isNotEmpty)
                          ? DateTime.now().difference(running.updatedAt).inMinutes
                          : 0;

                      return InkWell(
                        onTap: () {
                          pos.switchToken(tokenLabel);
                          Navigator.pop(sheetCtx);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: (MediaQuery.of(ctx).size.width.clamp(320, 540) - 40 - 24) / 4,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (hasItems ? AppColors.warning.withValues(alpha: 0.12) : ctx.colorSurfaceSubtle),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (hasItems ? AppColors.warning.withValues(alpha: 0.6) : ctx.colorBorder),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tokenLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : (hasItems ? context.colorTextPrimary : ctx.colorTextMuted),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSelected
                                    ? (isHindi ? 'सक्रिय' : 'Active')
                                    : (hasItems
                                        ? (elapsed >= 15
                                            ? '$count • ₹${amt.toStringAsFixed(0)} (${elapsed}m)'
                                            : '$count • ₹${amt.toStringAsFixed(0)}')
                                        : (isHindi ? 'खाली' : 'Free')),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white70
                                      : (hasItems
                                          ? (elapsed >= 30 ? AppColors.error : AppColors.warning)
                                          : AppColors.success),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ctx.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ctx.colorBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ctx.colorPrimaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHindi ? 'फ्लोर टोकन कार्ड प्रिंट करें' : 'Print Floor Token Cards',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                isHindi ? 'A4 शीट पर T-01 से T-20 तक 20 लैमिनेटेड कार्ड (QR कोड सहित)' : '20 laminated cards (T-01 to T-20) with QR codes on 1 A4 sheet',
                                style: TextStyle(fontSize: 10.5, color: ctx.colorTextMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text(isHindi ? 'प्रिंट / PDF' : 'Print / PDF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            final currentShop = context.read<AuthController>().currentShop;
                            FloorTokenCardsService.printFloorTokens(
                              context,
                              shopName: currentShop?.name ?? 'ShopSilo Store',
                            );
                          },
                        ),
                      ],
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

  /// Responsive Desktop 2-Column POS Billing Terminal Layout
  Widget _buildDesktopTerminal(BuildContext context, PosController pos) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Main Column: Tokens Bar, Fast Scan Bar & Active Bill Table
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActiveTokensBar(context, pos),
                const SizedBox(height: 12),
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
        _buildActiveTokensBar(context, pos),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildFastScanBar(context, pos),
        ),
        Expanded(child: _buildActiveBillTable(context, pos)),
        _buildMobileBottomCheckoutBar(context, pos),
      ],
    );
  }

  /// Fast Scan & Search Bar with Auto-Add and Live Overlay Matches
  Widget _buildFastScanBar(BuildContext context, PosController pos) {
    List<String> catNames = const [];
    try {
      catNames = context.watch<CategoryController>().categoryNames;
    } catch (_) {
      // Graceful fallback when CategoryController is omitted in test harnesses
    }
    final allCategories = {
      ...pos.products.map((p) => p.category.trim()).where((c) => c.isNotEmpty),
      ...catNames,
    };
    final dynamicCategories = ['All', ...allCategories];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      if (_matchingSearchResults.isNotEmpty) {
                        setState(() {
                          _highlightedMatchIndex = (_highlightedMatchIndex + 1) % _matchingSearchResults.length;
                        });
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      if (_matchingSearchResults.isNotEmpty) {
                        setState(() {
                          _highlightedMatchIndex = (_highlightedMatchIndex - 1 + _matchingSearchResults.length) % _matchingSearchResults.length;
                        });
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                      if (_matchingSearchResults.isNotEmpty || _didYouMeanSuggestion != null) {
                        _handleSearchSubmit(pos);
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      _scanController.clear();
                      setState(() {
                        _matchingSearchResults = [];
                        _isSearchingLocal = false;
                        _highlightedMatchIndex = -1;
                        _didYouMeanSuggestion = null;
                      });
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: AppProductSearchBar(
                  controller: _scanController,
                  focusNode: _searchFocusNode,
                  autoFocus: true,
                  hintText: context.isHindi
                      ? 'बारकोड, SKU स्कैन करें या नाम लिखें...'
                      : 'Scan Barcode, SKU or type item name...',
                  showBarcodeScanner: true,
                  onBarcodeScan: () => _openCameraScanner(context, pos),
                  onChanged: (val) => _onSearchQueryChanged(val, pos),
                  onSubmitted: (_) => _handleSearchSubmit(pos),
                  onClear: () {
                    setState(() {
                      _matchingSearchResults = [];
                      _isSearchingLocal = false;
                      _highlightedMatchIndex = -1;
                      _didYouMeanSuggestion = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _openCameraScanner(context, pos),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      context.isHindi ? 'स्कैनर' : 'Scan',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (MediaQuery.of(context).size.width > 650) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddCustomItemDialog(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        context.isHindi ? 'खुला सामान' : '+ Custom',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // 1-Tap Quick Dynamic Category Shortcuts Bar
        if (pos.products.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: dynamicCategories
                  .map((c) => _buildPosCategoryPill(context, c, pos))
                  .toList(),
            ),
          ),
        ],

        // 1-TAP "DID YOU MEAN?" TYPO / SPELL CORRECTION BANNER
        if (_didYouMeanSuggestion != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: context.colorTextPrimary),
                      children: [
                        TextSpan(
                          text: context.isHindi ? 'क्या आपका मतलब: ' : 'Did you mean: ',
                          style: TextStyle(color: context.colorTextMuted),
                        ),
                        TextSpan(
                          text: _didYouMeanSuggestion!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        TextSpan(
                          text: ' (₹${_didYouMeanSuggestion!.price.toStringAsFixed(0)})',
                          style: TextStyle(fontWeight: FontWeight.bold, color: context.colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(54, 28),
                  ),
                  onPressed: () {
                    final item = _didYouMeanSuggestion!;
                    pos.addToCart(item);
                    _scanController.clear();
                    setState(() {
                      _matchingSearchResults = [];
                      _isSearchingLocal = false;
                      _highlightedMatchIndex = -1;
                      _didYouMeanSuggestion = null;
                    });
                    _searchFocusNode.requestFocus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.isHindi ? '${item.name} बिल में जोड़ दिया गया!' : '${item.name} added to bill!'),
                        duration: const Duration(milliseconds: 700),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: Text(context.isHindi ? '+ जोड़ें' : '+ Add', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],

        // LIVE AUTO-COMPLETE MATCHES OVERLAY WITH KEYBOARD HIGHLIGHTING
        if (_isSearchingLocal && _matchingSearchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _matchingSearchResults.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.colorBorder),
              itemBuilder: (ctx, idx) {
                final p = _matchingSearchResults[idx];
                final isHighlighted = idx == _highlightedMatchIndex;

                return Ink(
                  decoration: BoxDecoration(
                    color: isHighlighted ? context.colorPrimaryLight.withValues(alpha: 0.6) : Colors.transparent,
                    border: isHighlighted
                        ? const Border(left: BorderSide(color: AppColors.primary, width: 3.5))
                        : null,
                  ),
                  child: ListTile(
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
                    title: AppHighlightedText(
                      text: p.name,
                      query: _scanController.text,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: context.colorTextPrimary,
                      ),
                    ),
                    subtitle: Text('${p.category} • ₹${p.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isHighlighted)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('↵ Enter', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ),
                        ElevatedButton(
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
                              _highlightedMatchIndex = -1;
                              _didYouMeanSuggestion = null;
                            });
                            _searchFocusNode.requestFocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.isHindi ? '${p.name} बिल में जोड़ दिया गया!' : '${p.name} added to bill!'),
                                duration: const Duration(milliseconds: 700),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          child: Text(context.isHindi ? '+ जोड़ें' : '+ Add', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // ZERO-DEAD-END RECOVERY SCREEN IN POS (NO PRODUCTS FOUND)
        if (_isSearchingLocal && _matchingSearchResults.isEmpty && _scanController.text.trim().isNotEmpty && _didYouMeanSuggestion == null) ...[
          const SizedBox(height: 8),
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
                  children: [
                    Icon(Icons.search_off_rounded, size: 18, color: context.colorTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.isHindi
                            ? '"${_scanController.text.trim()}" कैटलॉग में नहीं मिला'
                            : 'No items found for "${_scanController.text.trim()}"',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(120, 34),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: Colors.white),
                      label: Text(
                        context.isHindi ? '+ खुला सामान जोड़ें' : '+ Add Loose Item',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        final query = _scanController.text.trim();
                        _showAddCustomItemDialog(context, initialName: query);
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(120, 34),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: AppColors.primary),
                      label: Text(
                        context.isHindi ? '+ इन्वेंट्री में बनाएं' : '+ Create in Inventory',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final query = _scanController.text.trim();
                        context.push('/merchant/inventory?filter=add&name=${Uri.encodeComponent(query)}');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Quick Action Bar: Custom Item & Fast Shortcuts (Zero Overflow Scroll)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              InkWell(
                onTap: () => PriceCheckerDialog.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('price_checker_title'),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: Text(context.isHindi ? '+ अतिरिक्त वस्तु' : '+ Loose / Custom Item', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        context.isHindi ? 'आज की 24h बिक्री सारांश' : 'Today 24h Sales Summary',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
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

  /// Active Bill Receipt Table with Dedicated Tile & 60-120 FPS Steppers
  Widget _buildActiveBillTable(BuildContext context, PosController pos) {
    if (pos.cart.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                context.isHindi ? 'बिलिंग काउंटर तैयार है' : 'POS Billing Counter Ready',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  context.isHindi
                      ? 'बिलिंग शुरू करने के लिए बारकोड स्कैन करें या उत्पाद का नाम लिखें।'
                      : 'Scan product barcode, SKU or type item name above to start billing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: Text(
                      context.isHindi ? 'कैमरा से बारकोड स्कैन करें' : 'Scan with Camera',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _openCameraScanner(context, pos),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text(context.isHindi ? '+ अतिरिक्त वस्तु जोड़ें' : '+ Add Loose Charge'),
                    onPressed: () => _showAddCustomItemDialog(context),
                  ),
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
                Expanded(
                  flex: 4,
                  child: Text(
                    context.isHindi ? 'वस्तु का नाम' : 'ITEM NAME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    context.isHindi ? 'मात्रा' : 'QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    context.isHindi ? 'मूल्य (₹)' : 'PRICE (₹)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // Table Items List with 60-120 FPS Bouncing Physics & Cache Extent
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              cacheExtent: 500,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: pos.cart.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.colorBorder),
              itemBuilder: (context, idx) {
                final item = pos.cart[idx];
                return _PosCartItemTile(
                  key: ValueKey(item.product.id.isNotEmpty ? item.product.id : 'custom_${item.product.name}_$idx'),
                  item: item,
                  onIncrement: () => pos.incrementQuantity(item),
                  onDecrement: () => pos.decrementQuantity(item),
                  onEditPrice: () {
                    SmartSaudaModal.show(
                      context: context,
                      item: item,
                      onApplyPrice: (newPrice) {
                        pos.updateCartItemPrice(item, newPrice);
                      },
                    );
                  },
                  onRemove: () {
                    final removedName = item.product.name;
                    pos.removeFromCart(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.isHindi ? 'वस्तु "$removedName" हटा दी गई' : 'Item "$removedName" removed from bill'),
                        duration: const Duration(milliseconds: 700),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
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
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CUSTOMER LINK & KHATA
          Text(
            context.isHindi ? 'ग्राहक मोबाइल (वैकल्पिक)' : 'CUSTOMER MOBILE (OPTIONAL)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: context.isHindi ? '10 अंकों का ग्राहक मोबाइल दर्ज करें...' : 'Enter 10-digit customer mobile...',
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
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
                      context.isHindi ? 'खाता जुड़ा: ${_matchedKhataCustomer!.name}' : 'Khata Linked: ${_matchedKhataCustomer!.name}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    context.isHindi ? 'उधार: ₹${_matchedKhataCustomer!.balance.toStringAsFixed(0)}' : 'Udhar: ₹${_matchedKhataCustomer!.balance.toStringAsFixed(0)}',
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
          Text(
            context.isHindi ? 'भुगतान माध्यम' : 'PAYMENT METHOD',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PaymentModeChip(
                  label: context.isHindi ? '💵 नकद' : '💵 Cash',
                  selected: pos.paymentMethod == 'cash',
                  activeColor: AppColors.success,
                  onTap: () => pos.setPaymentMethod('cash'),
                ),
                const SizedBox(width: 8),
                _PaymentModeChip(
                  label: context.isHindi ? '📱 यूपीआई' : '📱 UPI QR',
                  selected: pos.paymentMethod == 'upi',
                  activeColor: AppColors.primary,
                  onTap: () {
                    pos.setPaymentMethod('upi');
                    if (pos.grandTotal > 0) {
                      showDynamicUpiQrDialog(context, amount: pos.grandTotal);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.isHindi
                              ? 'UPI QR दिखाने के लिए कार्ट में उत्पाद जोड़ें'
                              : 'Add items to cart to generate dynamic UPI QR code'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _PaymentModeChip(
                  label: context.isHindi ? '⚡ स्प्लिट (नकद+UPI)' : '⚡ Split (Cash+UPI)',
                  selected: pos.paymentMethod == 'split',
                  activeColor: AppColors.primary,
                  onTap: () {
                    pos.setPaymentMethod('split');
                    if (pos.splitCashAmount <= 0 && pos.grandTotal > 0) {
                      final half = (pos.grandTotal / 2).roundToDouble();
                      pos.setSplitCashAmount(half);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _PaymentModeChip(
                  label: context.isHindi ? '📖 खाता उधार' : '📖 Khata Udhar',
                  selected: pos.paymentMethod == 'khata',
                  activeColor: AppColors.warning,
                  onTap: () => pos.setPaymentMethod('khata'),
                ),
              ],
            ),
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
          // 4. Khata Credit Limit & Customer Overdue Guard
          if (pos.paymentMethod == 'khata' && pos.cart.isNotEmpty) ...[
            Builder(builder: (ctx) {
              final khataCustomers = LocalCacheService.getKhataCustomers();
              final cleanPhone = pos.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
              KhataCustomerModel? matchedCustomer;
              if (cleanPhone.length >= 10) {
                final last10 = cleanPhone.substring(cleanPhone.length - 10);
                for (final c in khataCustomers) {
                  final cPhone = c.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cPhone.endsWith(last10)) {
                    matchedCustomer = c;
                    break;
                  }
                }
              }

              if (matchedCustomer == null) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctx.isHindi
                              ? 'उधार बिलिंग के लिए नीचे ग्राहक का 10-अंकों का मोबाइल नंबर दर्ज करें'
                              : 'Enter 10-digit customer mobile number below for credit billing',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final currentBal = matchedCustomer.currentBalance;
              final creditLimit = matchedCustomer.creditLimit;
              final newBal = currentBal + pos.grandTotal;
              final isOverLimit = creditLimit > 0 && newBal > creditLimit;
              final hasOverdue = matchedCustomer.overdueCount > 0;

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverLimit
                      ? AppColors.error.withValues(alpha: 0.08)
                      : (hasOverdue ? AppColors.warning.withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOverLimit
                        ? AppColors.error
                        : (hasOverdue ? AppColors.warning : AppColors.primary.withValues(alpha: 0.3)),
                    width: isOverLimit ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isOverLimit
                                  ? Icons.warning_amber_rounded
                                  : (hasOverdue ? Icons.schedule_rounded : Icons.account_balance_wallet_outlined),
                              size: 16,
                              color: isOverLimit ? AppColors.error : (hasOverdue ? AppColors.warning : AppColors.primary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              matchedCustomer.customerName.isNotEmpty ? matchedCustomer.customerName : (ctx.isHindi ? 'खाता ग्राहक' : 'Khata Customer'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        Text(
                          '${ctx.isHindi ? 'बकाया' : 'Dues'}: ₹${currentBal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: currentBal > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          creditLimit > 0 ? '${ctx.isHindi ? 'उधार सीमा' : 'Credit Limit'}: ₹${creditLimit.toStringAsFixed(0)}' : (ctx.isHindi ? 'उधार सीमा: असीमित' : 'Credit Limit: Open'),
                          style: TextStyle(fontSize: 11, color: ctx.colorTextMuted),
                        ),
                        Text(
                          '${ctx.isHindi ? 'नया बकाया' : 'New Dues'}: ₹${newBal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isOverLimit ? AppColors.error : ctx.colorTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (isOverLimit) ...[
                      const SizedBox(height: 6),
                      Text(
                        ctx.isHindi
                            ? '⚠️ चेतावनी: यह बिल ग्राहक की तय उधार सीमा (₹${creditLimit.toStringAsFixed(0)}) को पार कर देगा!'
                            : '⚠️ Warning: This bill exceeds customer\'s credit limit of ₹${creditLimit.toStringAsFixed(0)}!',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ],
                    if (hasOverdue && !isOverLimit) ...[
                      const SizedBox(height: 4),
                      Text(
                        ctx.isHindi
                            ? '⏱️ इस ग्राहक के पुराने बिल बकाया हैं।'
                            : '⏱️ Customer has overdue unpaid bills.',
                        style: const TextStyle(fontSize: 11, color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          if (pos.paymentMethod == 'split' && pos.cart.isNotEmpty) ...[
            const SizedBox(height: 10),
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
                      Expanded(
                        child: Text(
                          context.isHindi ? '⚡ स्प्लिट भुगतान (नकद + यूपीआई):' : '⚡ Split Settlement (Cash + UPI):',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${pos.grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.isHindi ? '1. नकद हिस्सा:' : '1. Cash Portion:',
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: pos.splitCashAmount.toStringAsFixed(0),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val) ?? 0.0;
                                pos.setSplitCashAmount(parsed);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.isHindi ? '2. यूपीआई हिस्सा:' : '2. UPI Portion:',
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.colorPrimaryLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${pos.splitUpiAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (pos.splitUpiAmount > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 16),
                        label: Text(
                          context.isHindi
                              ? '📱 यूपीआई क्यूआर दिखाएं (₹${pos.splitUpiAmount.toStringAsFixed(0)})'
                              : '📱 Show UPI QR (₹${pos.splitUpiAmount.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => showDynamicUpiQrDialog(context, amount: pos.splitUpiAmount),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (pos.paymentMethod == 'cash' && pos.cart.isNotEmpty) ...[
            const SizedBox(height: 10),
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
                  Text(
                    context.isHindi ? 'नकद प्राप्त राशि (Tendered Cash):' : 'Cash Received (Tendered):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: pos.getSmartCashSuggestions().map((amount) {
                        final isExact = (amount - pos.grandTotal).abs() < 0.01;
                        final label = isExact
                            ? (context.isHindi
                                ? 'बराबर (₹${amount.toStringAsFixed(0)})'
                                : 'Exact (₹${amount.toStringAsFixed(0)})')
                            : '₹${amount.toStringAsFixed(0)}';
                        return _buildCashChip(context, label, amount, pos);
                      }).toList(),
                    ),
                  ),
                  if (pos.changeDue > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.isHindi ? '🟢 ग्राहक को वापस करें (वापसी राशि):' : '🟢 Return to Customer (Change):',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.isHindi
                                      ? '₹${pos.cashTendered.toStringAsFixed(0)} प्राप्त − ₹${pos.grandTotal.toStringAsFixed(0)} बिल'
                                      : '₹${pos.cashTendered.toStringAsFixed(0)} Tendered − ₹${pos.grandTotal.toStringAsFixed(0)} Bill',
                                  style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                                ),
                              ],
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₹${pos.changeDue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (pos.cashTendered > 0 && (pos.cashTendered - pos.grandTotal).abs() < 0.01) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.isHindi ? '✓ पूर्ण बराबर नकद भुगतान प्राप्त' : '✓ Full exact cash received',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (pos.cashShortage > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.isHindi ? '⚠️ शेष बकाया राशि:' : '⚠️ Remaining Shortage:',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${pos.cashShortage.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.warning),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  ),
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.primary),
                                  label: Text(
                                    context.isHindi ? 'शेष UPI से लें' : 'Take via UPI',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  onPressed: () {
                                    pos.setPaymentMethod('split');
                                    pos.setSplitCashAmount(pos.cashTendered);
                                    showDynamicUpiQrDialog(context, amount: pos.cashShortage);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

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
                    Expanded(
                      child: Text(
                        '${context.isHindi ? "उप-योग" : "Subtotal"} (${pos.totalItemCount} ${context.isHindi ? "वस्तुएं" : "items"}):',
                        style: TextStyle(color: context.colorTextMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('₹${pos.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              context.isHindi ? 'छूट:' : 'Discount:',
                              style: TextStyle(color: context.colorTextMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showDiscountDialog(context, pos),
                            child: Text(
                              context.isHindi ? '✏️ छूट बदलें' : '✏️ Edit Discount',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('-₹${pos.discount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(height: 18, color: context.colorBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        context.isHindi ? 'कुल राशि:' : 'GRAND TOTAL:',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹${pos.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: -0.5),
                      ),
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
              pos.isLoading
                  ? (context.isHindi ? 'बिक्री प्रक्रिया जारी...' : 'Processing Sale...')
                  : (context.isHindi
                      ? '⚡ बिक्री पूर्ण करें और बिल बनाएं (₹${pos.grandTotal.toStringAsFixed(0)})'
                      : '⚡ Complete Sale & Print Bill (₹${pos.grandTotal.toStringAsFixed(0)})'),
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
                          content: Text(pos.errorMessage ?? (context.isHindi ? 'बिक्री असफल रही' : 'Sale generation failed')),
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
    final isSelected = (pos.cashTendered - amount).abs() < 0.01;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          _cashController.text = amount.toStringAsFixed(0);
          pos.setCashTendered(amount);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : context.colorSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.colorBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : context.colorTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile Bottom Checkout Bar with Zero Flex Overflow Protection
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
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pos.totalItemCount} ${context.isHindi ? "वस्तुएं बिल में" : "Items in Bill"}',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹${pos.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: -0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(150, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    top: 20,
                    left: 20,
                    right: 20,
                  ),
                  child: _buildCheckoutPanel(ctx, pos),
                ),
              );
            },
            child: Text(
              context.isHindi ? 'बिल चेकआउट' : 'Checkout Bill',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🛒 Dedicated POS Cart Item Tile with 0ms Tactile Steppers & Zero Repaint Cascading
class _PosCartItemTile extends StatelessWidget {
  final PosCartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback? onEditPrice;

  const _PosCartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.onEditPrice,
  });

  @override
  Widget build(BuildContext context) {
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

          // Item Name & Unit Price (Tappable for Smart Sauda Negotiation)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: onEditPrice,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.customPrice != item.product.price
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.customPrice != item.product.price
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : context.colorBorder,
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.customPrice == item.product.price)
                            Text(
                              '₹${item.product.price.toStringAsFixed(0)} / ${item.product.unit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: context.colorTextPrimary,
                              ),
                            )
                          else ...[
                            Text(
                              '₹${item.customPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '₹${item.product.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9.5,
                                decoration: TextDecoration.lineThrough,
                                color: context.colorTextMuted,
                              ),
                            ),
                            Text(
                              ' / ${item.product.unit}',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colorTextMuted,
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            Icons.handshake_outlined,
                            size: 13,
                            color: item.customPrice != item.product.price
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

          // Quantity Stepper (0ms Direct Tactile Response without UI toast lag)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: onDecrement,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: context.colorTextPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onIncrement,
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '₹${item.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: context.colorTextPrimary,
                ),
              ),
            ),
          ),

          // 🗑️ Item Deletion Button
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
            tooltip: context.isHindi ? 'वस्तु हटाएं' : 'Remove Item',
            onPressed: onRemove,
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
  final Color? activeColor;

  const _PaymentModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? AppColors.primary;
    final effectiveBg = selected
        ? effectiveColor.withValues(alpha: 0.12)
        : context.colorSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: effectiveBg,
          border: Border.all(
            color: selected ? effectiveColor : context.colorBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? effectiveColor : context.colorTextPrimary,
          ),
        ),
      ),
    );
  }
}
