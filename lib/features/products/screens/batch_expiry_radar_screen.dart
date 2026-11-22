import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../controllers/batch_expiry_controller.dart';
import '../controllers/product_controller.dart';
import '../../procurement/controllers/procurement_controller.dart';
import 'product_detail_screen.dart';

/// Expiry & Batch Radar Screen
/// Displays all products from shop inventory with an expiry date,
/// categorizes them by urgency (Expired, 7 Days, 30 Days, Upcoming),
/// provides 1-tap reordering to Mandi procurement and clearance markdowns.
class BatchExpiryRadarScreen extends StatefulWidget {
  const BatchExpiryRadarScreen({super.key});

  @override
  State<BatchExpiryRadarScreen> createState() => _BatchExpiryRadarScreenState();
}

class _BatchExpiryRadarScreenState extends State<BatchExpiryRadarScreen> {
  String _selectedFilter = 'all'; // 'all', 'expired', '7_days', '30_days', '60_days', 'safe'
  String _selectedCategory = 'All';
  String _sortOrder = 'expiry_asc'; // 'expiry_asc', 'expiry_desc', 'stock_desc', 'name_asc'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final batchCtrl = context.read<BatchExpiryController>();
    final prodCtrl = context.read<ProductController>();

    batchCtrl.loadNearExpiry();
    if (prodCtrl.products.isEmpty && !prodCtrl.isLoading) {
      prodCtrl.loadProducts();
    } else {
      batchCtrl.syncInventoryProducts(prodCtrl.products);
    }
  }

  // 1-Tap Add to Mandi Procurement List Dialog
  void _showAddToMandiDialog(ExpiryTrackedItem item) {
    final isHindi = context.isHindi;
    final qtyCtrl = TextEditingController(text: item.stockQuantity > 0 ? item.stockQuantity.toInt().toString() : '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(bContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'मंडी लिस्ट में नया स्टॉक जोड़ें' : 'Add Fresh Stock to Mandi Sheet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isHindi ? 'एक्सपायर होने वाले सामान का नया स्टॉक मंगाएं' : 'Reorder replacement stock before expiry',
                        style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${isHindi ? "वर्तमान स्टॉक" : "Current Stock"}: ${item.stockQuantity.toStringAsFixed(0)} ${item.unit} • MRP ₹${item.mrp.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isHindi ? 'ऑर्डर मात्रा (${item.unit})' : 'Order Quantity (${item.unit})',
                hintText: 'e.g. 10',
                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(bContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text(
                      isHindi ? 'मंडी लिस्ट में जोड़ें' : 'Add to Mandi',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final qtyVal = qtyCtrl.text.trim();
                      if (qtyVal.isEmpty) return;

                      final procCtrl = context.read<ProcurementController>();
                      await procCtrl.addItem(
                        name: item.name,
                        qty: '$qtyVal ${item.unit}',
                        category: item.category.isNotEmpty ? item.category : 'General Store',
                        estimatedPrice: item.purchaseCost > 0 ? item.purchaseCost : (item.mrp * 0.7),
                      );

                      if (bContext.mounted) {
                        Navigator.pop(bContext);
                      }
                      if (mounted) {
                        CustomSnackbar.showSuccess(
                          context,
                          isHindi
                              ? '✓ ${item.name} ($qtyVal ${item.unit}) मंडी लिस्ट में जुड़ गया!'
                              : '✓ ${item.name} ($qtyVal ${item.unit}) added to Mandi list!',
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1-Tap Clearance Markdown / Discount Dialog
  void _showClearanceDiscountDialog(ExpiryTrackedItem item) {
    final isHindi = context.isHindi;
    double selectedPercent = 20.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final discountedPrice = item.mrp * (1 - (selectedPercent / 100));

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.discount_rounded, color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'क्लियरेंस सेल / छूट लगाएं' : 'Clearance Sale Markdown',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isHindi ? 'एक्सपायर होने से पहले तुरंत स्टॉक क्लियर करें' : 'Liquidate near-expiry stock fast',
                            style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('MRP: ₹${item.mrp.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isHindi ? 'क्लियरेंस ऑफर प्राइज:' : 'Clearance Offer Price:',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '₹${discountedPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isHindi ? 'छूट प्रतिशत चुनें:' : 'Select Discount Percentage:',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [10.0, 20.0, 30.0, 50.0].map((pct) {
                    final isSel = selectedPercent == pct;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              '${pct.toInt()}% छूट',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                color: isSel ? Colors.white : context.colorTextPrimary,
                              ),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFFDC2626),
                          backgroundColor: context.colorSurfaceSubtle,
                          showCheckmark: false,
                          onSelected: (_) => setModalState(() => selectedPercent = pct),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (item.productId != null) {
                        final prodCtrl = context.read<ProductController>();
                        await prodCtrl.editProduct(item.productId!, {
                          'discount_price': discountedPrice,
                          'attributes': {
                            'markdown_percent': selectedPercent.toInt().toString(),
                            'clearance_sale': 'true',
                          },
                        });
                        prodCtrl.loadProducts();
                      }
                      if (bContext.mounted) {
                        Navigator.pop(bContext);
                      }
                      if (mounted) {
                        CustomSnackbar.showSuccess(
                          context,
                          isHindi
                              ? '✓ ${item.name} पर ${selectedPercent.toInt()}% क्लियरेंस छूट लागू कर दी गई!'
                              : '✓ ${selectedPercent.toInt()}% clearance markdown applied to ${item.name}!',
                        );
                      }
                    },
                    child: Text(
                      isHindi ? 'क्लियरेंस छूट लागू करें' : 'Apply Clearance Markdown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 1-Tap Update / Set Expiry Date
  Future<void> _updateExpiryDate(ExpiryTrackedItem item) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate.isAfter(DateTime.now()) ? item.expiryDate : DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked == null || !mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(picked);

    if (item.productId != null) {
      final prodCtrl = context.read<ProductController>();
      final ok = await prodCtrl.editProduct(item.productId!, {
        'attributes': {
          'expiry_date': dateStr,
        },
      });

      if (ok && mounted) {
        await prodCtrl.loadProducts();
        if (!mounted) return;
        context.read<BatchExpiryController>().syncInventoryProducts(prodCtrl.products);
        CustomSnackbar.showSuccess(
          context,
          context.isHindi
              ? '✓ ${item.name} की नई एक्सपायरी डेट (${DateFormat("dd MMM yyyy").format(picked)}) सेट की गई'
              : '✓ Expiry date updated to ${DateFormat("dd MMM yyyy").format(picked)}',
        );
      }
    }
  }

  // Dialog to attach Expiry Date to any existing Inventory product
  void _showTrackExistingProductSheet() {
    final prodCtrl = context.read<ProductController>();
    final isHindi = context.isHindi;
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final candidateProducts = prodCtrl.products.where((p) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            return p.name.toLowerCase().contains(q) || p.barcode.contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(bCtx).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHindi ? 'दुकान के सामान पर एक्सपायरी सेट करें' : 'Track Product Expiry',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (val) => setModalState(() => search = val.trim()),
                  decoration: InputDecoration(
                    hintText: isHindi ? 'सामान का नाम या बारकोड खोजें...' : 'Search product name or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: candidateProducts.isEmpty
                      ? Center(
                          child: Text(
                            isHindi ? 'कोई सामान नहीं मिला' : 'No matching products found',
                            style: TextStyle(color: context.colorTextMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: candidateProducts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = candidateProducts[i];
                            final hasExp = p.expiryDate != null;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                hasExp
                                    ? '${isHindi ? "वर्तमान एक्सपायरी" : "Expiry"}: ${DateFormat("dd MMM yyyy").format(p.expiryDate!)}'
                                    : (isHindi ? 'एक्सपायरी डेट सेट नहीं है' : 'No expiry set'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: hasExp ? const Color(0xFF16A34A) : context.colorTextMuted,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  Navigator.pop(bCtx);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: p.expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                                  );
                                  if (picked != null && mounted) {
                                    final dateStr = DateFormat('yyyy-MM-dd').format(picked);
                                    await prodCtrl.editProduct(p.id, {
                                      'attributes': {'expiry_date': dateStr},
                                    });
                                    if (!mounted) return;
                                    await prodCtrl.loadProducts();
                                    if (!mounted) return;
                                    context.read<BatchExpiryController>().syncInventoryProducts(prodCtrl.products);
                                    CustomSnackbar.showSuccess(
                                      context,
                                      isHindi
                                          ? '✓ ${p.name} की एक्सपायरी डेट सेट हो गई और रडार में जुड़ गया!'
                                          : '✓ Expiry tracked for ${p.name}!',
                                    );
                                  }
                                },
                                child: Text(
                                  hasExp ? (isHindi ? 'बदलें' : 'Change') : (isHindi ? 'डेट सेट करें' : 'Set Date'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
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

  // Register Fresh Batch Lot Dialog
  void _showAddBatchDialog() {
    final isHindi = context.isHindi;
    final prodCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    DateTime selectedExpiry = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHindi ? 'नया बैच / लॉट रजिस्टर करें' : 'Register Product Batch Lot',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isHindi
                      ? 'लॉट नंबर और एक्सपायरी डेट दर्ज करें ताकि ऑटो-छूट और ट्रैकिंग चालू रहे:'
                      : 'Track expiry dates and automatic price markdowns for fresh lots:',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: prodCtrl,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'सामान का नाम' : 'Product Name',
                    hintText: isHindi ? 'जैसे: अमूल मक्खन 500g' : 'e.g. Amul Butter 500g',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: batchCtrl,
                  decoration: InputDecoration(
                    labelText: isHindi ? 'लॉट / बैच नंबर' : 'Batch / Lot Number',
                    hintText: 'e.g. LOT-2026-MAY',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isHindi ? 'मात्रा' : 'Quantity',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: mrpCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'MRP (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isHindi ? 'खरीद लागत (₹)' : 'Purchase Cost (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogCtx,
                      initialDate: selectedExpiry,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) {
                      setState(() => selectedExpiry = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isHindi ? 'एक्सपायरी डेट:' : 'Expiry Date:',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(selectedExpiry),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 10.0;
                final mrp = double.tryParse(mrpCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                final ok = await context.read<BatchExpiryController>().createBatch(
                      productId: 'PROD-LOT-${DateTime.now().millisecondsSinceEpoch}',
                      productName: prodCtrl.text.trim(),
                      batchNumber: batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : 'BATCH-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      expiryDate: selectedExpiry,
                      initialQuantity: qty,
                      purchaseCost: cost,
                      mrp: mrp,
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Text(isHindi ? 'लॉट जोड़ें' : 'Add Batch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchCtrl = context.watch<BatchExpiryController>();
    final prodCtrl = context.watch<ProductController>();

    // Make sure inventory products are synced if they updated
    if (batchCtrl.inventoryProducts.length != prodCtrl.products.length && prodCtrl.products.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) batchCtrl.syncInventoryProducts(prodCtrl.products);
      });
    }

    final isHindi = context.isHindi;
    final totalCount = batchCtrl.totalCount;
    final expiredCount = batchCtrl.expiredCount;
    final criticalCount = batchCtrl.criticalCount;
    final warningCount = batchCtrl.warningCount;
    final upcomingCount = batchCtrl.upcomingCount;

    final filteredItems = batchCtrl.getFilteredItems(
      filter: _selectedFilter,
      searchQuery: _searchCtrl.text,
      category: _selectedCategory,
      sortOrder: _sortOrder,
    );

    return Scaffold(
      backgroundColor: context.colorSurfaceSubtle,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/merchant/inventory'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? 'एक्सपायरी रडार' : 'Batch & Expiry Radar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: context.colorTextPrimary),
            ),
            Text(
              isHindi ? 'दुकान के सभी एक्सपायरी उत्पाद ($totalCount सामान)' : 'Store Expiry Tracker ($totalCount items)',
              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
            ),
          ],
        ),
        backgroundColor: context.colorSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: isHindi ? 'नया सामान ट्रैक करें' : 'Track Product Expiry',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
            onPressed: _showTrackExistingProductSheet,
          ),
          IconButton(
            tooltip: isHindi ? 'ताज़ा करें' : 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: context.colorTextPrimary, size: 22),
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          isHindi ? '+ सामान / लॉट जोड़ें' : '+ Track Expiry',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                    ),
                    title: Text(
                      isHindi ? 'दुकान के सामान पर एक्सपायरी डेट सेट करें' : 'Set Expiry on Shop Product',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isHindi ? 'इन्वेंट्री के किसी भी सामान को एक्सपायरी ट्रैकर में जोड़ें' : 'Select any product from inventory to track',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTrackExistingProductSheet();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0284C7)),
                    ),
                    title: Text(
                      isHindi ? 'नया बैच / लॉट नंबर रजिस्टर करें' : 'Register New Batch Lot',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isHindi ? 'लॉट नंबर, खरीद लागत और एक्सपायरी के साथ जोड़ें' : 'Track lots with custom batch number and cost',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddBatchDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // 1. Metric Badges Row
          Container(
            color: context.colorSurface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricChip(
                    label: isHindi ? 'सभी' : 'All',
                    count: totalCount,
                    isSelected: _selectedFilter == 'all',
                    color: AppColors.primary,
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    label: isHindi ? '🔴 एक्सपायर' : '🔴 Expired',
                    count: expiredCount,
                    isSelected: _selectedFilter == 'expired',
                    color: const Color(0xFFDC2626),
                    onTap: () => setState(() => _selectedFilter = 'expired'),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    label: isHindi ? '🟠 7 दिन' : '🟠 7 Days',
                    count: criticalCount,
                    isSelected: _selectedFilter == '7_days',
                    color: const Color(0xFFEA580C),
                    onTap: () => setState(() => _selectedFilter = '7_days'),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    label: isHindi ? '🟡 30 दिन' : '🟡 30 Days',
                    count: warningCount,
                    isSelected: _selectedFilter == '30_days',
                    color: const Color(0xFFD97706),
                    onTap: () => setState(() => _selectedFilter = '30_days'),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    label: isHindi ? '🟢 आगामी' : '🟢 Upcoming',
                    count: upcomingCount,
                    isSelected: _selectedFilter == 'safe',
                    color: const Color(0xFF16A34A),
                    onTap: () => setState(() => _selectedFilter = 'safe'),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.colorBorder),

          // 2. Search & Sort Bar
          Container(
            color: context.colorSurface,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colorBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 18, color: context.colorTextMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: isHindi ? 'सामान का नाम या बारकोड खोजें...' : 'Search name or barcode...',
                              hintStyle: TextStyle(fontSize: 12, color: context.colorTextMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            child: Icon(Icons.close_rounded, size: 16, color: context.colorTextMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: _sortOrder,
                  tooltip: isHindi ? 'क्रम बदलें' : 'Sort',
                  icon: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, size: 16, color: context.colorTextPrimary),
                        const SizedBox(width: 4),
                        Text(
                          isHindi ? 'क्रम' : 'Sort',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (val) => setState(() => _sortOrder = val),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'expiry_asc',
                      child: Text(isHindi ? '⏳ जल्द एक्सपायर पहले' : '⏳ Earliest Expiry First'),
                    ),
                    PopupMenuItem(
                      value: 'stock_desc',
                      child: Text(isHindi ? '📦 ज्यादा स्टॉक पहले' : '📦 Highest Stock First'),
                    ),
                    PopupMenuItem(
                      value: 'name_asc',
                      child: Text(isHindi ? '🔤 नाम (A से Z)' : '🔤 Name (A-Z)'),
                    ),
                    PopupMenuItem(
                      value: 'expiry_desc',
                      child: Text(isHindi ? '📅 बाद में एक्सपायर' : '📅 Furthest Expiry First'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colorBorder),

          // 3. Expiry Items List or Clean Empty State
          Expanded(
            child: batchCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : totalCount == 0
                    ? _buildZeroTrackedState(context, isHindi)
                    : filteredItems.isEmpty
                        ? _buildNoFilteredItemsState(context, isHindi)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = filteredItems[idx];
                              return _buildExpiryProductCard(context, item, isHindi);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The Expiry Product Card with Live Visual Urgency and 1-Tap Retail Actions
  Widget _buildExpiryProductCard(BuildContext context, ExpiryTrackedItem item, bool isHindi) {
    Color urgencyColor;
    String urgencyLabel;

    if (item.isExpired) {
      urgencyColor = const Color(0xFFDC2626);
      urgencyLabel = isHindi
          ? '🔴 एक्सपायर (${item.daysRemaining.abs()} दिन पहले)'
          : '🔴 EXPIRED (${item.daysRemaining.abs()}d ago)';
    } else if (item.daysRemaining == 0) {
      urgencyColor = const Color(0xFFDC2626);
      urgencyLabel = isHindi ? '⚠️ आज ही एक्सपायर!' : '⚠️ EXPIRES TODAY!';
    } else if (item.daysRemaining <= 7) {
      urgencyColor = const Color(0xFFEA580C);
      urgencyLabel = isHindi ? '🟠 गंभीर (${item.daysRemaining} दिन बाकी)' : '🟠 CRITICAL (${item.daysRemaining}d left)';
    } else if (item.daysRemaining <= 30) {
      urgencyColor = const Color(0xFFD97706);
      urgencyLabel = isHindi ? '🟡 चेतावनी (${item.daysRemaining} दिन बाकी)' : '🟡 WARNING (${item.daysRemaining}d left)';
    } else {
      urgencyColor = const Color(0xFF16A34A);
      urgencyLabel = isHindi ? '🟢 सुरक्षित (${item.daysRemaining} दिन)' : '🟢 SAFE (${item.daysRemaining}d)';
    }

    final formattedDate = DateFormat('dd MMM yyyy').format(item.expiryDate);

    return InkWell(
      onTap: () {
        if (item.product != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: item.product!),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgencyColor.withValues(alpha: item.isExpired || item.daysRemaining <= 7 ? 0.45 : 0.2),
            width: item.isExpired || item.daysRemaining <= 7 ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Product Name + Urgency Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.isExpired ? Icons.event_busy_rounded : Icons.hourglass_top_rounded,
                    color: urgencyColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.colorTextPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.category.isNotEmpty) ...[
                            Text(
                              item.category,
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                            ),
                            Text(' • ', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                          ],
                          if (item.batchNumber != null)
                            Text(
                              'लॉट #${item.batchNumber}',
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                            )
                          else if (item.barcode.isNotEmpty)
                            Text(
                              item.barcode,
                              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    urgencyLabel,
                    style: TextStyle(color: urgencyColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: context.colorBorder.withValues(alpha: 0.6)),
            const SizedBox(height: 8),

            // Middle Row: Expiry Date + Store Stock In Hand + Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      '${isHindi ? "एक्सपायरी" : "Exp"}: $formattedDate',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  '${isHindi ? "स्टॉक" : "Stock"}: ${item.stockQuantity.toStringAsFixed(0)} ${item.unit}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: item.stockQuantity > 0 ? context.colorTextPrimary : const Color(0xFFDC2626),
                  ),
                ),
                Text(
                  '₹${item.mrp.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),

            if (item.markdownDiscount > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isHindi ? "सक्रिय छूट" : "Active Discount"}: ${item.markdownDiscount.toStringAsFixed(0)}% OFF',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Action Buttons Bar
            Row(
              children: [
                // 1. Add replacement to Mandi List
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: AppColors.primary),
                    label: Text(
                      isHindi ? 'मंडी में जोड़ें' : 'Add to Mandi',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: () => _showAddToMandiDialog(item),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Clearance Markdown Discount
                if (item.daysRemaining <= 30) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.discount_rounded, size: 14),
                      label: Text(
                        isHindi ? 'छूट लगाएं' : 'Markdown',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showClearanceDiscountDialog(item),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 3. Edit Expiry Date
                InkWell(
                  onTap: () => _updateExpiryDate(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: Icon(Icons.edit_calendar_rounded, size: 16, color: context.colorTextPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // State when zero products in shop have an expiry date set
  Widget _buildZeroTrackedState(BuildContext context, bool isHindi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              isHindi ? 'दुकान के किसी भी सामान पर एक्सपायरी दर्ज नहीं है' : 'No products tracked with expiry date',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'जब आप दुकान में दूध, ब्रेड, किराना या दवाइयाँ जोड़ते हैं, तो उनकी एक्सपायरी डेट डालें। वे सभी सामान यहाँ अपने आप ट्रैक होंगे और नुकसान होने से बचेंगे!'
                  : 'Add expiry dates to perishable items like dairy, bakery, FMCG, and medicines. They will automatically be tracked here with smart alerts!',
              style: TextStyle(fontSize: 12.5, color: context.colorTextMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                isHindi ? 'दुकान के सामान पर एक्सपायरी जोड़ें' : 'Set Expiry on Shop Products',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _showTrackExistingProductSheet,
            ),
          ],
        ),
      ),
    );
  }

  // State when the active filter returned 0 results
  Widget _buildNoFilteredItemsState(BuildContext context, bool isHindi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, size: 44, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 14),
            Text(
              isHindi ? '🎉 इस फ़िल्टर में कोई एक्सपायरी सामान नहीं है!' : 'No items found matching this filter!',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isHindi ? 'आपकी दुकान का यह स्टॉक बिल्कुल सुरक्षित है।' : 'Your store stock is fresh and safe.',
              style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.filter_list_off_rounded, size: 16),
              label: Text(isHindi ? 'सभी एक्सपायरी उत्पाद देखें' : 'View All Tracked Products'),
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                  _searchCtrl.clear();
                  _selectedCategory = 'All';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
