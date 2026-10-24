import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../products/controllers/product_controller.dart';
import '../../products/models/product_model.dart';
import '../controllers/procurement_controller.dart';
import '../models/procurement_model.dart';

class ProcurementListScreen extends StatefulWidget {
  const ProcurementListScreen({super.key});

  @override
  State<ProcurementListScreen> createState() => _ProcurementListScreenState();
}

class _ProcurementListScreenState extends State<ProcurementListScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _dealerCtrl = TextEditingController();
  final TextEditingController _dealerPhoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _selectedCategory = 'General Store';
  bool _isFormExpanded = false;
  String _activeFilter = 'ALL'; // 'ALL' | 'PENDING' | 'COMPLETED' | Category Name

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _dealerCtrl.dispose();
    _dealerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsAppOrderSheet(BuildContext context, List<ProcurementItemModel> items, String shopName) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.isHindi ? 'मंडी लिस्ट अभी खाली है' : 'Mandi procurement list is empty')),
      );
      return;
    }

    final pending = items.where((i) => !i.isCompleted).toList();
    final target = pending.isNotEmpty ? pending : items;

    String text = '🌾 *MANDI SOURCING & WHOLESALE ORDER SHEET*\n';
    text += 'Dukan: *$shopName*\n';
    text += 'Tareekh: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n';
    text += '------------------------------------\n\n';
    text += '*KHAREEDNE WALE ITEMS (${target.length}):*\n';

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

  Future<void> _callDealer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProcurementController>();
    final authController = context.watch<AuthController>();
    final prodController = context.watch<ProductController>();

    final shopName = authController.currentShop?.name ?? 'ShopSilo Merchant';
    final items = controller.items;

    // Real Low Stock Products from Inventory
    final lowStockProducts = prodController.products.where((p) => p.isLowStock || p.isOutOfStock).toList();

    final categoriesList = List<String>.from(CategoryRegistry.canonicalCategories);

    // Filter items based on active chip
    final filteredItems = items.where((item) {
      if (_activeFilter == 'PENDING') return !item.isCompleted;
      if (_activeFilter == 'COMPLETED') return item.isCompleted;
      if (_activeFilter != 'ALL') return CategoryRegistry.isCategoryMatch(item.category, _activeFilter);
      return true;
    }).toList();

    return MerchantShell(
      currentIndex: -1,
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
          title: Text(
            context.tr('mandi_title'),
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
              tooltip: context.isHindi ? 'रीफ्रेश करें' : 'Refresh List',
              onPressed: () {
                controller.refreshList();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.isHindi ? '✓ मंडी खरीद लिस्ट रीफ्रेश हो गई' : '✓ Mandi Procurement List Refreshed'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: context.colorSurface,
              onSelected: (value) {
                if (value == 'whatsapp') {
                  _sendWhatsAppOrderSheet(context, items, shopName);
                } else if (value == 'pdf') {
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
                } else if (value == 'clear') {
                  controller.clearAllCompleted();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.isHindi ? 'खरीदे जा चुके सामान हटा दिए गए' : 'Cleared bought items')),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      const Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('mandi_whatsapp_sheet'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pdf',
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
                      Text(
                        '${context.tr('mandi_import_low')} (${lowStockProducts.length})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
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
                        const SizedBox(width: 8),
                        Text(
                          context.isHindi ? 'खरीदा गया सामान साफ करें' : 'Clear Bought Items',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
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
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ResponsiveContainer(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. FINANCIAL PROCUREMENT SUMMARY CARDS
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('mandi_items'),
                          value: '${controller.totalCount}',
                          subtitle: context.isHindi ? '${controller.pendingCount} बाकी • ${controller.completedCount} खरीदा' : '${controller.pendingCount} Pending • ${controller.completedCount} Bought',
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('mandi_budget'),
                          value: '₹${controller.totalEstimatedBudget.toStringAsFixed(0)}',
                          subtitle: context.isHindi ? 'अनुमानित कुल लागत' : 'Estimated Target Expense',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. PROMINENT QUICK ACTIONS HUB
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Auto-Import Low Stock Button
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              if (lowStockProducts.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.isHindi ? 'सब सामान इन-स्टॉक है! कोई कम स्टॉक आइटम नहीं मिला।' : 'All items in stock! No low-stock items found.')),
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
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${context.tr('mandi_import_low')} (${lowStockProducts.length})',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // WhatsApp Order Sheet Button
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _sendWhatsAppOrderSheet(context, items, shopName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.send_rounded, size: 15, color: Color(0xFF128C7E)),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr('mandi_whatsapp_sheet'),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF128C7E)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Mandi PDF Sheet Button
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => controller.generatePdfSheet(context, shopName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.colorSurfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 15, color: context.colorTextPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr('mandi_pdf_sheet'),
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. ADD ITEM TO MANDI LIST FORM (EASY & EXPANDABLE)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isFormExpanded = !_isFormExpanded),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add_task_rounded, size: 18, color: AppColors.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr('mandi_add_title'),
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                                  ),
                                ),
                                Icon(
                                  _isFormExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: context.colorTextMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Fast Input Fields
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _nameCtrl,
                                decoration: InputDecoration(
                                  labelText: context.tr('mandi_item_name'),
                                  hintText: context.isHindi ? 'उदा. शरबाती गेहूं 50kg / तैल 1L' : 'e.g. Sharbati Wheat 50kg',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _qtyCtrl,
                                decoration: InputDecoration(
                                  labelText: context.tr('mandi_qty'),
                                  hintText: context.isHindi ? '5 बोरी / 100kg' : '5 Bags / 100kg',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Additional Form Details when Expanded or Always on Large Screens
                        if (_isFormExpanded || Responsive.isDesktop(context)) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: const ValueKey('procurement_category_dropdown'),
                                  isExpanded: true,
                                  initialValue: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: categoriesList
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCategory = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Est Rate (₹)',
                                    prefixText: '₹ ',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _dealerCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Wholesaler / Mandi Dealer',
                                    hintText: 'e.g. Shyam Trading Co.',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _dealerPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Dealer Phone / WhatsApp',
                                    hintText: '9876543210',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Quality Notes / Specs',
                              hintText: 'e.g. Grade A Quality, Cash Discount',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() => _isFormExpanded = !_isFormExpanded),
                              icon: Icon(_isFormExpanded ? Icons.tune_rounded : Icons.add_circle_outline_rounded, size: 16),
                              label: Text(_isFormExpanded ? (context.isHindi ? 'कम विवरण' : 'Fewer Details') : (context.isHindi ? 'डीलर व नोट्स जोड़ें' : '+ Dealer & Notes')),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(130, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              label: Text(context.isHindi ? 'सामान जोड़ें' : 'Add to List', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                final name = _nameCtrl.text.trim();
                                final qty = _qtyCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('proc_val_name'))),
                                  );
                                  return;
                                }

                                controller.addItem(
                                  name: name,
                                  qty: qty.isNotEmpty ? qty : '1',
                                  category: _selectedCategory,
                                  estimatedPrice: double.tryParse(_priceCtrl.text) ?? 0.0,
                                  dealerName: _dealerCtrl.text.trim(),
                                  dealerPhone: _dealerPhoneCtrl.text.trim(),
                                  notes: _notesCtrl.text.trim(),
                                );

                                _nameCtrl.clear();
                                _qtyCtrl.clear();
                                _priceCtrl.clear();
                                _dealerCtrl.clear();
                                _dealerPhoneCtrl.clear();
                                _notesCtrl.clear();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.isHindi ? 'सामान मंडी खरीद लिस्ट में जुड़ गया!' : 'Item added to Mandi Procurement List!'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. FILTER PILLS STRIP
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', context.isHindi ? 'सभी (${items.length})' : 'All (${items.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('PENDING', context.isHindi ? '⏳ बाकी (${controller.pendingCount})' : '⏳ Pending (${controller.pendingCount})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('COMPLETED', context.isHindi ? '✅ खरीदा (${controller.completedCount})' : '✅ Bought (${controller.completedCount})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. ITEMIZED SOURCING LIST
                  AppSectionHeader(
                    title: '${context.tr('mandi_items')} (${filteredItems.length})',
                  ),

                  if (filteredItems.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 44, color: context.colorTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            context.isHindi ? 'मंडी खरीद लिस्ट खाली है' : 'Sourcing list is empty',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.isHindi ? 'ऊपर नया सामान जोड़ें या "कम स्टॉक ऑटो-इंपोर्ट" बटन दबाएं!' : 'Add items above or tap "Auto-Import Low Stock" button!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                          ),
                          if (lowStockProducts.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                              label: Text(
                                '${context.tr('mandi_import_low')} (${lowStockProducts.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                              ),
                              onPressed: () {
                                controller.importLowStockProducts(lowStockProducts);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.isHindi ? '${lowStockProducts.length} कम स्टॉक वाले उत्पाद जुड़े!' : '${lowStockProducts.length} Low-Stock Items imported!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
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
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: 1.05,
                                child: Checkbox.adaptive(
                                  value: item.isCompleted,
                                  activeColor: AppColors.success,
                                  onChanged: (_) => controller.toggleItem(item.id),
                                ),
                              ),
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: context.colorTextPrimary,
                                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        if (item.estimatedPrice > 0)
                                          Text(
                                            '₹${item.estimatedPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: context.colorSurfaceSubtle,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: context.colorBorder),
                                          ),
                                          child: Text('Qty: ${item.qty}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: context.colorPrimaryLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(item.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                        if (item.dealerName.isNotEmpty)
                                          Text(
                                            'Wholesaler: ${item.dealerName}',
                                            style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    ),
                                    if (item.notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Note: ${item.notes}', style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontStyle: FontStyle.italic)),
                                    ],
                                  ],
                                ),
                              ),
                              if (item.dealerPhone.isNotEmpty) ...[
                                IconButton(
                                  icon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
                                  tooltip: 'Call Wholesaler',
                                  onPressed: () => _callDealer(item.dealerPhone),
                                ),
                              ],
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
