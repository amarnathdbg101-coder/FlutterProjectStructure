import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../pos/controllers/pos_controller.dart';
import '../controllers/expense_controller.dart';
import '../models/expense_model.dart';
import '../services/smart_expense_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseController>().loadExpenses();
    });
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'chai_nashta':
        return const Color(0xFF8D6E63); // Warm Coffee Brown
      case 'electricity':
        return const Color(0xFFF57C00); // Amber Orange
      case 'rent':
        return const Color(0xFF1E88E5); // Royal Blue
      case 'salary':
        return const Color(0xFF8E24AA); // Purple
      case 'transport':
        return const Color(0xFF00897B); // Teal
      case 'packaging':
        return const Color(0xFFD81B60); // Pink/Rose
      case 'maintenance':
        return const Color(0xFF546E7A); // Slate Blue
      default:
        return const Color(0xFF6D4C41); // Slate Brown
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'chai_nashta':
        return Icons.coffee_rounded;
      case 'electricity':
        return Icons.bolt_rounded;
      case 'rent':
        return Icons.storefront_rounded;
      case 'salary':
        return Icons.badge_outlined;
      case 'transport':
        return Icons.local_shipping_outlined;
      case 'packaging':
        return Icons.shopping_bag_outlined;
      case 'maintenance':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _formatCategoryName(BuildContext context, String cat) {
    switch (cat.toLowerCase()) {
      case 'chai_nashta':
        return context.tr('exp_cat_tea');
      case 'electricity':
        return context.tr('exp_cat_electricity');
      case 'rent':
        return context.tr('exp_cat_rent');
      case 'salary':
        return context.tr('exp_cat_salary');
      case 'transport':
        return context.tr('exp_cat_transport');
      case 'packaging':
        return context.tr('exp_cat_packaging');
      case 'maintenance':
        return context.tr('exp_cat_maintenance');
      default:
        return context.tr('exp_cat_other');
    }
  }

  void _showAddExpenseDialog(
    BuildContext context, {
    String? defaultCategory,
    String? defaultNotes,
    double? defaultAmount,
  }) {
    String category = defaultCategory ?? 'chai_nashta';
    String paymentMethod = 'cash';
    final amountCtrl = TextEditingController(
      text: defaultAmount != null && defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
    );
    final notesCtrl = TextEditingController(text: defaultNotes ?? '');

    final availableCategories = [
      {'key': 'chai_nashta', 'icon': Icons.coffee_rounded, 'label': context.tr('exp_cat_tea')},
      {'key': 'electricity', 'icon': Icons.bolt_rounded, 'label': context.tr('exp_cat_electricity')},
      {'key': 'rent', 'icon': Icons.storefront_rounded, 'label': context.tr('exp_cat_rent')},
      {'key': 'salary', 'icon': Icons.badge_outlined, 'label': context.tr('exp_cat_salary')},
      {'key': 'transport', 'icon': Icons.local_shipping_outlined, 'label': context.tr('exp_cat_transport')},
      {'key': 'packaging', 'icon': Icons.shopping_bag_outlined, 'label': context.tr('exp_cat_packaging')},
      {'key': 'maintenance', 'icon': Icons.cleaning_services_rounded, 'label': context.tr('exp_cat_maintenance')},
      {'key': 'other', 'icon': Icons.receipt_long_rounded, 'label': context.tr('exp_cat_other')},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) => Container(
          decoration: BoxDecoration(
            color: sheetCtx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.90,
              maxWidth: 600,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle & Header
                  Center(
                    child: Container(
                      width: 44,
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
                          color: sheetCtx.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sheetCtx.tr('exp_dialog_title'),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: sheetCtx.colorTextPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: sheetCtx.colorBorder),

                  // 1. 1-Tap Category Selector Chips
                  Text(
                    sheetCtx.tr('exp_field_category'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sheetCtx.colorTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((c) {
                      final isSelected = category == c['key'];
                      final catKey = c['key'] as String;
                      final catColor = _getCategoryColor(catKey);
                      return InkWell(
                        onTap: () {
                          setModalState(() => category = catKey);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? catColor : sheetCtx.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? catColor : sheetCtx.colorBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c['icon'] as IconData,
                                size: 16,
                                color: isSelected ? Colors.white : catColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : sheetCtx.colorTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 2. Amount Input
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: defaultAmount == null,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: '${sheetCtx.tr('exp_field_amount')} *',
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // 1-Tap Quick Amount Chips (Min 42px touch target)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final preset in SmartExpenseService.quickAmountPresets)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setModalState(() {
                              amountCtrl.text = preset.toStringAsFixed(0);
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (double.tryParse(amountCtrl.text) == preset)
                                  ? AppColors.primary
                                  : sheetCtx.colorPrimaryLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (double.tryParse(amountCtrl.text) == preset)
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '₹${preset.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (double.tryParse(amountCtrl.text) == preset)
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Payment Mode Selection (44px touch targets)
                  Text(
                    sheetCtx.tr('exp_field_payment_mode'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sheetCtx.colorTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => paymentMethod = 'cash'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: paymentMethod == 'cash' ? AppColors.success.withValues(alpha: 0.15) : sheetCtx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: paymentMethod == 'cash' ? AppColors.success : sheetCtx.colorBorder,
                                width: paymentMethod == 'cash' ? 1.5 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_rounded, size: 18, color: paymentMethod == 'cash' ? AppColors.success : sheetCtx.colorTextSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  sheetCtx.tr('exp_mode_cash'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: paymentMethod == 'cash' ? AppColors.success : sheetCtx.colorTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => paymentMethod = 'upi'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: paymentMethod == 'upi' ? AppColors.primary.withValues(alpha: 0.15) : sheetCtx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: paymentMethod == 'upi' ? AppColors.primary : sheetCtx.colorBorder,
                                width: paymentMethod == 'upi' ? 1.5 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 18, color: paymentMethod == 'upi' ? AppColors.primary : sheetCtx.colorTextSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  sheetCtx.tr('exp_mode_online'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: paymentMethod == 'upi' ? AppColors.primary : sheetCtx.colorTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Notes
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: sheetCtx.tr('exp_field_notes'),
                      hintText: sheetCtx.isHindi ? 'उदा. दुकान स्टाफ के लिए चाय नाश्ता' : 'e.g. Samosa & tea for staff',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: AppVoiceIconButton(
                        controller: notesCtrl,
                        hint: sheetCtx.tr('exp_field_notes'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 5. Submit Buttons (48px primary action)
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(sheetCtx.tr('btn_cancel'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                            if (amount <= 0) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text(sheetCtx.tr('exp_val_amount'))),
                              );
                              return;
                            }

                            final success = await context.read<ExpenseController>().addExpense(
                              category: category,
                              amount: amount,
                              notes: notesCtrl.text.trim(),
                              paymentMethod: paymentMethod,
                            );

                            if (success && sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(sheetCtx.tr('exp_toast_saved')),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          child: Text(
                            sheetCtx.isHindi ? '✓ खर्च सेव करें' : sheetCtx.tr('btn_save'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('exp_delete_title')),
        content: Text(context.tr('exp_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('btn_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ExpenseController>().deleteExpense(id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('exp_toast_deleted'))),
                );
              }
            },
            child: Text(context.tr('btn_delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMonthlySummarySheet(
    BuildContext context,
    ExpenseController expCtrl,
    double todaySales,
    dynamic profitSummary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ctx.isHindi ? 'दुकान खर्च व मुनाफा रिपोर्ट' : 'Monthly Expense & Profit Summary',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: ctx.colorTextPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    title: ctx.tr('exp_kpi_sales'),
                    value: '₹${todaySales.toStringAsFixed(0)}',
                    subtitle: ctx.isHindi ? 'आज की बिक्री' : "Today's Sales",
                    icon: Icons.point_of_sale_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppStatCard(
                    title: ctx.tr('exp_kpi_today'),
                    value: '₹${expCtrl.todayExpenses.toStringAsFixed(0)}',
                    subtitle: ctx.isHindi ? 'आज के खर्चे' : "Today's Expenses",
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    title: profitSummary.isLoss ? ctx.tr('exp_kpi_net_balance') : ctx.tr('exp_kpi_net_profit'),
                    value: '${profitSummary.netProfit < 0 ? "-" : (profitSummary.netProfit > 0 ? "+" : "")}₹${profitSummary.netProfit.abs().toStringAsFixed(0)}',
                    subtitle: profitSummary.isLoss ? (ctx.isHindi ? 'घाटा' : 'Net Loss') : (ctx.isHindi ? 'शुद्ध बचत' : 'Net In-Hand'),
                    icon: profitSummary.isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppStatCard(
                    title: ctx.tr('exp_kpi_monthly'),
                    value: '₹${expCtrl.monthlyExpenses.toStringAsFixed(0)}',
                    subtitle: '${expCtrl.expenses.length} ${ctx.isHindi ? 'प्रविष्टियां' : 'Records'}',
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresetChip(BuildContext context, String label, String cat, String defaultNotes, double? defaultAmt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _showAddExpenseDialog(
          context,
          defaultCategory: cat,
          defaultNotes: defaultNotes,
          defaultAmount: defaultAmt,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colorBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final expController = context.watch<ExpenseController>();

    DashboardController? dashCtrl;
    try {
      dashCtrl = context.watch<DashboardController>();
    } catch (_) {}

    PosController? posCtrl;
    try {
      posCtrl = context.watch<PosController>();
    } catch (_) {}

    AuthController? authCtrl;
    try {
      authCtrl = context.watch<AuthController>();
    } catch (_) {}

    final todaySales = (dashCtrl != null && dashCtrl.stats.todaySales > 0)
        ? dashCtrl.stats.todaySales
        : (posCtrl?.today24hRevenue ?? 0.0);

    final profitSummary = SmartExpenseService.calculateDailyProfit(
      todaySales: todaySales,
      todayExpenses: expController.todayExpenses,
    );

    final displayExpenses = _selectedFilter == 'all'
        ? expController.expenses
        : expController.expenses.where((e) => e.category.toLowerCase() == _selectedFilter).toList();

    return MerchantShell(
      currentIndex: 4,
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
            context.tr('exp_title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colorTextPrimary),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
              tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              onSelected: (val) async {
                switch (val) {
                  case 'add':
                    _showAddExpenseDialog(context);
                    break;
                  case 'share':
                    final summaryMessage = SmartExpenseService.formatDailyExpenseSummary(
                      shopName: authCtrl?.currentShop?.name ?? '',
                      todaySales: todaySales,
                      todayExpenses: expController.todayExpenses,
                      todayExpensesList: expController.expenses.where((e) {
                        final now = DateTime.now();
                        final dt = e.expenseDate;
                        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
                      }).toList(),
                      isHindi: context.isHindi,
                    );
                    SmartExpenseService.shareExpenseSummaryOnWhatsApp(
                      context: context,
                      message: summaryMessage,
                    );
                    break;
                  case 'monthly':
                    _showMonthlySummarySheet(context, expController, todaySales, profitSummary);
                    break;
                  case 'refresh':
                    await expController.loadExpenses();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Shop Expenses Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'add',
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'नया खर्च दर्ज करें' : 'Add New Expense'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'व्हाट्सएप सारांश शेयर करें' : 'Share WhatsApp Summary'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'monthly',
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'महीने की रिपोर्ट देखें' : 'Monthly Summary Report'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: ctx.colorTextPrimary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'कैशबुक रीफ्रेश करें' : 'Refresh Cashbook'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            context.tr('exp_add_btn'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showAddExpenseDialog(context),
        ),
        body: ResponsiveContainer(
          maxWidth: 1200,
          child: Column(
            children: [
              // 1. DUAL CASHBOOK HERO CARD (TODAY'S SPENDS + THIS MONTH'S EXPENSES)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Left: Today's Spends
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.colorErrorLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.error),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          context.isHindi ? 'आज का खर्चा' : context.tr('exp_kpi_today'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.error,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${expController.todayExpenses.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.error,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.isHindi
                                        ? (profitSummary.netProfit >= 0
                                            ? 'बचत: +₹${profitSummary.netProfit.toStringAsFixed(0)}'
                                            : 'घाटा: -₹${profitSummary.netProfit.abs().toStringAsFixed(0)}')
                                        : 'Sales: ₹${todaySales.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: profitSummary.isLoss ? AppColors.error : AppColors.success,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right: This Month's Spends
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.colorPrimaryLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          context.isHindi ? 'इस महीने का खर्च' : context.tr('exp_kpi_monthly'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${expController.monthlyExpenses.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: context.colorTextPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${expController.expenses.length} ${context.isHindi ? 'खर्चे दर्ज' : 'Records'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.colorTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Action Row: Quick add + Monthly report button (40px touch targets)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showMonthlySummarySheet(context, expController, todaySales, profitSummary),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.analytics_outlined, size: 16),
                              label: Text(
                                context.isHindi ? 'महीने की रिपोर्ट' : 'Monthly Summary',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddExpenseDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                context.isHindi ? '+ नया खर्च' : '+ Add Expense',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. ⚡ ROZ KE KHARCHE 1-TAP QUICK PRESETS BAR (Min 40px Height)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('exp_quick_entry_title'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickPresetChip(context, context.isHindi ? '☕ चाय-नाश्ता (₹20)' : '☕ Tea & Snacks (₹20)', 'chai_nashta', 'Staff Tea & Snacks', 20.0),
                          _buildQuickPresetChip(context, context.isHindi ? '⚡ बिजली बिल' : '⚡ Electricity Bill', 'electricity', 'Monthly Power Bill', null),
                          _buildQuickPresetChip(context, context.isHindi ? '🏬 दुकान किराया' : '🏬 Store Rent', 'rent', 'Monthly Shop Rent', null),
                          _buildQuickPresetChip(context, context.isHindi ? '👨‍🍳 स्टाफ वेतन' : '👨‍🍳 Staff Salary', 'salary', 'Staff Salary Advance', null),
                          _buildQuickPresetChip(context, context.isHindi ? '⛽ भाड़ा / ऑटो (₹100)' : '⛽ Goods Auto / Fare', 'transport', 'Delivery / Auto Fare', 100.0),
                          _buildQuickPresetChip(context, context.isHindi ? '📦 पैकिंग थैली (₹500)' : '📦 Packaging Bags', 'packaging', 'Packing Bags Material', 500.0),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // 3. CATEGORY FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_filter_all'),
                      count: expController.expenses.length,
                      isSelected: _selectedFilter == 'all',
                      onSelected: () => setState(() => _selectedFilter = 'all'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_tea'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'chai_nashta').length,
                      isSelected: _selectedFilter == 'chai_nashta',
                      onSelected: () => setState(() => _selectedFilter = 'chai_nashta'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_electricity'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'electricity').length,
                      isSelected: _selectedFilter == 'electricity',
                      onSelected: () => setState(() => _selectedFilter == 'electricity'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_rent'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'rent').length,
                      isSelected: _selectedFilter == 'rent',
                      onSelected: () => setState(() => _selectedFilter == 'rent'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_salary'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'salary').length,
                      isSelected: _selectedFilter == 'salary',
                      onSelected: () => setState(() => _selectedFilter == 'salary'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_transport'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'transport').length,
                      isSelected: _selectedFilter == 'transport',
                      onSelected: () => setState(() => _selectedFilter == 'transport'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_packaging'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'packaging').length,
                      isSelected: _selectedFilter == 'packaging',
                      onSelected: () => setState(() => _selectedFilter == 'packaging'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_other'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'other').length,
                      isSelected: _selectedFilter == 'other',
                      onSelected: () => setState(() => _selectedFilter == 'other'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4. EXPENSES LIST
              Expanded(
                child: expController.isLoading && expController.expenses.isEmpty
                    ? const AppListSkeleton()
                    : displayExpenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 54, color: context.colorTextMuted),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('exp_empty_title'),
                                  style: TextStyle(fontWeight: FontWeight.w600, color: context.colorTextPrimary),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    minimumSize: const Size(140, 44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                                  label: Text(context.tr('exp_add_btn')),
                                  onPressed: () => _showAddExpenseDialog(context),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final isMultiColumn = width > 750;

                              if (isMultiColumn) {
                                final crossAxisCount = width > 1050 ? 3 : 2;
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 3.2,
                                  ),
                                  itemCount: displayExpenses.length,
                                  itemBuilder: (context, index) {
                                    final exp = displayExpenses[index];
                                    return _buildExpenseCard(context, exp, expController);
                                  },
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: displayExpenses.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final exp = displayExpenses[index];
                                  return _buildExpenseCard(context, exp, expController);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, ExpenseModel exp, ExpenseController controller) {
    final catColor = _getCategoryColor(exp.category);
    final catIcon = _getCategoryIcon(exp.category);
    final isCash = exp.paymentMethod.toLowerCase() == 'cash';
    final formattedDate = AppDateTimeUtils.formatRelativeDate(exp.expenseDate);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(catIcon, color: catColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatCategoryName(context, exp.category),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.colorTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCash ? AppColors.success.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCash ? (context.isHindi ? 'नकद' : 'CASH') : (context.isHindi ? 'ऑनलाइन' : 'UPI'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isCash ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                    ),
                    if (exp.notes.isNotEmpty) ...[
                      Text(' • ', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                      Expanded(
                        child: Text(
                          exp.notes,
                          style: TextStyle(fontSize: 11.5, color: context.colorTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${exp.amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.colorTextPrimary),
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: context.colorTextMuted),
            tooltip: context.isHindi ? 'हटाएं' : 'Delete',
            onPressed: () => _confirmDeleteExpense(context, exp.id),
          ),
        ],
      ),
    );
  }
}
