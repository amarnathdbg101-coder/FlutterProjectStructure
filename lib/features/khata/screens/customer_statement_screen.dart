import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../controllers/khata_controller.dart';
import '../models/khata_model.dart';
import '../services/smart_khata_reminder_service.dart';
import '../widgets/khata_dialogs.dart';
import '../widgets/khata_micro_plan_card.dart';

/// Dedicated Traditional Full Screen for Customer Statement / Passbook
/// Eliminates cramped modal popups and provides a clean, fast, reliable workflow.
class CustomerStatementScreen extends StatefulWidget {
  final KhataCustomerModel customer;

  const CustomerStatementScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  String _activeFilter = 'all'; // 'all', 'credit', 'payment'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KhataController>().loadStatement(widget.customer.mobile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<KhataController>(
      builder: (context, khata, _) {
        final liveCustomer = khata.customers.firstWhere(
          (c) =>
              c.mobile == widget.customer.mobile ||
              (widget.customer.id.toString().isNotEmpty && c.id == widget.customer.id),
          orElse: () => widget.customer,
        );
        final isOverdue = liveCustomer.isOverdue;
        final utilization = liveCustomer.creditUtilizationPercent;

        // Filter transactions based on active pill
        final allTxs = khata.currentCustomerStatement;
        final filteredTxs = allTxs.where((tx) {
          if (_activeFilter == 'credit') return tx.isCredit;
          if (_activeFilter == 'payment') return tx.isPayment;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.isHindi ? 'वापस' : 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    liveCustomer.name.isNotEmpty ? liveCustomer.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        liveCustomer.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${liveCustomer.mobile} • ${allTxs.length} ${context.tr('khata_entries_count')}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Direct 1-tap Native PDF Statement Share (Bluetooth, WhatsApp, Instagram, etc.)
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 21, color: AppColors.primary),
                tooltip: context.isHindi ? 'लेजर शेयर करें (WhatsApp, Bluetooth...)' : 'Share Statement (WhatsApp, Bluetooth...)',
                onPressed: () => khata.shareStatementPdf(context, liveCustomer.mobile, customer: liveCustomer),
              ),
              // Direct 1-tap PDF Statement Download / Print
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 21, color: AppColors.primary),
                tooltip: context.isHindi ? 'पीडीएफ लेजर' : 'PDF Statement',
                onPressed: () => khata.openStatementPdf(context, liveCustomer.mobile, customer: liveCustomer),
              ),
              // Direct 1-tap WhatsApp Reminder (if dues > 0)
              if (liveCustomer.balance > 0)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21, color: Color(0xFF25D366)),
                  tooltip: context.isHindi ? 'व्हाट्सएप तगादा भेजें' : 'Send WhatsApp Reminder',
                  onPressed: () => khata.sendWhatsAppReminder(context, liveCustomer, transactions: allTxs),
                ),
              // More Menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 21,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'delete_customer') {
                    KhataDialogs.showDeleteCustomerDialog(context, liveCustomer);
                  } else if (val == 'copy_summary') {
                    final isHindi = context.isHindi;
                    final shop = LocalCacheService.getShop();
                    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
                    final text = SmartKhataReminderService.formatReminderMessage(
                      customer: liveCustomer,
                      shopName: shopName,
                      shopUpiId: shop?.upiId,
                      recentTransactions: allTxs,
                      isHindi: isHindi,
                    );
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('khata_copied_summary')),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (menuCtx) => [
                  PopupMenuItem<String>(
                    value: 'copy_summary',
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(menuCtx.isHindi ? 'खाता सारांश कॉपी करें' : 'Copy Ledger Summary'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'delete_customer',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(menuCtx.isHindi ? 'ग्राहक खाता डिलीट करें' : 'Delete Customer Account'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Body: Clean, Scrollable Passbook Layout
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Unified Clean Financial Summary Hero Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (liveCustomer.balance > 0 ? AppColors.error : AppColors.success)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (liveCustomer.balance > 0 ? AppColors.error : AppColors.success)
                          .withValues(alpha: 0.25),
                    ),
                  ),
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
                                Text(
                                  context.tr('khata_statement_dues'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${liveCustomer.balance.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: liveCustomer.balance > 0 ? AppColors.error : AppColors.success,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppBadge(
                                label: isOverdue
                                    ? context.tr('khata_tab_overdue')
                                    : (liveCustomer.balance == 0
                                        ? context.tr('khata_settled_badge')
                                        : (liveCustomer.balance > 0
                                            ? context.tr('khata_status_due')
                                            : context.tr('khata_status_advance'))),
                                type: isOverdue || liveCustomer.balance > 0
                                    ? AppBadgeType.error
                                    : (liveCustomer.balance == 0 ? AppBadgeType.success : AppBadgeType.primary),
                              ),
                              if (isOverdue && liveCustomer.overdueDays > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${liveCustomer.overdueDays} ${context.isHindi ? "दिन लेट" : "days late"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: (liveCustomer.balance > 0 ? AppColors.error : AppColors.success)
                            .withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => KhataDialogs.showSetCreditLimitDialog(context, liveCustomer),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 15,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      liveCustomer.creditLimit > 0
                                          ? '${context.tr("khata_credit_limit_label")}: ₹${liveCustomer.creditLimit.toStringAsFixed(0)} (${utilization.toStringAsFixed(0)}%)'
                                          : '${context.tr("khata_credit_limit_label")}: ₹0',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.colorTextSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => KhataDialogs.showSetPromiseDateDialog(context, liveCustomer),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 15,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      liveCustomer.promiseDate != null
                                          ? '${context.isHindi ? "वादा" : "Promise"}: ${DateFormat("dd MMM").format(liveCustomer.promiseDate!)}'
                                          : (context.isHindi ? 'तारीख तय करें' : 'Set date'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: liveCustomer.promiseDate != null
                                            ? AppColors.primary
                                            : context.colorTextMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (liveCustomer.balance > 0) ...[
                  const SizedBox(height: 12),
                  // Micro-Installment Settle Card
                  KhataMicroPlanCard(
                    customerPhone: liveCustomer.mobile,
                    customerName: liveCustomer.name,
                    currentBalance: liveCustomer.balance,
                  ),
                ],
                const SizedBox(height: 16),

                // 2. Transactions History Header & Filter Pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('khata_history_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (allTxs.length > 1)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFilterPill(
                            label: context.tr('khata_filter_all'),
                            isSelected: _activeFilter == 'all',
                            isDark: isDark,
                            onTap: () => setState(() => _activeFilter = 'all'),
                          ),
                          const SizedBox(width: 4),
                          _buildFilterPill(
                            label: context.tr('khata_filter_credit'),
                            isSelected: _activeFilter == 'credit',
                            isDark: isDark,
                            onTap: () => setState(() => _activeFilter = 'credit'),
                          ),
                          const SizedBox(width: 4),
                          _buildFilterPill(
                            label: context.tr('khata_filter_payment'),
                            isSelected: _activeFilter == 'payment',
                            isDark: isDark,
                            onTap: () => setState(() => _activeFilter = 'payment'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. Transactions Passbook List
                if (khata.isStatementLoading)
                  const AppListSkeleton(itemCount: 4)
                else if (filteredTxs.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 38,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('khata_history_empty'),
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTxs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final tx = filteredTxs[i];
                      final isCredit = tx.isCredit;
                      final isCancelled = tx.isCancelled;
                      final isEdited = tx.editReason.isNotEmpty;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Type Icon Badge
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCancelled
                                    ? (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.4)
                                    : (isCredit
                                        ? AppColors.error.withValues(alpha: 0.12)
                                        : AppColors.success.withValues(alpha: 0.12)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                                size: 16,
                                color: isCancelled
                                    ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                                    : (isCredit ? AppColors.error : AppColors.success),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Entry Info & Meta Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            color: isCancelled
                                                ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                                                : (isDark ? Colors.white : AppColors.textPrimary),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Payment mode pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tx.paymentMode.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tx.notes.isNotEmpty || (tx.billNumber?.isNotEmpty ?? false)) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (tx.billNumber?.isNotEmpty ?? false)
                                          '${context.isHindi ? "बिल" : "Bill"} #${tx.billNumber}',
                                        if (tx.notes.isNotEmpty) tx.notes,
                                      ].join(' • '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (isCancelled) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      context.isHindi ? 'रद्द प्रविष्टि (Cancelled)' : 'Cancelled Entry',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.error,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else if (isEdited) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${context.isHindi ? "संशोधन" : "Edit reason"}: ${tx.editReason}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Amounts & Running Balance Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: isCancelled ? FontWeight.w700 : FontWeight.w900,
                                    fontSize: isCancelled ? 13 : 15,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    color: isCancelled
                                        ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                                        : (isCredit ? AppColors.error : AppColors.success),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${context.tr('khata_running_balance')}: ₹${tx.balanceAfter.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),

                            // Options Menu (Edit / Reverse / Delete)
                            const SizedBox(width: 4),
                            if (isCancelled)
                              Tooltip(
                                message: context.isHindi
                                    ? 'यह प्रविष्टि रद्द की जा चुकी है'
                                    : 'This entry is cancelled',
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                ),
                              )
                            else
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  size: 18,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                                tooltip: context.isHindi ? 'प्रविष्टि विकल्प' : 'Entry Options',
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    KhataDialogs.showEditTransactionModal(
                                      context,
                                      tx,
                                      liveCustomer.id.toString(),
                                      liveCustomer.mobile,
                                      liveCustomer.balance,
                                    );
                                  } else if (val == 'reverse') {
                                    KhataDialogs.showReverseDialog(
                                      context,
                                      tx,
                                      liveCustomer.id.toString(),
                                      liveCustomer.mobile,
                                    );
                                  } else if (val == 'delete') {
                                    KhataDialogs.showDeleteTransactionDialog(
                                      context,
                                      tx,
                                      liveCustomer.id.toString(),
                                      liveCustomer.mobile,
                                      liveCustomer.balance,
                                    );
                                  }
                                },
                                itemBuilder: (menuCtx) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text(menuCtx.isHindi ? 'प्रविष्टि संपादित करें (Edit)' : 'Edit Entry'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'reverse',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.undo_rounded, size: 16, color: AppColors.warning),
                                        const SizedBox(width: 8),
                                        Text(menuCtx.isHindi ? 'प्रविष्टि वापस लें (Reverse)' : 'Reverse Entry'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                        const SizedBox(width: 8),
                                        Text(menuCtx.isHindi ? 'प्रविष्टि डिलीट करें (Delete)' : 'Delete Entry'),
                                      ],
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

          // Pinned Sticky Bottom Navigation Bar
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  offset: const Offset(0, -3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        KhataDialogs.showAddTransactionModal(
                          context,
                          customer: liveCustomer,
                          isCredit: true,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.arrow_outward_rounded, size: 17),
                      label: Text(
                        context.tr('khata_dialog_give_credit'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        KhataDialogs.showAddTransactionModal(
                          context,
                          customer: liveCustomer,
                          isCredit: false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.arrow_downward_rounded, size: 17),
                      label: Text(
                        context.tr('khata_dialog_receive_payment'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
