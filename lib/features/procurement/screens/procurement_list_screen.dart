import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../../products/models/product_model.dart';
import '../../pos/widgets/supplier_invoice_ocr_modal.dart';
import '../controllers/procurement_controller.dart';
import '../models/procurement_model.dart';

/// Standard wholesale units for Indian Mandi / Retail sourcing
const List<String> _kWholesaleUnits = [
  'kg',
  'बोरी (Bags)',
  'पेटी / बॉक्स (Box)',
  'पैकेट (Pkt)',
  'लीटर (Ltr)',
  'पीस (Pcs)',
  'क्विंटल (Qtl)',
  'ग्राम (g)',
  'दर्जन (Dzn)',
  'कार्टन (Carton)',
  'टिन / केन (Tin)',
];

class ProcurementListScreen extends StatefulWidget {
  const ProcurementListScreen({super.key});

  @override
  State<ProcurementListScreen> createState() => _ProcurementListScreenState();
}

class _ProcurementListScreenState extends State<ProcurementListScreen> {
  String _activeFilter = 'ALL'; // 'ALL' | 'PENDING' | 'COMPLETED'

  /// Share structured wholesale procurement sheet via WhatsApp
  Future<void> _sendWhatsAppOrderSheet(BuildContext context, List<ProcurementItemModel> items, String shopName) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.isHindi ? 'मंडी लिस्ट अभी खाली है' : 'Mandi procurement list is empty')),
      );
      return;
    }

    final pending = items.where((i) => !i.isCompleted).toList();
    final target = pending.isNotEmpty ? pending : items;

    String text = '📋 *MANDI SOURCING & WHOLESALE ORDER SHEET*\n';
    text += 'Dukan: *$shopName*\n';
    text += 'Tareekh: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n';
    text += '------------------------------------\n\n';
    text += '*KHAREEDNE WALE ITEMS (${target.length}):*\n\n';

    double totalEst = 0.0;
    for (int i = 0; i < target.length; i++) {
      final item = target[i];
      totalEst += item.itemEstimatedCost;
      text += '${i + 1}. *${item.name}* [${item.category}]\n';
      text += '   • Matra (Qty): *${item.qty}*\n';
      if (item.estimatedPrice > 0) {
        text += '   • Est Rate: *₹${item.estimatedPrice.toStringAsFixed(0)}*\n';
      }
      if (item.dealerName.isNotEmpty) {
        text += '   • Dealer: ${item.dealerName}\n';
      }
      if (item.notes.isNotEmpty) {
        text += '   • Note: ${item.notes}\n';
      }
      text += '\n';
    }

    if (totalEst > 0) {
      text += '------------------------------------\n';
      text += 'Est. Total Budget: *₹${totalEst.toStringAsFixed(0)}*\n';
    }
    text += '\nPlease confirm wholesale rates and stock availability. Thank you!';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.isHindi ? 'व्हाट्सएप नहीं खोला जा सका' : 'Cannot launch WhatsApp')),
        );
      }
    }
  }

  /// 1-Tap call dealer
  Future<void> _callDealer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Opens the professional, structured Add/Edit Sourcing Item Sheet
  void _showAddEditSourcingItemSheet(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController, {
    ProcurementItemModel? editItem,
  }) {
    // Parse quantity and unit if editing
    String initialQtyNum = '1';
    String initialUnit = _kWholesaleUnits.first;
    if (editItem != null) {
      final parts = editItem.qty.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        initialQtyNum = parts[0];
        if (parts.length > 1) {
          final restUnit = parts.sublist(1).join(' ').trim();
          initialUnit = _kWholesaleUnits.firstWhere(
            (u) => u.toLowerCase().contains(restUnit.toLowerCase()) || restUnit.toLowerCase().contains(u.toLowerCase()),
            orElse: () => restUnit,
          );
        }
      }
    }

    final TextEditingController nameCtrl = TextEditingController(text: editItem?.name ?? '');
    final TextEditingController qtyCtrl = TextEditingController(text: editItem != null ? initialQtyNum : '1');
    final TextEditingController priceCtrl = TextEditingController(
      text: (editItem != null && editItem.estimatedPrice > 0) ? editItem.estimatedPrice.toStringAsFixed(0) : '',
    );
    final TextEditingController dealerCtrl = TextEditingController(text: editItem?.dealerName ?? '');
    final TextEditingController dealerPhoneCtrl = TextEditingController(text: editItem?.dealerPhone ?? '');
    final TextEditingController notesCtrl = TextEditingController(text: editItem?.notes ?? '');

    String selectedCategory = editItem?.category ?? 'General Store';
    String selectedUnit = initialUnit;
    bool showDealerNotes = editItem != null &&
        (editItem.dealerName.isNotEmpty || editItem.notes.isNotEmpty || editItem.dealerPhone.isNotEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final double qtyVal = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
            final double rateVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
            final double calculatedTotal = qtyVal * rateVal;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ctx.colorBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Sheet Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              editItem == null ? Icons.add_shopping_cart_rounded : Icons.edit_note_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editItem == null
                                      ? (context.isHindi ? 'नया मंडी सामान जोड़ें' : 'Add Sourcing Item')
                                      : (context.isHindi ? 'मंडी सामान अपडेट करें' : 'Edit Sourcing Item'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.colorTextPrimary,
                                  ),
                                ),
                                Text(
                                  context.isHindi
                                      ? 'थोक खरीद हेतु सामान, मात्रा व अनुमानित दर'
                                      : 'Item name, wholesale quantity & target rate',
                                  style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: context.colorTextMuted, size: 20),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 1. PRODUCT NAME WITH AUTOCOMPLETE FROM INVENTORY
                      Autocomplete<ProductModel>(
                        initialValue: TextEditingValue(text: nameCtrl.text),
                        optionsBuilder: (TextEditingValue textVal) {
                          if (textVal.text.trim().isEmpty) {
                            return const Iterable<ProductModel>.empty();
                          }
                          final q = textVal.text.toLowerCase();
                          return prodController.products
                              .where((p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q))
                              .take(6);
                        },
                        displayStringForOption: (ProductModel opt) => opt.name,
                        onSelected: (ProductModel sel) {
                          nameCtrl.text = sel.name;
                          setModalState(() {
                            if (CategoryRegistry.canonicalCategories.contains(sel.category)) {
                              selectedCategory = sel.category;
                            }
                            if (sel.costPrice > 0) {
                              priceCtrl.text = sel.costPrice.toStringAsFixed(0);
                            } else if (sel.price > 0) {
                              priceCtrl.text = sel.price.toStringAsFixed(0);
                            }
                            if (sel.unit.isNotEmpty) {
                              final match = _kWholesaleUnits.firstWhere(
                                (u) => u.toLowerCase().contains(sel.unit.toLowerCase()) || sel.unit.toLowerCase().contains(u.toLowerCase()),
                                orElse: () => selectedUnit,
                              );
                              selectedUnit = match;
                            }
                          });
                        },
                        fieldViewBuilder: (fieldCtx, fieldCtrl, focusNode, onFieldSubmitted) {
                          fieldCtrl.addListener(() {
                            nameCtrl.text = fieldCtrl.text;
                          });
                          return TextFormField(
                            controller: fieldCtrl,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: context.isHindi ? 'सामान का नाम *' : 'Item Name *',
                              hintText: context.isHindi ? 'उदा. शरबाती गेहूं / फॉर्च्यून तेल' : 'e.g. Sharbati Wheat / Fortune Oil',
                              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          );
                        },
                        optionsViewBuilder: (optCtx, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(10),
                              color: context.colorSurface,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (ctx, idx) {
                                    final opt = options.elementAt(idx);
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                                      title: Text(opt.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: Text('${opt.category} • ₹${opt.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. STRUCTURED QUANTITY & WHOLESALE UNIT PICKER
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: context.isHindi ? 'मात्रा (Qty) *' : 'Quantity *',
                                hintText: '50',
                                prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('unit_$selectedUnit'),
                              initialValue: _kWholesaleUnits.contains(selectedUnit) ? selectedUnit : _kWholesaleUnits.first,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.isHindi ? 'यूनिट (Unit)' : 'Unit',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: _kWholesaleUnits.map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. ESTIMATED RATE & CATEGORY PICKER
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: context.isHindi ? 'अनुमानित दर (₹)' : 'Est Rate (₹)',
                                hintText: '2400',
                                prefixText: '₹ ',
                                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('cat_$selectedCategory'),
                              initialValue: CategoryRegistry.canonicalCategories.contains(selectedCategory)
                                  ? selectedCategory
                                  : CategoryRegistry.canonicalCategories.first,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.isHindi ? 'श्रेणी (Category)' : 'Category',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: CategoryRegistry.canonicalCategories.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedCategory = val);
                              },
                            ),
                          ),
                        ],
                      ),

                      // LIVE ESTIMATED SUBTOTAL PREVIEW CARD
                      if (qtyVal > 0 && rateVal > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calculate_outlined, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.isHindi
                                        ? 'कुल अनुमानित खर्च ($qtyVal $selectedUnit × ₹${rateVal.toStringAsFixed(0)}):'
                                        : 'Est Total ($qtyVal $selectedUnit × ₹${rateVal.toStringAsFixed(0)}):',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                                  ),
                                ],
                              ),
                              Text(
                                '₹${calculatedTotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // 4. EXPANDABLE SUPPLIER / MANDI DEALER DETAILS (OPTIONAL)
                      InkWell(
                        onTap: () => setModalState(() => showDealerNotes = !showDealerNotes),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                showDealerNotes ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                showDealerNotes
                                    ? (context.isHindi ? 'सप्लायर विवरण छुपाएं' : 'Hide Supplier Details')
                                    : (context.isHindi ? '+ सप्लायर व नोट्स जोड़ें (वैकल्पिक)' : '+ Add Supplier & Notes (Optional)'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showDealerNotes) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: dealerCtrl,
                                decoration: InputDecoration(
                                  labelText: context.isHindi ? 'व्यापारी / सप्लायर' : 'Wholesaler / Dealer',
                                  hintText: 'उदा. श्याम ट्रेडिंग कंपनी',
                                  prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: dealerPhoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: context.isHindi ? 'फोन / व्हाट्सएप' : 'Phone / WhatsApp',
                                  hintText: '9876543210',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: InputDecoration(
                            labelText: context.isHindi ? 'क्वालिटी नोट्स / शर्तें' : 'Quality Notes / Specs',
                            hintText: context.isHindi ? 'उदा. शरबाती ग्रेड-A, नया माल, नकद डिस्काउंट' : 'e.g. Grade A Quality, New Stock',
                            prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 5. SUBMIT ACTION BUTTON
                      AppButton(
                        text: editItem == null
                            ? (context.isHindi ? '✓ मंडी लिस्ट में जोड़ें' : '✓ Add to Sourcing List')
                            : (context.isHindi ? '✓ सामान अपडेट करें' : '✓ Update Item'),
                        icon: editItem == null ? Icons.add_shopping_cart_rounded : Icons.check_circle_outline_rounded,
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('proc_val_name'))),
                            );
                            return;
                          }
                          final rawQty = qtyCtrl.text.trim();
                          final qtyStr = rawQty.isEmpty ? '1 $selectedUnit' : '$rawQty $selectedUnit';
                          final rate = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                          if (editItem == null) {
                            controller.addItem(
                              name: name,
                              qty: qtyStr,
                              category: selectedCategory,
                              estimatedPrice: rate,
                              dealerName: dealerCtrl.text.trim(),
                              dealerPhone: dealerPhoneCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.isHindi ? '✓ सामान मंडी लिस्ट में जुड़ गया!' : '✓ Item added to Sourcing List!'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          } else {
                            controller.updateItem(
                              id: editItem.id,
                              name: name,
                              qty: qtyStr,
                              category: selectedCategory,
                              estimatedPrice: rate,
                              dealerName: dealerCtrl.text.trim(),
                              dealerPhone: dealerPhoneCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.isHindi ? '✓ सामान अपडेट हो गया!' : '✓ Item updated!'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    ],
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
    final controller = context.watch<ProcurementController>();
    final authController = context.watch<AuthController>();
    final prodController = context.watch<ProductController>();

    final cachedShop = LocalCacheService.getShop();
    final shopName = (authController.currentShop != null && authController.currentShop!.name.trim().isNotEmpty)
        ? authController.currentShop!.name.trim()
        : (cachedShop != null && cachedShop.name.trim().isNotEmpty
            ? cachedShop.name.trim()
            : 'ShopSilo Partner Store');
    final items = controller.items;

    // Real Low Stock Products from Store Inventory
    final lowStockProducts = prodController.products.where((p) => p.isLowStock || p.isOutOfStock).toList();

    // Filter items based on active chip
    final filteredItems = items.where((item) {
      if (_activeFilter == 'PENDING') return !item.isCompleted;
      if (_activeFilter == 'COMPLETED') return item.isCompleted;
      return true;
    }).toList();

    return MerchantShell(
      currentIndex: -1,
      showBottomNav: false,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditSourcingItemSheet(context, controller, prodController),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
        label: Text(
          context.isHindi ? 'नया सामान जोड़ें' : 'Add Item',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
        ),
      ),
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
        title: Text(
          context.tr('mandi_title'),
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
        ),
        actions: [
          // Refresh Action
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
            tooltip: context.isHindi ? 'रीफ्रेश करें' : 'Refresh List',
            onPressed: () {
              controller.refreshList();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.isHindi ? '✓ मंडी खरीद लिस्ट रीफ्रेश हो गई' : '✓ Mandi List Refreshed'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // WhatsApp Share Direct Action
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 19, color: Color(0xFF128C7E)),
            tooltip: context.tr('mandi_whatsapp_sheet'),
            onPressed: () => _sendWhatsAppOrderSheet(context, items, shopName),
          ),

          // More Options Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colorSurface,
            onSelected: (value) {
              if (value == 'pdf') {
                controller.generatePdfSheet(context, shopName);
              } else if (value == 'import') {
                if (lowStockProducts.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.isHindi ? 'सब सामान इन-स्टॉक है! कोई कम स्टॉक आइटम नहीं मिला।' : 'All items in stock! No low-stock products found.')),
                  );
                  return;
                }
                controller.importLowStockProducts(lowStockProducts);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.isHindi ? '${lowStockProducts.length} कम स्टॉक वाले उत्पाद मंडी लिस्ट में जुड़ गए!' : '${lowStockProducts.length} Low-Stock Items imported!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else if (value == 'ai_invoice') {
                SupplierInvoiceOcrModal.show(context);
              } else if (value == 'clear') {
                controller.clearAllCompleted();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.isHindi ? 'खरीदे जा चुके सामान हटा दिए गए' : 'Cleared bought items')),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('mandi_pdf_sheet'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: ctx.colorTextPrimary),
                    const SizedBox(width: 10),
                    Text(
                      '${context.tr('mandi_import_low')} (${lowStockProducts.length})',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'ai_invoice',
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 10),
                    Text(
                      context.isHindi ? 'सप्लायर बिल स्कैन' : 'Supplier Invoice Scan',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (controller.completedCount > 0)
                PopupMenuItem<String>(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.cleaning_services_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Text(
                        context.isHindi ? 'खरीदा सामान साफ करें' : 'Clear Bought Items',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          child: ResponsiveContainer(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. SLEEK, UNIFIED PROCUREMENT SUMMARY BANNER
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.assignment_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${controller.totalCount} ${context.isHindi ? "सामान" : "Items"}',
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: context.colorTextPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${controller.pendingCount} ${context.isHindi ? "बाकी" : "Pending"}',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.warning),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${controller.completedCount} ${context.isHindi ? "खरीदा" : "Bought"}',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.success),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${controller.totalEstimatedBudget.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                context.isHindi ? 'अनुमानित कुल बजट' : 'Estimated Budget',
                                style: TextStyle(fontSize: 11.5, color: context.colorTextMuted, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Quick Low-Stock Import Banner (if any)
                      if (lowStockProducts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colorBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  context.isHindi
                                      ? '${lowStockProducts.length} कम स्टॉक सामान इन्वेंट्री में मिले'
                                      : '${lowStockProducts.length} low-stock items in inventory',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  controller.importLowStockProducts(lowStockProducts);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.isHindi
                                          ? '${lowStockProducts.length} कम स्टॉक सामान लिस्ट में जुड़ गए!'
                                          : '${lowStockProducts.length} items imported!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.isHindi ? '+ ऑटो-इंपोर्ट' : '+ Auto-Import',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. CLEAN FILTER CHIPS STRIP
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', context.isHindi ? 'सभी (${items.length})' : 'All (${items.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('PENDING', context.isHindi ? 'बाकी (${controller.pendingCount})' : 'Pending (${controller.pendingCount})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('COMPLETED', context.isHindi ? 'खरीदा गया (${controller.completedCount})' : 'Bought (${controller.completedCount})'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. MANDI SOURCING CHECKLIST
                if (filteredItems.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: context.colorTextMuted),
                        const SizedBox(height: 12),
                        Text(
                          context.isHindi ? 'मंडी खरीद लिस्ट खाली है' : 'Sourcing list is empty',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.isHindi
                              ? 'निचे दिए गए "+ नया सामान जोड़ें" बटन से सामान जोड़ें!'
                              : 'Tap "+ Add Item" below to start your sourcing checklist!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          label: Text(
                            context.isHindi ? 'नया सामान जोड़ें' : 'Add Sourcing Item',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                          onPressed: () => _showAddEditSourcingItemSheet(context, controller, prodController),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1-Tap Checkbox Toggle
                            Transform.scale(
                              scale: 1.1,
                              child: Checkbox.adaptive(
                                value: item.isCompleted,
                                activeColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (_) => controller.toggleItem(item.id),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: item.isCompleted ? context.colorTextMuted : context.colorTextPrimary,
                                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                      if (item.estimatedPrice > 0) ...[
                                        Text(
                                          '₹${item.estimatedPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: item.isCompleted ? context.colorTextMuted : AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // Quantity badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: context.colorSurfaceSubtle,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: context.colorBorder),
                                        ),
                                        child: Text(
                                          item.qty,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: item.isCompleted ? context.colorTextMuted : context.colorTextPrimary,
                                          ),
                                        ),
                                      ),
                                      // Category badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: context.colorPrimaryLight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      if (item.dealerName.isNotEmpty)
                                        Text(
                                          item.dealerName,
                                          style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                  if (item.notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.notes,
                                      style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Actions
                            if (item.dealerPhone.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
                                tooltip: 'Call Wholesaler',
                                onPressed: () => _callDealer(item.dealerPhone),
                              ),
                            ],
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: context.colorTextMuted),
                              tooltip: 'Edit Item',
                              onPressed: () => _showAddEditSourcingItemSheet(
                                context,
                                controller,
                                prodController,
                                editItem: item,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.colorTextMuted),
                              tooltip: 'Remove Item',
                              onPressed: () => controller.removeItem(item.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _activeFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : context.colorTextPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: context.colorSurfaceSubtle,
      onSelected: (_) => setState(() => _activeFilter = value),
    );
  }
}
