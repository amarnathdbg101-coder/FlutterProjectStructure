import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../models/khata_model.dart';
import '../services/smart_khata_reminder_service.dart';

/// Shows a responsive, minimalist bottom sheet / dialog to preview, customize, and share
/// an itemized payment reminder & passbook statement via WhatsApp or clipboard.
Future<void> showSmartPaymentReminderSheet(
  BuildContext context,
  KhataCustomerModel customer, {
  List<KhataTransactionModel>? transactions,
}) async {
  final isWide = MediaQuery.of(context).size.width > 600;

  if (isWide) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colorSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: _SmartPaymentReminderSheetContent(
            customer: customer,
            transactions: transactions,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Material(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: _SmartPaymentReminderSheetContent(
            customer: customer,
            transactions: transactions,
          ),
        ),
      ),
    ),
  );
}

class _SmartPaymentReminderSheetContent extends StatefulWidget {
  final KhataCustomerModel customer;
  final List<KhataTransactionModel>? transactions;

  const _SmartPaymentReminderSheetContent({
    required this.customer,
    this.transactions,
  });

  @override
  State<_SmartPaymentReminderSheetContent> createState() => _SmartPaymentReminderSheetContentState();
}

class _SmartPaymentReminderSheetContentState extends State<_SmartPaymentReminderSheetContent> {
  late TextEditingController _messageController;
  bool _includeRecentHistory = true;
  bool _includeUpiLink = true;
  String _shopName = '';
  String? _shopUpiId;

  @override
  void initState() {
    super.initState();
    final shop = LocalCacheService.getShop();
    _shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
    _shopUpiId = shop?.upiId?.isNotEmpty == true ? shop!.upiId : null;
    _includeUpiLink = _shopUpiId != null && _shopUpiId!.trim().isNotEmpty;

    _messageController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _regenerateMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _regenerateMessage() {
    final text = SmartKhataReminderService.formatReminderMessage(
      customer: widget.customer,
      shopName: _shopName,
      shopUpiId: _shopUpiId,
      recentTransactions: widget.transactions,
      includeRecentHistory: _includeRecentHistory,
      includeUpiLink: _includeUpiLink,
      isHindi: context.isHindi,
    );
    _messageController.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final hasDues = widget.customer.balance > 0;
    final hasUpi = _shopUpiId != null && _shopUpiId!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Drag handle / Header bar
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.colorBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header Title & Close Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: Color(0xFF25D366),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('khata_reminder_modal_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.customer.name} (${widget.customer.mobile})',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorTextMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 2. Scrollable Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outstanding Balance Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasDues
                        ? AppColors.error.withValues(alpha: 0.08)
                        : AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasDues
                          ? AppColors.error.withValues(alpha: 0.25)
                          : AppColors.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'वर्तमान कुल उधारी बकाया' : 'Current Outstanding Dues',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.colorTextMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.customer.isOverdue) ...[
                              const SizedBox(height: 2),
                              Text(
                                isHindi ? '⚠️ अतिदेय खाता (Overdue)' : '⚠️ Overdue Account',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${widget.customer.balance.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: hasDues ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Customization Toggles
                if (hasDues) ...[
                  if (widget.transactions != null && widget.transactions!.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        context.tr('khata_reminder_include_history'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isHindi ? 'पारदर्शिता हेतु पिछली प्रविष्टियां' : 'Shows last 3 entries for clarity',
                        style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                      ),
                      value: _includeRecentHistory,
                      onChanged: (val) {
                        setState(() {
                          _includeRecentHistory = val ?? true;
                          _regenerateMessage();
                        });
                      },
                    ),

                  if (hasUpi)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        context.tr('khata_reminder_include_upi'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'UPI: ${_shopUpiId!}',
                        style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _includeUpiLink,
                      onChanged: (val) {
                        setState(() {
                          _includeUpiLink = val ?? true;
                          _regenerateMessage();
                        });
                      },
                    ),

                  const SizedBox(height: 8),
                ],

                // Live Message Preview Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('khata_reminder_preview_label'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    InkWell(
                      onTap: _regenerateMessage,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              isHindi ? 'रीसेट' : 'Reset',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Message Text Field Container
                Container(
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Bottom Action Buttons Bar
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primary 1-Tap WhatsApp Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    context.tr('khata_reminder_btn_send_whatsapp'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final msg = _messageController.text.trim();
                    if (msg.isNotEmpty) {
                      SmartKhataReminderService.openWhatsApp(
                        context: context,
                        mobile: widget.customer.mobile,
                        message: msg,
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Secondary Row: Copy Message & Copy UPI Link
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: context.colorBorder),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        context.tr('khata_reminder_btn_copy_message'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        final msg = _messageController.text.trim();
                        if (msg.isNotEmpty) {
                          SmartKhataReminderService.copyMessageToClipboard(
                            context: context,
                            message: msg,
                          );
                        }
                      },
                    ),
                  ),
                  if (hasUpi && hasDues) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 14, color: AppColors.primary),
                        label: Text(
                          context.tr('khata_reminder_btn_copy_upi'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          SmartKhataReminderService.copyUpiLinkToClipboard(
                            context: context,
                            upiId: _shopUpiId!,
                            shopName: _shopName,
                            amount: widget.customer.balance,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
