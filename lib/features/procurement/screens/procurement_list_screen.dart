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
        const SnackBar(content: Text('Mandi procurement list is empty')),
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
          const SnackBar(content: Text('Cannot launch WhatsApp')),
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

    final categoriesList = [
      'General Store',
      'Grocery & Staples',
      'Snacks & Munchies',
      'Beverages & Drinks',
      'Dairy, Bakery & Frozen',
      'Personal Care & Beauty',
      'Household & Cleaning',
      'Fruits & Vegetables',
      'Electronics & Appliances',
      'Mobile & Accessories',
      'Clothing & Fashion',
      'Footwear & Leather',
      'Stationery & Office Supplies',
      'Hardware & Building Material',
      'Medicine & Healthcare',
      'Toys & Baby Products',
      'Sports & Fitness',
      'Automotive & Spare Parts',
      'Pet Supplies',
      'Services & Others',
    ];

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
            'Mandi Procurement & Sourcing',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
              tooltip: 'Refresh Procurement List',
              onPressed: () {
                controller.refreshList();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Mandi Procurement List Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
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
                      const SnackBar(content: Text('All items are in stock! No low-stock products found.')),
                    );
                    return;
                  }
                  controller.importLowStockProducts(lowStockProducts);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lowStockProducts.length} Real Low-Stock Items imported into Mandi List!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else if (value == 'clear') {
                  controller.clearAllCompleted();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared purchased/completed items')),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'whatsapp',
                  child: Row(
                    children: const [
                      Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                      SizedBox(width: 8),
                      Text(
                        'WhatsApp Mandi Order',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pdf',
                  child: Row(
                    children: const [
                      Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Generate Mandi PDF Sheet',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                        'Import Low Stock (${lowStockProducts.length})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                      ),
                    ],
                  ),
                ),
                if (controller.completedCount > 0)
                  PopupMenuItem<String>(
                    value: 'clear',
                    child: Row(
                      children: const [
                        Icon(Icons.cleaning_services_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(
                          'Clear Bought Items',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          title: 'Sourcing Items',
                          value: '${controller.totalCount}',
                          subtitle: '${controller.pendingCount} Pending • ${controller.completedCount} Bought',
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppStatCard(
                          title: 'Est. Mandi Budget',
                          value: '₹${controller.totalEstimatedBudget.toStringAsFixed(0)}',
                          subtitle: 'Target Expense',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. ADD ITEM TO MANDI LIST FORM
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.add_task_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Add New Item to Mandi Sourcing List',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Item / Crop Name *',
                                  hintText: 'e.g. Sharbati Gehun / Fortune Oil 1L',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _qtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Qty / Weight *',
                                  hintText: '5 Bags / 250kg',
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
                                  labelText: 'Mandi Dealer / Wholesaler Name',
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _notesCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Notes / Quality Specs',
                                  hintText: 'e.g. Grade A Quality, Cash Discount',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(120, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                  const SnackBar(
                                    content: Text('Item Mandi Procurement List mein add ho gaya!'),
                                    backgroundColor: AppColors.success,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. MANDI SOURCING ITEMS LIST
                  AppSectionHeader(title: 'Mandi Sourcing List (${items.length})'),

                  if (items.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: context.colorTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Procurement list is empty',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add items above or tap 3-dots menu [⋮] -> "Import Low Stock" to auto-fetch reorder items!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Checkbox.adaptive(
                                value: item.isCompleted,
                                activeColor: AppColors.success,
                                onChanged: (_) => controller.toggleItem(item.id),
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
                                      spacing: 8,
                                      runSpacing: 4,
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
                                            'Dealer: ${item.dealerName}',
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
                                  tooltip: 'Call Dealer',
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
    ),);
  }
}
