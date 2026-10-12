import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/expense_controller.dart';
import '../models/expense_model.dart';

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

  void _showAddExpenseDialog(BuildContext context, {String? defaultCategory, String? defaultNotes, double? defaultAmount}) {
    String category = defaultCategory ?? 'chai_nashta';
    String paymentMethod = 'cash';
    final amountCtrl = TextEditingController(
      text: defaultAmount != null && defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
    );
    final notesCtrl = TextEditingController(text: defaultNotes ?? '');

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
            top: 20,
            left: 20,
            right: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              maxWidth: 580,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle & Header
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: sheetCtx.colorTextPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: sheetCtx.colorBorder),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    key: ValueKey('exp_category_$category'),
                    isExpanded: true,
                    initialValue: category,
                    decoration: InputDecoration(labelText: sheetCtx.tr('exp_field_category')),
                    items: [
                      DropdownMenuItem(value: 'chai_nashta', child: Text(sheetCtx.tr('exp_cat_tea'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'electricity', child: Text(sheetCtx.tr('exp_cat_electricity'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'rent', child: Text(sheetCtx.tr('exp_cat_rent'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'salary', child: Text(sheetCtx.tr('exp_cat_salary'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'transport', child: Text('Transport / Petrol', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'packaging', child: Text(sheetCtx.tr('exp_cat_packaging'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'maintenance', child: Text(sheetCtx.tr('exp_cat_maintenance'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'other', child: Text(sheetCtx.tr('exp_cat_other'), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '${sheetCtx.tr('exp_field_amount')} *',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: sheetCtx.tr('exp_field_notes'),
                      hintText: 'e.g. Samosa & tea for staff',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Method
                  DropdownButtonFormField<String>(
                    key: ValueKey('exp_payment_mode_$paymentMethod'),
                    isExpanded: true,
                    initialValue: paymentMethod,
                    decoration: InputDecoration(labelText: sheetCtx.tr('exp_field_payment_mode')),
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(sheetCtx.tr('exp_mode_cash'), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'upi', child: Text(sheetCtx.tr('exp_mode_online'), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: Text(sheetCtx.tr('btn_cancel')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(120, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        child: Text(sheetCtx.tr('btn_save'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ExpenseController>().deleteExpense(id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense record deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        return 'Transport / Petrol';
      case 'packaging':
        return context.tr('exp_cat_packaging');
      case 'maintenance':
        return context.tr('exp_cat_maintenance');
      default:
        return context.tr('exp_cat_other');
    }
  }

  Widget _buildQuickPresetChip(BuildContext context, String label, String cat, String defaultNotes, double? defaultAmt) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _showAddExpenseDialog(
          context,
          defaultCategory: cat,
          defaultNotes: defaultNotes,
          defaultAmount: defaultAmt,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colorBorder),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
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
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh Expenses',
              onPressed: () async {
                await expController.loadExpenses();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Shop Expenses Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                  );
                }
              },
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
              // 1. EXECUTIVE EXPENSE SUMMARY KPI CARDS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppStatCard(
                        title: context.tr('exp_kpi_today'),
                        value: '₹${expController.todayExpenses.toStringAsFixed(0)}',
                        subtitle: context.isHindi ? 'आज के खर्चे' : "Today's Expenses",
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppStatCard(
                        title: context.tr('exp_kpi_monthly'),
                        value: '₹${expController.monthlyExpenses.toStringAsFixed(0)}',
                        subtitle: '${expController.expenses.length} ${context.isHindi ? 'प्रविष्टियां' : 'Records'}',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. ⚡ ROZ KE KHARCHE 1-TAP QUICK PRESETS BAR
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
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextMuted),
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
                          _buildQuickPresetChip(context, context.isHindi ? '⛽ पेट्रोल / परिवहन' : '⛽ Petrol / Transport', 'transport', 'Delivery / Auto Fare', 100.0),
                          _buildQuickPresetChip(context, context.isHindi ? '📦 पैकेजिंग / बैग' : '📦 Packaging Bags', 'packaging', 'Packing Material', 500.0),
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
                      label: context.isHindi ? 'सभी' : 'All',
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
                      onSelected: () => setState(() => _selectedFilter = 'electricity'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_rent'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'rent').length,
                      isSelected: _selectedFilter == 'rent',
                      onSelected: () => setState(() => _selectedFilter = 'rent'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_salary'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'salary').length,
                      isSelected: _selectedFilter == 'salary',
                      onSelected: () => setState(() => _selectedFilter = 'salary'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.isHindi ? '⛽ परिवहन' : '⛽ Transport',
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'transport').length,
                      isSelected: _selectedFilter == 'transport',
                      onSelected: () => setState(() => _selectedFilter = 'transport'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_packaging'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'packaging').length,
                      isSelected: _selectedFilter == 'packaging',
                      onSelected: () => setState(() => _selectedFilter = 'packaging'),
                    ),
                    _buildFilterChip(
                      context: context,
                      label: context.tr('exp_cat_other'),
                      count: expController.expenses.where((e) => e.category.toLowerCase() == 'other').length,
                      isSelected: _selectedFilter == 'other',
                      onSelected: () => setState(() => _selectedFilter = 'other'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 3. EXPENSES LIST
              Expanded(
                child: expController.isLoading && expController.expenses.isEmpty
                    ? const Center(child: CircularProgressIndicator())
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
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCategoryName(context, exp.category),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  exp.notes.isNotEmpty ? exp.notes : 'Mode: ${exp.paymentMethod.toUpperCase()}',
                  style: TextStyle(fontSize: 11.5, color: context.colorTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '₹${exp.amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.colorTextPrimary),
          ),
          const SizedBox(width: 6),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.colorTextMuted),
            tooltip: 'Delete Record',
            onPressed: () => _confirmDeleteExpense(context, exp.id),
          ),
        ],
      ),
    );
  }
}
