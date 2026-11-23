import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/khata_controller.dart';
import '../models/khata_model.dart';
import 'customer_statement_screen.dart';
import '../widgets/khata_dialogs.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KhataController>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // MODAL: RECORD CREDIT / PAYMENT ENTRY
  // ==========================================
  void _showAddTransactionModal(
    BuildContext context, {
    KhataCustomerModel? customer,
    bool isCredit = true,
  }) {
    KhataDialogs.showAddTransactionModal(context, customer: customer, isCredit: isCredit);
  }

  void _showCustomerStatementSheet(BuildContext context, KhataCustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerStatementScreen(customer: customer),
      ),
    );
  }

  // ==========================================
  // MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final khata = context.watch<KhataController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MerchantShell(
      currentIndex: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: context.colorSurface,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: context.colorBorder, height: 1.0),
          ),
          leading: AppBackButton(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fallbackRoute: '/merchant',
          ),
          title: Text(
            context.tr('khata_title'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 22),
              tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              onSelected: (val) async {
                switch (val) {
                  case 'broadcast':
                    khata.broadcastWhatsAppOverdueReminders(context);
                    break;
                  case 'aging':
                    _showAgingBreakdownSheet(context);
                    break;
                  case 'add':
                    _showAddTransactionModal(context, isCredit: true);
                    break;
                  case 'refresh':
                    await khata.loadCustomers();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.isHindi ? '✓ खाता डेटा रीफ्रेश हुआ' : '✓ Khata ledger refreshed'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (khata.overdueCount > 0)
                  PopupMenuItem(
                    value: 'broadcast',
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFF25D366), size: 18),
                        const SizedBox(width: 10),
                        Text(ctx.isHindi ? '📢 सभी बकायेदारों को तगादा भेजें' : '📢 Broadcast Reminders'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'aging',
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'उधारी एजिंग रिपोर्ट (0-30, 31-60 दिन)' : 'View Aging Report'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'नया खाता ग्राहक जोड़ें' : 'Add New Customer'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'खाता रीफ्रेश करें' : 'Refresh Khata Ledger'),
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
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: Text(
            context.isHindi ? '+ नया खाता' : '+ New Customer',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
          onPressed: () => _showAddTransactionModal(context, isCredit: true),
        ),
        body: RefreshIndicator(
          onRefresh: () => khata.loadCustomers(),
          color: AppColors.primary,
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Column(
              children: [
                // Clean Single Hero Total Market Debt Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Metric Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (khata.totalMarketDebt > 0 ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: khata.totalMarketDebt > 0 ? AppColors.error : AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.isHindi ? 'कुल बाज़ार बाकी (मार्केट उधारी)' : 'Total Market Dues',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.colorTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '₹${khata.totalMarketDebt.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: khata.totalMarketDebt > 0 ? AppColors.error : AppColors.success,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${khata.debtorsCount} ${context.isHindi ? "ग्राहक बाकीदार" : "customers owe dues"}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: context.colorTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (khata.overdueCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${khata.overdueCount} ${context.isHindi ? "समय पार" : "Overdue"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: context.colorBorder),
                        const SizedBox(height: 12),
                        // Quick Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddTransactionModal(context, isCredit: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.error,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                                  ),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                                label: Text(context.isHindi ? 'दिए (+ उधार)' : '+ Give Credit'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddTransactionModal(context, isCredit: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.success,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                label: Text(context.isHindi ? 'मिले (- जमा)' : '- Receive Cash'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Input (Customer Style Spacious Search & Speech-to-Text)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: context.tr('khata_search_hint'),
                    onChanged: (query) => khata.setSearchQuery(query),
                    onSubmitted: (query) => khata.setSearchQuery(query),
                    onClear: () => khata.setSearchQuery(''),
                  ),
                ),
                const SizedBox(height: 6),

                // Horizontal Segment Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: context.tr('khata_tab_all'),
                        count: khata.customers.length,
                        isSelected: khata.activeFilter == 'all',
                        onSelected: () => khata.setActiveFilter('all'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('khata_tab_dues'),
                        count: khata.debtorsCount,
                        isSelected: khata.activeFilter == 'dues',
                        onSelected: () => khata.setActiveFilter('dues'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('khata_tab_overdue'),
                        count: khata.overdueCount,
                        isSelected: khata.activeFilter == 'overdue',
                        onSelected: () => khata.setActiveFilter('overdue'),
                        isAlert: khata.overdueCount > 0,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: context.tr('khata_tab_settled'),
                        count: khata.customers.where((c) => c.balance <= 0).length,
                        isSelected: khata.activeFilter == 'settled',
                        onSelected: () => khata.setActiveFilter('settled'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Customer Ledger List / Grid
                Expanded(
                  child: khata.isLoading
                      ? const AppListSkeleton()
                      : khata.filteredCustomers.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_outlined,
                                      size: 42,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      context.tr('khata_empty_title'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.person_add_outlined, size: 15),
                                      label: Text(context.tr('khata_add_btn')),
                                      onPressed: () => _showAddTransactionModal(context, isCredit: true),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final isMultiColumn = width > 750;

                                if (isMultiColumn) {
                                  final crossAxisCount = width > 1050 ? 3 : 2;
                                  return GridView.builder(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.1,
                                    ),
                                    itemCount: khata.filteredCustomers.length,
                                    itemBuilder: (context, index) {
                                      final c = khata.filteredCustomers[index];
                                      return _buildCustomerCard(context, c);
                                    },
                                  );
                                }

                                return ListView.separated(
                                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: khata.filteredCustomers.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final c = khata.filteredCustomers[index];
                                    return _buildCustomerCard(context, c);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: AGING BREAKDOWN BOTTOM SHEET
  // ==========================================
  void _showAgingBreakdownSheet(BuildContext context) {
    final khata = context.read<KhataController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aging = khata.aging;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.isHindi ? 'उधारी एजिंग रिपोर्ट (Aging Analysis)' : 'Udhar Aging Analysis',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildAgingRow(
              ctx,
              label: context.tr('khata_aging_0_30'),
              amount: '₹${aging?.currentDays0To30.toStringAsFixed(0) ?? '0'}',
              color: AppColors.primary,
              icon: Icons.timelapse_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildAgingRow(
              ctx,
              label: context.tr('khata_aging_31_60'),
              amount: '₹${aging?.days31To60.toStringAsFixed(0) ?? '0'}',
              color: AppColors.warning,
              icon: Icons.alarm_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildAgingRow(
              ctx,
              label: context.tr('khata_aging_60_plus'),
              amount: '₹${aging?.days61Plus.toStringAsFixed(0) ?? '0'}',
              color: AppColors.error,
              icon: Icons.warning_amber_rounded,
              isDark: isDark,
              isAlert: (aging?.days61Plus ?? 0) > 0,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingRow(
    BuildContext context, {
    required String label,
    required String amount,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert
            ? color.withValues(alpha: 0.12)
            : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? color.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: FILTER CHIP HELPER
  // ==========================================
  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
    bool isAlert = false,
  }) {
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : (isAlert ? AppColors.error : AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isAlert ? AppColors.error : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      onSelected: (_) => onSelected(),
    );
  }

  // ==========================================
  // WIDGET: RICH CUSTOMER CARD
  // ==========================================
  Widget _buildCustomerCard(BuildContext context, KhataCustomerModel c) {
    final khata = context.read<KhataController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDues = c.balance > 0;
    final isAdvance = c.balance < 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _showCustomerStatementSheet(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Avatar, Name, Mobile & Balance
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: hasDues
                    ? AppColors.error.withValues(alpha: 0.1)
                    : (isAdvance
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : context.colorSurfaceSubtle),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: hasDues
                        ? AppColors.error
                        : (isAdvance ? AppColors.primary : context.colorTextPrimary),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.mobile,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.lastTransactionAt != null) ...[
                          Flexible(
                            child: Text(
                              ' • ${AppDateTimeUtils.formatRelativeDate(c.lastTransactionAt!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    child: Text(
                      '₹${c.balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: hasDues
                            ? AppColors.error
                            : (isAdvance ? AppColors.primary : AppColors.success),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppBadge(
                    label: hasDues
                        ? context.tr('khata_status_due')
                        : (isAdvance
                            ? context.tr('khata_status_advance')
                            : context.tr('khata_status_settled')),
                    type: hasDues
                        ? AppBadgeType.error
                        : (isAdvance ? AppBadgeType.primary : AppBadgeType.success),
                  ),
                ],
              ),
            ],
          ),

          // Metadata Badges Row (Overdue warning / Promise Date)
          if (c.isOverdue || c.promiseDate != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (c.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          c.overdueDays > 0
                              ? '${c.overdueDays} ${context.isHindi ? "दिन लेट (समय पार)" : "days overdue"}'
                              : (context.isHindi ? 'समय सीमा पार (Overdue)' : 'Payment overdue'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (c.promiseDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${context.isHindi ? "वादा" : "Promise"}: ${DateFormat('dd MMM').format(c.promiseDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Clean Action Row
          Row(
            children: [
              if (hasDues) ...[
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      khata.sendWhatsAppReminder(context, c);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF1EBE5D)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.isHindi ? 'तगादा भेजें' : 'WhatsApp',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1EBE5D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _showAddTransactionModal(context, customer: c, isCredit: true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_outward_rounded, size: 13, color: AppColors.error),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr('khata_give_credit_short'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _showAddTransactionModal(context, customer: c, isCredit: false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr('khata_receive_payment_short'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
