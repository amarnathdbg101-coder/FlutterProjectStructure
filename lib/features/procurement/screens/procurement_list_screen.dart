import 'dart:convert' show base64Encode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../dashboard/repositories/ai_repository.dart';
import '../../products/controllers/product_controller.dart';
import '../../products/models/product_model.dart';
import '../../products/widgets/color_shade_selector.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Detects whether an item has an associated Indian textile color shade
  ColorShadeModel? _detectItemShade(ProcurementItemModel item) {
    if (!isColorCriticalProduct(category: item.category, name: item.name)) return null;
    final combined = '${item.name} ${item.notes}'.toLowerCase();
    for (final shade in kIndianTextileShadeRegistry) {
      if (combined.contains(shade.shadeName.toLowerCase()) ||
          (shade.hindiName.isNotEmpty && combined.contains(shade.hindiName.toLowerCase()))) {
        return shade;
      }
    }
    return null;
  }

  /// 1-Tap WhatsApp PO direct to a specific wholesaler/dealer
  Future<void> _messageDealerWhatsApp(BuildContext context, ProcurementItemModel item) async {
    final clean = item.dealerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final phone = clean.length == 10 ? '91$clean' : clean;
    final msg = 'Namaste ${item.dealerName.isNotEmpty ? item.dealerName : ""},\n'
        'Hume yeh wholesale item chahiye:\n'
        '• *${item.name}*\n'
        '• Matra (Qty): *${item.qty}*\n'
        '${item.estimatedPrice > 0 ? "• Target Rate: ₹${item.estimatedPrice.toStringAsFixed(0)}\n" : ""}'
        '${item.notes.isNotEmpty ? "• Note: ${item.notes}\n" : ""}'
        'Kripya stock availability aur rate confirm karein. Dhanyawad!';
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.isHindi ? 'व्हाट्सएप नहीं खोला जा सका' : 'Cannot launch WhatsApp')),
      );
    }
  }

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
        if (item.notes.toLowerCase().contains('shade')) {
          text += '   • 🎨 *${item.notes}*\n';
        } else {
          text += '   • Note: ${item.notes}\n';
        }
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

  /// Intelligently infers standard Indian Mandi wholesale reorder unit from product base unit
  String _buildDefaultWholesaleUnit(String productUnit) {
    final clean = productUnit.toLowerCase().trim();
    if (clean == 'l' || clean == 'litre' || clean == 'liter' || clean == 'ml') {
      return 'पेटी / बॉक्स (Box)';
    } else if (clean == 'kg' || clean == 'kilo' || clean == 'gram' || clean == 'g') {
      return 'बोरी (Bags)';
    } else if (clean == 'pack' || clean == 'pkt' || clean == 'packet') {
      return 'कार्टन (Carton)';
    } else if (clean == 'box') {
      return 'पेटी / बॉक्स (Box)';
    } else if (clean == 'dozen' || clean == 'dzn') {
      return 'दर्जन (Dzn)';
    }
    return 'पेटी / बॉक्स (Box)';
  }

  /// 📷 1-Tap Barcode Scanner for Mandi Sourcing:
  /// Supports both Single-Item Confirmation and Continuous Rapid Multi-Scan mode.
  Future<void> _openBarcodeScannerForMandi(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController, {
    bool continuous = false,
  }) async {
    MobileBarcodeScannerDialog.show(
      context,
      title: continuous
          ? (context.isHindi ? '⚡ लगातार बारकोड स्कैन (सुपरफास्ट)' : 'Rapid Multi-Scan Mode')
          : (context.isHindi ? 'मंडी सामान बारकोड स्कैनर' : 'Scan Product for Mandi'),
      subtitle: continuous
          ? (context.isHindi
              ? 'खाली डिब्बों या पैकेटों को एक-एक कर स्कैन करते जाएं — सीधे मंडी लिस्ट में जुड़ता जाएगा'
              : 'Scan barcodes back-to-back — directly auto-added to Mandi list')
          : (context.isHindi
              ? 'दुकान के सामान का बारकोड स्कैन करें और तुरंत रीस्टॉक लिस्ट में जोड़ें'
              : 'Scan barcode of low-stock item to add directly to Mandi list'),
      autoCloseOnSuccess: !continuous,
      onBarcodeScanned: (barcode) async {
        final clean = barcode.trim();
        if (clean.isEmpty) return false;

        final prod = await prodController.findProductByBarcode(clean);
        if (!context.mounted) return true;

        if (prod != null) {
          if (continuous) {
            final defaultUnit = _buildDefaultWholesaleUnit(prod.unit);
            final double defaultRate = prod.costPrice > 0 ? prod.costPrice : (prod.price > 0 ? prod.price * 0.85 : 0.0);
            final int reorderQty = prod.stock == 0 ? 5 : (prod.stock <= 3 ? 3 : 1);
            controller.addItem(
              name: prod.name,
              qty: '$reorderQty $defaultUnit',
              category: prod.category.isNotEmpty ? prod.category : 'General Store',
              estimatedPrice: defaultRate,
              notes: prod.barcode.isNotEmpty ? 'Barcode: ${prod.barcode}' : '',
            );
            try {
              HapticFeedback.mediumImpact();
            } catch (_) {}
            return true;
          } else {
            _showQuickAddFromProductSheet(context, controller, prod);
            return true;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.isHindi
                    ? 'बारकोड $clean दुकान स्टॉक में नहीं मिला, विवरण दर्ज करें'
                    : 'Barcode $clean not found in store stock',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          if (!continuous) {
            _showAddEditSourcingItemSheet(
              context,
              controller,
              prodController,
              initialBarcode: clean,
            );
          }
          return false;
        }
      },
    );
  }

  /// 🔍 Select from Shop Inventory Sheet:
  /// Allows searching store catalog, filtering low-stock products, or multi-selecting in bulk
  void _openShopProductPickerForMandi(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return _ShopProductPickerSheet(
          products: prodController.products,
          onProductSelected: (prod) {
            Navigator.pop(sheetCtx);
            _showQuickAddFromProductSheet(context, controller, prod);
          },
          onProductsBatchSelected: (batch) {
            Navigator.pop(sheetCtx);
            for (final prod in batch) {
              final defaultUnit = _buildDefaultWholesaleUnit(prod.unit);
              final double defaultRate = prod.costPrice > 0 ? prod.costPrice : (prod.price > 0 ? prod.price * 0.85 : 0.0);
              final int reorderQty = prod.stock == 0 ? 5 : (prod.stock <= 3 ? 3 : 1);
              controller.addItem(
                name: prod.name,
                qty: '$reorderQty $defaultUnit',
                category: prod.category.isNotEmpty ? prod.category : 'General Store',
                estimatedPrice: defaultRate,
                notes: prod.barcode.isNotEmpty ? 'Barcode: ${prod.barcode}' : '',
              );
            }
            try {
              HapticFeedback.mediumImpact();
            } catch (_) {}
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.isHindi
                            ? '✓ ${batch.length} सामान मंडी खरीद लिस्ट में जुड़ गए!'
                            : '✓ ${batch.length} items added to Mandi List!',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onScanBarcode: () {
            Navigator.pop(sheetCtx);
            _openBarcodeScannerForMandi(context, controller, prodController);
          },
        );
      },
    );
  }

  /// ⚡ Effortless 1-Tap Quick Add Confirmation Sheet for Store Products
  /// Enhanced with Quantity Stepper, Quick Presets (+1, +5, +10), Unit Pills & Restock Advice
  void _showQuickAddFromProductSheet(
    BuildContext context,
    ProcurementController controller,
    ProductModel prod,
  ) {
    final defaultUnit = _buildDefaultWholesaleUnit(prod.unit);
    final int initialSuggestedQty = prod.stock == 0 ? 5 : (prod.stock <= 3 ? 3 : 1);
    final TextEditingController qtyCtrl = TextEditingController(text: '$initialSuggestedQty');
    final double defaultRate = prod.costPrice > 0 ? prod.costPrice : (prod.price > 0 ? prod.price * 0.85 : 0.0);
    final TextEditingController rateCtrl = TextEditingController(
      text: defaultRate > 0 ? defaultRate.toStringAsFixed(0) : '',
    );
    String selectedUnit = defaultUnit;

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
            final double qtyVal = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
            final double rateVal = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
            final double totalEst = qtyVal * rateVal;
            final bool isLowStock = prod.stock <= 5;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: ctx.colorBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header with Product Info & Stock Pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: (isLowStock ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: isLowStock ? AppColors.error : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: ctx.colorTextPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (prod.category.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ctx.colorSurfaceSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        prod.category,
                                        style: TextStyle(fontSize: 11, color: ctx.colorTextMuted, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLowStock ? AppColors.errorLight : AppColors.successLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ctx.isHindi
                                          ? 'दुकान में स्टॉक: ${prod.stock} ${prod.unit}'
                                          : 'Shop Stock: ${prod.stock} ${prod.unit}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isLowStock ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: ctx.colorTextMuted),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),

                    // Low Stock Alert & 1-Tap Reorder Suggestion
                    if (isLowStock) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ctx.isHindi
                                    ? 'स्टॉक बहुत कम है! थोक में कम से कम $initialSuggestedQty $selectedUnit मंगाएं'
                                    : 'Stock is critical! Reorder at least $initialSuggestedQty $selectedUnit',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Quantity Stepper Row
                    Row(
                      children: [
                        // Minus button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: ctx.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ctx.colorBorder),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove_rounded, size: 20),
                            onPressed: () {
                              final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                              if (cur > 1) {
                                qtyCtrl.text = '${cur - 1}';
                                try {
                                  HapticFeedback.selectionClick();
                                } catch (_) {}
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Number field
                        Expanded(
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: ctx.isHindi ? 'थोक मात्रा *' : 'Wholesale Qty *',
                              hintText: '1',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Plus button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: ctx.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ctx.colorBorder),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            onPressed: () {
                              final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                              qtyCtrl.text = '${cur + 1}';
                              try {
                                HapticFeedback.selectionClick();
                              } catch (_) {}
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Quantity Increment Pills (+1, +2, +5, +10, +25)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            ctx.isHindi ? 'त्वरित जोड़ें: ' : 'Quick Add: ',
                            style: TextStyle(fontSize: 11.5, color: ctx.colorTextMuted, fontWeight: FontWeight.w600),
                          ),
                          ...[1, 2, 5, 10, 20, 50].map((preset) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  final cur = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                                  qtyCtrl.text = '${cur + preset}';
                                  try {
                                    HapticFeedback.selectionClick();
                                  } catch (_) {}
                                  setModalState(() {});
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '+$preset',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Wholesale Unit Fast Pills
                    Text(
                      ctx.isHindi ? 'थोक इकाई चुनें:' : 'Select Wholesale Unit:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ctx.colorTextMuted),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'पेटी / बॉक्स (Box)',
                          'बोरी (Bags)',
                          'दर्जन (Dzn)',
                          'पैकेट (Pkt)',
                          'लीटर (Ltr)',
                          'kg',
                          'कार्टन (Carton)',
                          'पीस (Pcs)',
                        ].map((u) {
                          final isSelected = selectedUnit == u;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(u, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : ctx.colorTextPrimary),
                              backgroundColor: ctx.colorSurfaceSubtle,
                              onSelected: (_) {
                                try {
                                  HapticFeedback.selectionClick();
                                } catch (_) {}
                                setModalState(() => selectedUnit = u);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Target Rate Input
                    TextFormField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: ctx.isHindi ? 'अनुमानित थोक दर (₹ प्रति यूनिट)' : 'Estimated Wholesale Rate (₹/unit)',
                        hintText: '0',
                        prefixText: '₹ ',
                        helperText: prod.costPrice > 0 ? (ctx.isHindi ? 'पिछली लागत: ₹${prod.costPrice.toStringAsFixed(0)}' : 'Last Cost: ₹${prod.costPrice.toStringAsFixed(0)}') : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Summary banner
                    if (totalEst > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.successLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ctx.isHindi ? 'अनुमानित कुल बजट:' : 'Estimated Total Budget:',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₹${totalEst.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Action Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(
                        ctx.isHindi ? '✓ मंडी लिस्ट में जोड़ें' : '✓ Add to Mandi List',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final q = qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim();
                        final formattedQty = '$q $selectedUnit';
                        final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;

                        controller.addItem(
                          name: prod.name,
                          qty: formattedQty,
                          category: prod.category.isNotEmpty ? prod.category : 'General Store',
                          estimatedPrice: rate,
                          notes: prod.barcode.isNotEmpty ? 'Barcode: ${prod.barcode}' : '',
                        );

                        try {
                          HapticFeedback.mediumImpact();
                        } catch (_) {}

                        Navigator.pop(sheetCtx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.isHindi
                                  ? '✓ "${prod.name}" ($formattedQty) मंडी लिस्ट में जुड़ गया!'
                                  : '✓ "${prod.name}" ($formattedQty) added to Mandi List!',
                            ),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 📸 AI Mandi Sourcing Vision Scanner:
  /// Captures camera photo of low-stock products, cartons, or shelves and
  /// automatically infers product identity, commercial wholesale unit, and Mandi market rates.
  Future<void> _openAiMandiScanner(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController,
  ) async {
    final picker = ImagePicker();

    // Source picker sheet
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Material(
        color: sheetCtx.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF673AB7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF673AB7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sheetCtx.isHindi ? 'AI मंडी खरीद स्कैन' : 'AI Mandi Sourcing Scan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sheetCtx.colorTextPrimary,
                            ),
                          ),
                          Text(
                            sheetCtx.isHindi
                                ? 'कम स्टॉक सामान या डिब्बे की फोटो लें'
                                : 'Snap low-stock item or empty shelf/carton',
                            style: TextStyle(fontSize: 12, color: sheetCtx.colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  ),
                  title: Text(sheetCtx.isHindi ? 'कैमरा से फोटो लें' : 'Take Photo with Camera',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(sheetCtx.isHindi ? 'दुकान में रखे सामान का सीधा फोटो' : 'Snap product on shelf/counter',
                      style: TextStyle(fontSize: 11.5, color: sheetCtx.colorTextMuted)),
                  onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF00B4D8)),
                  ),
                  title: Text(sheetCtx.isHindi ? 'गैलरी से तस्वीर चुनें' : 'Choose from Gallery',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(sheetCtx.isHindi ? 'पहले से ली गई फोटो से विश्लेषण' : 'Select existing photo',
                      style: TextStyle(fontSize: 11.5, color: sheetCtx.colorTextMuted)),
                  onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    try {
      final XFile? picked = await picker.pickImage(source: source);
      if (picked == null || !context.mounted) return;

      // Show sleek loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) => Dialog(
          backgroundColor: dlgCtx.colorSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF673AB7)),
                ),
                const SizedBox(height: 20),
                Text(
                  dlgCtx.isHindi ? '✨ AI मंडी खरीद स्कैनिंग...' : '✨ AI Mandi Vision Analyzing...',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: dlgCtx.colorTextPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  dlgCtx.isHindi
                      ? 'थोक खरीदारी मात्रा और मंडी दरों का विश्लेषण हो रहा है...'
                      : 'Extracting wholesale package sizes & estimated Mandi rates...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: dlgCtx.colorTextMuted),
                ),
              ],
            ),
          ),
        ),
      );

      // Fast image compression for fast network upload (800px, 75% quality saves ~75% bandwidth & speeds up AI inference)
      final (_, normalizedBytes) = await normalizeXFile(picked, maxDimension: 800, quality: 75);
      final base64String = base64Encode(normalizedBytes);
      final mime = picked.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final aiRepo = AiRepository();
      final res = await aiRepo.scanMandiItem(imageBase64: base64String, mimeType: mime);

      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!context.mounted) return;

      if (!res.success || res.data == null) {
        debugPrint('Mandi scan failed: ${res.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message?.isNotEmpty == true
                ? res.message!
                : (context.isHindi ? 'AI से सामान का विश्लेषण नहीं हो सका' : 'Could not analyze items from photo')),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final rawItems = res.data!['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.isHindi
                ? 'तस्वीर में कोई कम स्टॉक सामान नहीं पहचाना जा सका। कृपया स्पष्ट तस्वीर लें।'
                : 'No restock items detected in image. Please take a clearer photo.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final List<Map<String, dynamic>> detectedItems = rawItems
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      // Show the AI Sourcing Proposal review sheet
      if (context.mounted) {
        _showAiMandiProposalSheet(context, controller, prodController, detectedItems);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.isHindi ? "त्रुटि:" : "Error:"} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Displays the interactive AI Sourcing Proposal review sheet allowing the merchant
  /// to verify or tweak wholesale quantities, rates, and 1-tap add to Mandi Sheet.
  void _showAiMandiProposalSheet(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController,
    List<Map<String, dynamic>> detectedItems,
  ) {
    // Wrap detected items into stateful proposal items
    final List<_AiProposalItemState> proposalStates = detectedItems.map((item) {
      final String rawName = item['name']?.toString().trim() ?? '';
      final String rawCategory = item['category']?.toString().trim() ?? 'General Store';
      final String rawWholesaleQty = item['wholesale_qty']?.toString().trim() ?? '1';
      final String rawUnit = item['wholesale_unit']?.toString().trim() ?? _kWholesaleUnits.first;
      final double estRate = double.tryParse(item['estimated_wholesale_rate']?.toString() ?? '0') ?? 0.0;
      final String rawNotes = item['notes']?.toString().trim() ?? '';

      // Match with inventory products
      ProductModel? matchedProduct;
      try {
        final q = rawName.toLowerCase();
        matchedProduct = prodController.products.firstWhere(
          (p) => p.name.toLowerCase().contains(q) || q.contains(p.name.toLowerCase()),
        );
      } catch (_) {
        matchedProduct = null;
      }

      // Extract numeric qty part from rawWholesaleQty if available
      String qtyNum = '1';
      String unitMatch = _kWholesaleUnits.firstWhere(
        (u) => u.toLowerCase().contains(rawUnit.toLowerCase()) || rawUnit.toLowerCase().contains(u.toLowerCase()),
        orElse: () => _kWholesaleUnits.first,
      );

      final parts = rawWholesaleQty.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && double.tryParse(parts[0]) != null) {
        qtyNum = parts[0];
      }

      // Parse color details ONLY if product is a color-critical trade item (Apparel, Textiles, Cosmetics, etc.)
      final isColorCritical = isColorCriticalProduct(category: rawCategory, name: rawName);
      ColorShadeModel? colorShade;
      List<ColorShadeModel> colorAlternatives = [];

      if (isColorCritical) {
        if (item['color_details'] is Map) {
          final cd = Map<String, dynamic>.from(item['color_details'] as Map);
          if (cd['primary_shade'] is Map) {
            colorShade = ColorShadeModel.fromMap(Map<String, dynamic>.from(cd['primary_shade'] as Map));
          }
          if (cd['alternatives'] is List) {
            colorAlternatives = (cd['alternatives'] as List)
                .whereType<Map>()
                .map((m) => ColorShadeModel.fromMap(Map<String, dynamic>.from(m)))
                .toList();
          }
        } else {
          final lowerN = rawName.toLowerCase();
          colorShade = kIndianTextileShadeRegistry.firstWhere(
            (s) => lowerN.contains(s.shadeName.toLowerCase()) || lowerN.contains(s.hindiName.toLowerCase()),
            orElse: () => kIndianTextileShadeRegistry.first,
          );
        }
      }

      return _AiProposalItemState(
        nameCtrl: TextEditingController(text: rawName),
        qtyCtrl: TextEditingController(text: qtyNum),
        priceCtrl: TextEditingController(text: estRate > 0 ? estRate.toStringAsFixed(0) : ''),
        notesCtrl: TextEditingController(text: rawNotes),
        category: CategoryRegistry.canonicalCategories.contains(rawCategory) ? rawCategory : 'General Store',
        unit: unitMatch,
        matchedProduct: matchedProduct,
        isSelected: true,
        colorShade: colorShade,
        colorAlternatives: colorAlternatives,
      );
    }).toList();

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
            final selectedCount = proposalStates.where((s) => s.isSelected).length;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: ctx.colorBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Sheet Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF673AB7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFF673AB7)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ctx.isHindi ? '✨ AI द्वारा पहचाना गया सामान' : '✨ AI Detected Wholesale Items',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ctx.colorTextPrimary,
                                  ),
                                ),
                                Text(
                                  ctx.isHindi
                                      ? 'समीक्षा करें और 1-टैप में मंडी लिस्ट में जोड़ें'
                                      : 'Review quantities & add to Mandi sheet in 1-tap',
                                  style: TextStyle(fontSize: 11.5, color: ctx.colorTextMuted),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final allSelected = proposalStates.every((s) => s.isSelected);
                              setModalState(() {
                                for (final s in proposalStates) {
                                  s.isSelected = !allSelected;
                                }
                              });
                            },
                            child: Text(
                              proposalStates.every((s) => s.isSelected)
                                  ? (ctx.isHindi ? 'सभी हटाएं' : 'Deselect All')
                                  : (ctx.isHindi ? 'सभी चुनें' : 'Select All'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF673AB7)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: ctx.colorTextMuted, size: 20),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Proposal Items List
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        itemCount: proposalStates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (itemCtx, index) {
                          final state = proposalStates[index];
                          final matched = state.matchedProduct;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: state.isSelected
                                  ? const Color(0xFF673AB7).withValues(alpha: 0.04)
                                  : ctx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: state.isSelected
                                    ? const Color(0xFF673AB7).withValues(alpha: 0.4)
                                    : ctx.colorBorder,
                                width: state.isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Item Header with Checkbox
                                Row(
                                  children: [
                                    Checkbox(
                                      value: state.isSelected,
                                      activeColor: const Color(0xFF673AB7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setModalState(() {
                                          state.isSelected = val ?? false;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: state.nameCtrl,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: ctx.colorTextPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          hintText: ctx.isHindi ? 'सामान का नाम' : 'Item Name',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Matched Inventory Info Banner
                                if (matched != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (matched.stock <= 5 ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          matched.stock <= 5 ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                          size: 14,
                                          color: matched.stock <= 5 ? AppColors.warning : AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            ctx.isHindi
                                                ? 'दुकान में स्टॉक: ${matched.stock} ${matched.unit} बचा है'
                                                : 'Current Shop Stock: ${matched.stock} ${matched.unit} left',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: matched.stock <= 5 ? AppColors.warning : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 10),

                                // Quantity + Unit + Rate Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Quantity
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: state.qtyCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          labelText: ctx.isHindi ? 'मात्रा' : 'Qty',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  final val = double.tryParse(state.qtyCtrl.text) ?? 1.0;
                                                  if (val > 1) {
                                                    state.qtyCtrl.text = (val - 1).toInt().toString();
                                                    setModalState(() {});
                                                  }
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                                  child: Icon(Icons.remove_rounded, size: 16),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  final val = double.tryParse(state.qtyCtrl.text) ?? 1.0;
                                                  state.qtyCtrl.text = (val + 1).toInt().toString();
                                                  setModalState(() {});
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                                  child: Icon(Icons.add_rounded, size: 16, color: Color(0xFF673AB7)),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Wholesale Unit Dropdown
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _kWholesaleUnits.contains(state.unit) ? state.unit : _kWholesaleUnits.first,
                                        isExpanded: true,
                                        style: TextStyle(fontSize: 12, color: ctx.colorTextPrimary, fontWeight: FontWeight.w500),
                                        decoration: InputDecoration(
                                          labelText: ctx.isHindi ? 'थोक यूनिट' : 'Unit',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        items: _kWholesaleUnits.map((u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u, overflow: TextOverflow.ellipsis),
                                        )).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setModalState(() => state.unit = val);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Est Wholesale Rate
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: state.priceCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          labelText: ctx.isHindi ? 'अनु. दर (₹)' : 'Est Rate (₹)',
                                          prefixText: '₹',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 🎨 Indian Color Shade Calibrator (Only for Color-Critical Products)
                                if (state.colorShade != null &&
                                    isColorCriticalProduct(category: state.category, name: state.nameCtrl.text)) ...[
                                  const SizedBox(height: 10),
                                  ColorShadeSelector(
                                    initialShade: state.colorShade!,
                                    alternatives: state.colorAlternatives,
                                    compact: true,
                                    onShadeSelected: (newShade) {
                                      setModalState(() {
                                        final oldShade = state.colorShade;
                                        state.colorShade = newShade;
                                        // Update name if old shade was in title
                                        if (oldShade != null && state.nameCtrl.text.contains(oldShade.shadeName)) {
                                          state.nameCtrl.text = state.nameCtrl.text.replaceAll(oldShade.shadeName, newShade.shadeName);
                                        }
                                        // Keep package size/notes intact without erasing it
                                        final cleanNotes = state.notesCtrl.text
                                            .replaceAll(RegExp(r'Shade:\s*[^•\n]+(•\s*)?', caseSensitive: false), '')
                                            .trim();
                                        if (cleanNotes.isNotEmpty) {
                                          state.notesCtrl.text = 'Shade: ${newShade.displayName} • $cleanNotes';
                                        } else {
                                          state.notesCtrl.text = 'Shade: ${newShade.displayName}';
                                        }
                                      });
                                    },
                                  ),
                                ],

                                // Sourcing Notes (if available)
                                if (state.notesCtrl.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '💡 ${state.notesCtrl.text}',
                                    style: TextStyle(fontSize: 11, color: ctx.colorTextMuted, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Action Bar with Live Budget Calculation
                    Builder(
                      builder: (_) {
                        final totalProposalBudget = proposalStates
                            .where((s) => s.isSelected)
                            .fold(0.0, (sum, s) => sum + (double.tryParse(s.priceCtrl.text.trim()) ?? 0.0));

                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: BoxDecoration(
                            color: ctx.colorSurface,
                            border: Border(top: BorderSide(color: ctx.colorBorder)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (totalProposalBudget > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ctx.isHindi ? 'चयनित कुल अनुमानित बजट:' : 'Total Estimated Budget:',
                                      style: TextStyle(fontSize: 12.5, color: ctx.colorTextMuted, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '₹${totalProposalBudget.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF673AB7)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF673AB7),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 2,
                                      ),
                                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                                      label: Text(
                                        ctx.isHindi
                                            ? '✓ $selectedCount सामान मंडी लिस्ट में जोड़ें'
                                            : '✓ Add $selectedCount Items to Mandi Sheet',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      onPressed: selectedCount == 0
                                          ? null
                                          : () async {
                                              final selectedItems = proposalStates.where((s) => s.isSelected).toList();
                                              for (final s in selectedItems) {
                                                final name = s.nameCtrl.text.trim();
                                                if (name.isEmpty) continue;
                                                final qtyVal = s.qtyCtrl.text.trim().isEmpty ? '1' : s.qtyCtrl.text.trim();
                                                final combinedQty = '$qtyVal ${s.unit}'.trim();
                                                final estPrice = double.tryParse(s.priceCtrl.text.trim()) ?? 0.0;
                                                var notes = s.notesCtrl.text.trim();
                                                final isColorItem = isColorCriticalProduct(category: s.category, name: name);
                                                if (isColorItem && s.colorShade != null && !notes.toLowerCase().contains(s.colorShade!.shadeName.toLowerCase())) {
                                                  if (notes.isNotEmpty) {
                                                    notes = 'Shade: ${s.colorShade!.displayName} • $notes';
                                                  } else {
                                                    notes = 'Shade: ${s.colorShade!.displayName}';
                                                  }
                                                } else if (!isColorItem) {
                                                  // Ensure grocery/commodities do not carry random 'Shade:' notes
                                                  notes = notes.replaceAll(RegExp(r'Shade:\s*[^•\n]+(•\s*)?', caseSensitive: false), '').trim();
                                                }

                                                await controller.addItem(
                                                  name: name,
                                                  qty: combinedQty,
                                                  category: s.category,
                                                  estimatedPrice: estPrice,
                                                  notes: notes,
                                                );
                                              }

                                              if (sheetCtx.mounted) {
                                                Navigator.pop(sheetCtx);
                                              }

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            context.isHindi
                                                                ? '✓ ${selectedItems.length} सामान मंडी खरीद लिस्ट में जुड़ गए!'
                                                                : '✓ ${selectedItems.length} items added to Mandi Sourcing Sheet!',
                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor: AppColors.success,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  /// Opens the professional, structured Add/Edit Sourcing Item Sheet
  void _showAddEditSourcingItemSheet(
    BuildContext context,
    ProcurementController controller,
    ProductController prodController, {
    ProcurementItemModel? editItem,
    String? initialBarcode,
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
    final TextEditingController notesCtrl = TextEditingController(
      text: editItem?.notes ?? (initialBarcode != null ? 'Barcode: $initialBarcode' : ''),
    );

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
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
                                    tooltip: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Barcode',
                                    onPressed: () {
                                      MobileBarcodeScannerDialog.show(
                                        context,
                                        title: context.isHindi ? 'बारकोड स्कैन' : 'Scan Barcode',
                                        subtitle: context.isHindi ? 'सामान का बारकोड स्कैन करें' : 'Scan product barcode',
                                        autoCloseOnSuccess: true,
                                        onBarcodeScanned: (scannedCode) async {
                                          final cleanCode = scannedCode.trim();
                                          if (cleanCode.isEmpty) return false;
                                          final matched = await prodController.findProductByBarcode(cleanCode);
                                          if (matched != null) {
                                            fieldCtrl.text = matched.name;
                                            nameCtrl.text = matched.name;
                                            setModalState(() {
                                              if (CategoryRegistry.canonicalCategories.contains(matched.category)) {
                                                selectedCategory = matched.category;
                                              }
                                              if (matched.costPrice > 0) {
                                                priceCtrl.text = matched.costPrice.toStringAsFixed(0);
                                              } else if (matched.price > 0) {
                                                priceCtrl.text = matched.price.toStringAsFixed(0);
                                              }
                                              selectedUnit = _buildDefaultWholesaleUnit(matched.unit);
                                              notesCtrl.text = 'Barcode: $cleanCode';
                                            });
                                          } else {
                                            setModalState(() {
                                              notesCtrl.text = 'Barcode: $cleanCode';
                                            });
                                          }
                                          return true;
                                        },
                                      );
                                    },
                                  ),
                                  AppVoiceIconButton(
                                    controller: fieldCtrl,
                                    hint: context.isHindi ? 'सामान का नाम' : 'Item Name',
                                    onSubmitted: (val) {
                                      nameCtrl.text = val;
                                    },
                                  ),
                                ],
                              ),
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
                            suffixIcon: AppVoiceIconButton(
                              controller: notesCtrl,
                              hint: context.isHindi ? 'क्वालिटी नोट्स' : 'Quality Notes',
                            ),
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

    // Filter items based on active chip and instant search query
    final filteredItems = items.where((item) {
      if (_activeFilter == 'PENDING' && item.isCompleted) return false;
      if (_activeFilter == 'COMPLETED' && !item.isCompleted) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.name.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            item.dealerName.toLowerCase().contains(q) ||
            item.notes.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return MerchantShell(
      currentIndex: -1,
      showBottomNav: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_mandi_item_fab',
        elevation: 4,
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditSourcingItemSheet(context, controller, prodController),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
        label: Text(
          context.isHindi ? 'नया सामान जोड़ें' : 'Add Sourcing Item',
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
          // 1. Live In-App PDF Preview & Print Action
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 21, color: AppColors.primary),
            tooltip: context.isHindi ? 'PDF देखें व प्रिंट करें' : 'View & Print PDF',
            onPressed: () => controller.previewPdfSheet(context, shopName),
          ),

          // 2. Direct Share Action (WhatsApp, Bluetooth, etc.)
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF0D9488)),
            tooltip: context.isHindi ? 'मंडी लिस्ट शेयर करें' : 'Share Mandi Sheet',
            onPressed: () => controller.sharePdfSheet(context, shopName),
          ),

          // 3. More Options Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colorSurface,
            onSelected: (value) {
              if (value == 'preview_pdf') {
                controller.previewPdfSheet(context, shopName);
              } else if (value == 'share_pdf') {
                controller.sharePdfSheet(context, shopName);
              } else if (value == 'whatsapp') {
                _sendWhatsAppOrderSheet(context, items, shopName);
              } else if (value == 'refresh') {
                controller.refreshList();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.isHindi ? '✓ मंडी खरीद लिस्ट रीफ्रेश हो गई' : '✓ Mandi List Refreshed'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
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
              } else if (value == 'clear') {
                controller.clearAllCompleted();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.isHindi ? 'खरीदे जा चुके सामान हटा दिए गए' : 'Cleared bought items')),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'preview_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      ctx.isHindi ? 'PDF देखें व प्रिंट करें' : 'View & Print PDF',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'share_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.share_rounded, size: 18, color: Color(0xFF0D9488)),
                    const SizedBox(width: 10),
                    Text(
                      ctx.isHindi ? 'मंडी PDF शेयर करें' : 'Share PDF Sheet',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'whatsapp',
                child: Row(
                  children: [
                    const Icon(Icons.send_rounded, size: 18, color: Color(0xFF128C7E)),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('mandi_whatsapp_sheet'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: ctx.colorTextPrimary),
                    const SizedBox(width: 10),
                    Text(
                      ctx.isHindi ? 'रीफ्रेश करें' : 'Refresh',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                    ),
                  ],
                ),
              ),
              if (lowStockProducts.isNotEmpty)
                PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFE65100)),
                      const SizedBox(width: 10),
                      Text(
                        '${context.tr('mandi_import_low')} (${lowStockProducts.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
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

                      // Visual Procurement Progress Bar
                      if (controller.totalCount > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: controller.totalCount > 0 ? (controller.completedCount / controller.totalCount) : 0.0,
                            minHeight: 6,
                            backgroundColor: context.colorSurfaceSubtle,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                context.isHindi
                                    ? '${controller.completedCount} / ${controller.totalCount} खरीदा (${(controller.completedCount * 100 / (controller.totalCount > 0 ? controller.totalCount : 1)).toInt()}%)'
                                    : '${controller.completedCount} of ${controller.totalCount} bought (${(controller.completedCount * 100 / (controller.totalCount > 0 ? controller.totalCount : 1)).toInt()}%)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colorTextMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (controller.totalEstimatedBudget > 0)
                              Text(
                                context.isHindi
                                    ? '₹${controller.completedPurchasedExpense.toStringAsFixed(0)} खरीदा'
                                    : '₹${controller.completedPurchasedExpense.toStringAsFixed(0)} bought',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                          ],
                        ),
                      ],

                      // Low-Stock Quick Pill (Subtle & Compact, only if any exist)
                      if (lowStockProducts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCC80)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  context.isHindi
                                      ? '${lowStockProducts.length} सामान कम स्टॉक में हैं'
                                      : '${lowStockProducts.length} low-stock items in shop',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
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
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE65100),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    context.isHindi ? '+ ऑटो-इंपोर्ट' : '+ Auto-Import',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Unified Quick Sourcing Channels (Single Point of Entry, No Duplicates)
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Channel 1: Barcode Scanner
                          Expanded(
                            child: _buildSourcingActionCard(
                              context,
                              icon: Icons.qr_code_scanner_rounded,
                              label: context.isHindi ? 'बारकोड स्कैन' : 'Barcode',
                              sublabel: context.isHindi ? 'स्कैन करके जोड़ें' : 'Scan to Add',
                              color: AppColors.primary,
                              onTap: () => _openBarcodeScannerForMandi(context, controller, prodController),
                              onLongPress: () {
                                try {
                                  HapticFeedback.mediumImpact();
                                } catch (_) {}
                                _openBarcodeScannerForMandi(context, controller, prodController, continuous: true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Channel 2: Shop Inventory Picker
                          Expanded(
                            child: _buildSourcingActionCard(
                              context,
                              icon: Icons.inventory_2_outlined,
                              label: context.isHindi ? 'दुकान स्टॉक' : 'Shop Stock',
                              sublabel: context.isHindi ? 'सामान से चुनें' : 'Pick from Stock',
                              color: const Color(0xFF0D9488),
                              badge: lowStockProducts.isNotEmpty ? '${lowStockProducts.length}' : null,
                              onTap: () => _openShopProductPickerForMandi(context, controller, prodController),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Channel 3: AI Vision Scanner
                          Expanded(
                            child: _buildSourcingActionCard(
                              context,
                              icon: Icons.document_scanner_rounded,
                              label: context.isHindi ? 'AI विजन' : 'AI Vision',
                              sublabel: context.isHindi ? 'फोटो से थोक लिस्ट' : 'Photo Scan',
                              color: const Color(0xFF673AB7),
                              onTap: () => _openAiMandiScanner(context, controller, prodController),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. INSTANT SEARCH BAR (Customer Style Spacious & Speech-to-Text)
                if (items.isNotEmpty) ...[
                  AppSearchField(
                    controller: _searchCtrl,
                    hintText: context.isHindi
                        ? 'सामान, श्रेणी या डीलर खोजें...'
                        : 'Search items, category or wholesaler...',
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    onSubmitted: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. CLEAN FILTER CHIPS STRIP
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

                // 4. MANDI SOURCING CHECKLIST
                if (filteredItems.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.assignment_outlined,
                          size: 48,
                          color: context.colorTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? (context.isHindi ? 'कोई सामान नहीं मिला' : 'No matching items')
                              : (context.isHindi ? 'मंडी खरीद लिस्ट खाली है' : 'Sourcing list is empty'),
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? (context.isHindi ? '"$_searchQuery" के लिए कोई परिणाम नहीं। दूसरा नाम खोजें।' : 'No results for "$_searchQuery".')
                              : (context.isHindi
                                  ? 'निचे दिए गए "+ नया सामान जोड़ें" बटन से सामान जोड़ें!'
                                  : 'Tap "+ Add Item" below to start your sourcing checklist!'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
                        ),
                         if (_searchQuery.isEmpty) ...[
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
                        ] else ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: Text(context.isHindi ? 'खोज हटाएं' : 'Clear Search'),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        ],
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
                      final detectedShade = _detectItemShade(item);
                      return InkWell(
                        onTap: () => _showAddEditSourcingItemSheet(
                          context,
                          controller,
                          prodController,
                          editItem: item,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: AppCard(
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
                                  onChanged: (_) {
                                    try {
                                      HapticFeedback.lightImpact();
                                    } catch (_) {}
                                    controller.toggleItem(item.id);
                                  },
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
                                        if (detectedShade != null) ...[
                                          Tooltip(
                                            message: detectedShade.displayName,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: detectedShade.color,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 1.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.25),
                                                    blurRadius: 2.5,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
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

                              // Actions with comfortable 42px touch targets
                              if (item.dealerPhone.isNotEmpty)
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                                  padding: const EdgeInsets.all(8),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: Color(0xFF128C7E)),
                                  tooltip: context.isHindi ? 'डीलर को व्हाट्सएप' : 'WhatsApp Wholesaler',
                                  onPressed: () => _messageDealerWhatsApp(context, item),
                                ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, size: 20, color: context.colorTextMuted),
                                tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'Options',
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                onSelected: (val) {
                                  switch (val) {
                                    case 'edit':
                                      _showAddEditSourcingItemSheet(
                                        context,
                                        controller,
                                        prodController,
                                        editItem: item,
                                      );
                                      break;
                                    case 'call':
                                      _callDealer(item.dealerPhone);
                                      break;
                                    case 'delete':
                                      final removedItem = item;
                                      controller.removeItem(item.id);
                                      try {
                                        HapticFeedback.mediumImpact();
                                      } catch (_) {}
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.isHindi
                                                ? '"${removedItem.name}" लिस्ट से हटाया गया'
                                                : '"${removedItem.name}" removed',
                                          ),
                                          action: SnackBarAction(
                                            label: context.isHindi ? 'पूर्ववत (Undo)' : 'Undo',
                                            textColor: Colors.yellow,
                                            onPressed: () {
                                              controller.addItem(
                                                name: removedItem.name,
                                                qty: removedItem.qty,
                                                category: removedItem.category,
                                                estimatedPrice: removedItem.estimatedPrice,
                                                actualPrice: removedItem.actualPrice,
                                                dealerName: removedItem.dealerName,
                                                dealerPhone: removedItem.dealerPhone,
                                                notes: removedItem.notes,
                                              );
                                            },
                                          ),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 10),
                                        Text(ctx.isHindi ? 'विवरण बदलें' : 'Edit Item'),
                                      ],
                                    ),
                                  ),
                                  if (item.dealerPhone.isNotEmpty)
                                    PopupMenuItem<String>(
                                      value: 'call',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 18, color: AppColors.success),
                                          const SizedBox(width: 10),
                                          Text(ctx.isHindi ? 'डीलर को कॉल करें' : 'Call Wholesaler'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                        const SizedBox(width: 10),
                                        Text(ctx.isHindi ? 'लिस्ट से हटाएं' : 'Remove Item', style: const TextStyle(color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

  Widget _buildSourcingActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 21, color: color),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sublabel,
              style: TextStyle(fontSize: 9.5, color: context.colorTextMuted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

/// Holds interactive state for an AI proposed wholesale sourcing item in the review sheet.
class _AiProposalItemState {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController notesCtrl;
  final String category;
  String unit;
  final ProductModel? matchedProduct;
  bool isSelected;
  ColorShadeModel? colorShade;
  List<ColorShadeModel> colorAlternatives;

  _AiProposalItemState({
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.notesCtrl,
    required this.category,
    required this.unit,
    this.matchedProduct,
    this.isSelected = true,
    this.colorShade,
    this.colorAlternatives = const [],
  });
}

/// 🔍 Searchable Shop Product Picker for Mandi Sourcing with Low Stock & Bulk Multi-Select
class _ShopProductPickerSheet extends StatefulWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onProductSelected;
  final ValueChanged<List<ProductModel>> onProductsBatchSelected;
  final VoidCallback onScanBarcode;

  const _ShopProductPickerSheet({
    required this.products,
    required this.onProductSelected,
    required this.onProductsBatchSelected,
    required this.onScanBarcode,
  });

  @override
  State<_ShopProductPickerSheet> createState() => _ShopProductPickerSheetState();
}

class _ShopProductPickerSheetState extends State<_ShopProductPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedProductIds = {};
  String _selectedCategory = 'ALL';
  bool _onlyLowStock = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Unique list of shop categories
    final rawCats = widget.products.map((p) => p.category.trim()).where((c) => c.isNotEmpty).toSet().toList();
    rawCats.sort();
    final categories = ['ALL', ...rawCats];

    // Filtered products list
    final filtered = widget.products.where((p) {
      if (_onlyLowStock && p.stock > 5) return false;
      if (_selectedCategory != 'ALL' && p.category.trim() != _selectedCategory) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
    }).toList();

    // Low stock count for quick bulk-select
    final lowStockItems = widget.products.where((p) => p.stock <= 5).toList();

    // Budget sum of selected items
    final selectedProductsList = widget.products.where((p) => _selectedProductIds.contains(p.id)).toList();
    final double totalEstimatedBudget = selectedProductsList.fold(
      0.0,
      (sum, p) => sum + (p.costPrice > 0 ? p.costPrice : (p.price > 0 ? p.price * 0.85 : 0.0)),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: context.colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar with Barcode Scan and Close buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D9488), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.isHindi ? 'दुकान के सामान से चुनें' : 'Select from Shop Inventory',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      tooltip: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Barcode',
                      onPressed: widget.onScanBarcode,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  decoration: InputDecoration(
                    hintText: context.isHindi ? 'सामान का नाम या बारकोड खोजें...' : 'Search product name or barcode...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              // Filter & Bulk-Select Actions Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    // Low Stock Filter Chip
                    FilterChip(
                      label: Text(
                        context.isHindi ? 'कम स्टॉक (≤5)' : 'Low Stock (≤5)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _onlyLowStock ? FontWeight.bold : FontWeight.normal,
                          color: _onlyLowStock ? Colors.white : context.colorTextPrimary,
                        ),
                      ),
                      selected: _onlyLowStock,
                      selectedColor: AppColors.error,
                      backgroundColor: context.colorSurfaceSubtle,
                      onSelected: (val) => setState(() => _onlyLowStock = val),
                    ),
                    const SizedBox(width: 8),

                    // 1-Tap Select All Low Stock
                    if (lowStockItems.isNotEmpty) ...[
                      InkWell(
                        onTap: () {
                          try {
                            HapticFeedback.selectionClick();
                          } catch (_) {}
                          setState(() {
                            final allSelected = lowStockItems.every((p) => _selectedProductIds.contains(p.id));
                            if (allSelected) {
                              for (final p in lowStockItems) {
                                _selectedProductIds.remove(p.id);
                              }
                            } else {
                              for (final p in lowStockItems) {
                                _selectedProductIds.add(p.id);
                              }
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFE65100)),
                              const SizedBox(width: 4),
                              Text(
                                context.isHindi
                                    ? 'कम स्टॉक वाले सभी (${lowStockItems.length})'
                                    : 'All Low Stock (${lowStockItems.length})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${filtered.length} ${context.isHindi ? 'सामान' : 'items'}',
                      style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
                    ),
                  ],
                ),
              ),

              // Category Filter Pills
              if (categories.length > 2) ...[
                Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final cat = categories[idx];
                      final isSelected = _selectedCategory == cat;
                      final label = cat == 'ALL' ? (context.isHindi ? 'सभी' : 'All') : cat;

                      return ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : context.colorTextPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: context.colorSurfaceSubtle,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                ),
              ],
              const Divider(height: 1),

              // Product list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: context.colorTextMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              context.isHindi ? 'कोई सामान नहीं मिला' : 'No matching products',
                              style: TextStyle(color: context.colorTextMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final prod = filtered[idx];
                          final isLowStock = prod.stock <= 5;
                          final isSelected = _selectedProductIds.contains(prod.id);

                          return InkWell(
                            onTap: () {
                              try {
                                HapticFeedback.selectionClick();
                              } catch (_) {}
                              setState(() {
                                if (isSelected) {
                                  _selectedProductIds.remove(prod.id);
                                } else {
                                  _selectedProductIds.add(prod.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.06)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Selection Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      try {
                                        HapticFeedback.selectionClick();
                                      } catch (_) {}
                                      setState(() {
                                        if (val == true) {
                                          _selectedProductIds.add(prod.id);
                                        } else {
                                          _selectedProductIds.remove(prod.id);
                                        }
                                      });
                                    },
                                  ),

                                  // Product Icon
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: (isLowStock ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      color: isLowStock ? AppColors.error : AppColors.primary,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (prod.costPrice > 0)
                                              Text(
                                                'लागत: ₹${prod.costPrice.toStringAsFixed(0)} • ',
                                                style: TextStyle(fontSize: 11, color: ctx.colorTextMuted),
                                              ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isLowStock ? AppColors.errorLight : AppColors.successLight,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'स्टॉक: ${prod.stock} ${prod.unit}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isLowStock ? AppColors.error : AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Customize Single Item Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, size: 22, color: AppColors.primary),
                                    tooltip: ctx.isHindi ? 'कस्टमाइज़ करके जोड़ें' : 'Customize Qty/Rate',
                                    onPressed: () => widget.onProductSelected(prod),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Sticky Bottom Multi-Add Bar (When items are checked)
              if (_selectedProductIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: context.colorSurface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    border: Border(top: BorderSide(color: context.colorBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.isHindi
                                  ? '${_selectedProductIds.length} सामान चुने गए'
                                  : '${_selectedProductIds.length} items selected',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            if (totalEstimatedBudget > 0)
                              Text(
                                context.isHindi
                                    ? 'अनु. कुल: ₹${totalEstimatedBudget.toStringAsFixed(0)}'
                                    : 'Est. Total: ₹${totalEstimatedBudget.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.success, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.playlist_add_check_rounded, size: 19),
                        label: Text(
                          context.isHindi ? '⚡ मंडी लिस्ट में जोड़ें' : 'Add to Mandi',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          widget.onProductsBatchSelected(selectedProductsList);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
