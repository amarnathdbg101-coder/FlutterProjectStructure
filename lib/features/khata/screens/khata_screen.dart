import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/reusable/app_search_field.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../controllers/khata_controller.dart';
import '../models/khata_model.dart';
import '../repositories/khata_repository.dart';
import '../services/smart_khata_reminder_service.dart';
import '../widgets/khata_micro_plan_card.dart';

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
    final khataController = context.read<KhataController>();

    // Form state variables
    bool currentIsCredit = isCredit;
    KhataCustomerModel? selectedCustomer = customer;
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.mobile ?? '');
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final billNoCtrl = TextEditingController();
    String paymentMode = 'cash';
    bool isSaving = false;

    void addPreset(double preset) {
      final current = double.tryParse(amountCtrl.text) ?? 0.0;
      final next = current + preset;
      amountCtrl.text = next.toStringAsFixed(0);
    }

    Widget buildFormContent(BuildContext ctx, StateSetter setModalState) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final customers = khataController.customers;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title and Close Header
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('khata_add_btn'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
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
          const SizedBox(height: 8),

          // Scrollable Form Body with Stretch Constraints
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mode Toggle (Udhar Diya vs Jama Kiya)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => currentIsCredit = true);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: currentIsCredit ? AppColors.error : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 16,
                                    color: currentIsCredit
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('khata_dialog_give_credit'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: currentIsCredit
                                            ? Colors.white
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => currentIsCredit = false);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !currentIsCredit ? AppColors.success : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: !currentIsCredit
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('khata_dialog_receive_payment'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: !currentIsCredit
                                            ? Colors.white
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Customer Selection Section
                  if (customer != null) ...[
                    // Locked Customer Card
                    Builder(builder: (context) {
                      final live = customers.firstWhere(
                        (c) => c.mobile == customer.mobile || (customer.id.toString().isNotEmpty && c.id == customer.id),
                        orElse: () => customer,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                live.name.isNotEmpty ? live.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    live.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    live.mobile,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${live.balance.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: live.balance > 0 ? AppColors.error : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Quick Recent Customer Chips (if available)
                    if (customers.isNotEmpty) ...[
                      Text(
                        context.tr('khata_recent_customers'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // New Customer Chip
                            ActionChip(
                              avatar: const Icon(Icons.person_add_rounded, size: 14),
                              label: Text(
                                context.tr('khata_new_customer'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: selectedCustomer == null
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
                              side: BorderSide(
                                color: selectedCustomer == null ? AppColors.primary : Colors.transparent,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  selectedCustomer = null;
                                  nameCtrl.clear();
                                  phoneCtrl.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            // Recent Customers
                            ...customers.take(8).map((c) {
                              final isSelected = selectedCustomer == c;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: c.balance > 0
                                        ? AppColors.error.withValues(alpha: 0.2)
                                        : AppColors.success.withValues(alpha: 0.2),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: c.balance > 0 ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                  ),
                                  label: Text(
                                    '${c.name} • ₹${c.balance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                    ),
                                  ),
                                  backgroundColor: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedCustomer = c;
                                      nameCtrl.text = c.name;
                                      phoneCtrl.text = c.mobile;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Input fields for Name & Mobile
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: context.tr('khata_field_customer_name'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        suffixIcon: AppVoiceIconButton(
                          controller: nameCtrl,
                          hint: context.tr('khata_field_customer_name'),
                        ),
                      ),
                      onChanged: (_) {
                        if (selectedCustomer != null) {
                          setModalState(() => selectedCustomer = null);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('khata_field_customer_phone'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                        suffixIcon: AppVoiceIconButton(
                          controller: phoneCtrl,
                          hint: context.tr('khata_field_customer_phone'),
                        ),
                      ),
                      onChanged: (val) {
                        final clean = KhataRepository.normalizePhone(val);
                        if (clean.length == 10) {
                          final match = customers.firstWhere(
                            (c) => c.mobile == clean || c.mobile.endsWith(clean),
                            orElse: () => KhataCustomerModel(id: '', name: '', mobile: '', balance: 0),
                          );
                          if (match.mobile.isNotEmpty) {
                            setModalState(() {
                              selectedCustomer = match;
                              if (nameCtrl.text.trim().isEmpty) {
                                nameCtrl.text = match.name;
                              }
                            });
                            return;
                          }
                        }
                        if (selectedCustomer != null) {
                          setModalState(() => selectedCustomer = null);
                        }
                      },
                    ),
                    if (selectedCustomer != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${selectedCustomer!.name} (${selectedCustomer!.mobile})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Current: ₹${selectedCustomer!.balance.abs().toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selectedCustomer!.balance > 0 ? AppColors.error : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],

                  // Amount Input
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: currentIsCredit ? AppColors.error : AppColors.success,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('khata_field_amount'),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: currentIsCredit ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Amount Preset Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          context.tr('khata_quick_presets'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (final preset in [100.0, 200.0, 500.0, 1000.0, 2000.0])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('+₹${preset.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                              backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: () {
                                setModalState(() {
                                  addPreset(preset);
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Mode Selection (When Receiving Payment)
                  if (!currentIsCredit) ...[
                    Text(
                      context.tr('khata_field_payment_mode'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text(context.tr('khata_mode_cash'))),
                            selected: paymentMode == 'cash',
                            onSelected: (val) {
                              if (val) setModalState(() => paymentMode = 'cash');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text(context.tr('khata_mode_upi'))),
                            selected: paymentMode == 'upi',
                            onSelected: (val) {
                              if (val) setModalState(() => paymentMode = 'upi');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text(context.tr('khata_mode_cheque'))),
                            selected: paymentMode == 'cheque',
                            onSelected: (val) {
                              if (val) setModalState(() => paymentMode = 'cheque');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Bill / Invoice Number (Optional)
                  TextField(
                    controller: billNoCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('khata_field_bill_no'),
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      suffixIcon: AppVoiceIconButton(
                        controller: billNoCtrl,
                        hint: context.tr('khata_field_bill_no'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Notes / Reason
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('khata_field_notes'),
                      prefixIcon: const Icon(Icons.notes_rounded),
                      suffixIcon: AppVoiceIconButton(
                        controller: notesCtrl,
                        hint: context.tr('khata_field_notes'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error banner if any
                  if (khataController.hasError) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              khataController.errorMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons Footer
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  text: context.tr('btn_cancel'),
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: context.tr('btn_save'),
                  variant: currentIsCredit ? AppButtonVariant.danger : AppButtonVariant.success,
                  isLoading: isSaving,
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final cleanPhone = KhataRepository.normalizePhone(phone);

                          if (amount <= 0 || name.isEmpty || cleanPhone.length < 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(cleanPhone.length < 10 && phone.isNotEmpty
                                    ? 'Please enter a valid 10-digit mobile number'
                                    : context.tr('inv_val_required')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);

                          final bool success;
                          if (currentIsCredit) {
                            success = await khataController.addCredit(
                              customerName: name,
                              mobile: cleanPhone,
                              amount: amount,
                              notes: notesCtrl.text.trim(),
                              billNumber: billNoCtrl.text.trim(),
                            );
                          } else {
                            success = await khataController.addPayment(
                              customerName: name,
                              mobile: cleanPhone,
                              amount: amount,
                              paymentMode: paymentMode,
                              notes: notesCtrl.text.trim(),
                            );
                          }

                          if (ctx.mounted) {
                            setModalState(() => isSaving = false);
                            if (success) {
                              Navigator.pop(ctx);

                              final remainingBal = khataController.getCustomerBalance(cleanPhone);
                              final shop = LocalCacheService.getShop();
                              final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Store';

                              if (currentIsCredit && cleanPhone.length >= 10) {
                                final msg = Uri.encodeComponent(
                                  '📖 *Khata Udhar Slip - $shopName*\n'
                                  'Dear $name,\n'
                                  '₹${amount.toStringAsFixed(0)} has been added to your khata ledger.\n'
                                  'Total Outstanding Balance: ₹${remainingBal.toStringAsFixed(0)}.\n\n'
                                  'Thank you for shopping with us!',
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Credit of ₹${amount.toStringAsFixed(0)} added! Total: ₹${remainingBal.toStringAsFixed(0)}'),
                                    backgroundColor: AppColors.error,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'WhatsApp Slip',
                                      textColor: Colors.white,
                                      onPressed: () async {
                                        await WhatsAppShareHelper.shareToWhatsApp(
                                          context: context,
                                          phone: cleanPhone,
                                          message: Uri.decodeComponent(msg),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              } else if (!currentIsCredit && cleanPhone.length >= 10) {
                                final msg = Uri.encodeComponent(
                                  '🧾 *Khata Payment Receipt*\n'
                                  'Dear $name,\n'
                                  'Thank you! Your payment of ₹${amount.toStringAsFixed(0)} (${paymentMode.toUpperCase()}) was received at $shopName.\n'
                                  'Remaining Khata Balance: ₹${remainingBal.toStringAsFixed(0)}.\n\n'
                                  'Thank you for shopping with us!',
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Payment of ₹${amount.toStringAsFixed(0)} received! Remaining: ₹${remainingBal.toStringAsFixed(0)}'),
                                    backgroundColor: AppColors.success,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'WhatsApp Receipt',
                                      textColor: Colors.white,
                                      onPressed: () async {
                                        await WhatsAppShareHelper.shareToWhatsApp(
                                          context: context,
                                          phone: cleanPhone,
                                          message: Uri.decodeComponent(msg),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr('khata_toast_saved')),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(khataController.errorMessage ?? 'Failed to save khata entry'),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final keyboardHeight = MediaQuery.of(sheetCtx).viewInsets.bottom;
          final screenHeight = MediaQuery.of(sheetCtx).size.height;
          final maxModalHeight = (screenHeight - keyboardHeight - 24).clamp(280.0, screenHeight * 0.88);

          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: maxModalHeight,
                  constraints: const BoxConstraints(maxWidth: 580),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SafeArea(
                    top: false,
                    child: buildFormContent(sheetCtx, setModalState),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // DIALOG: SET PAYMENT PROMISE DATE
  // ==========================================
  Future<void> _showSetPromiseDateDialog(BuildContext context, KhataCustomerModel customer) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: customer.promiseDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: context.tr('khata_select_date'),
    );

    if (picked != null && context.mounted) {
      final success = await context.read<KhataController>().setPromiseDate(
            customer.id.toString(),
            picked,
            customer.mobile,
          );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('khata_toast_promise_saved'))),
        );
      }
    }
  }

  // ==========================================
  // DIALOG: SET CREDIT LIMIT
  // ==========================================
  void _showSetCreditLimitDialog(BuildContext context, KhataCustomerModel customer) {
    final limitCtrl = TextEditingController(text: customer.creditLimit.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('khata_enter_credit_limit'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Max Limit',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [5000, 10000, 25000, 50000].map((val) {
                    return ActionChip(
                      label: Text('₹$val'),
                      onPressed: () {
                        limitCtrl.text = val.toString();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.outline(
                      text: context.tr('btn_cancel'),
                      size: AppButtonSize.sm,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      text: context.tr('btn_save'),
                      size: AppButtonSize.sm,
                      onPressed: () async {
                        final newLimit = double.tryParse(limitCtrl.text) ?? 10000.0;
                        final ok = await context
                            .read<KhataController>()
                            .updateCreditLimit(customer.mobile, newLimit);
                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('khata_toast_limit_saved'))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DIALOG: REVERSE TRANSACTION
  // ==========================================
  void _showReverseDialog(
    BuildContext context,
    KhataTransactionModel tx,
    String khataId,
    String customerMobile,
  ) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.undo_rounded, color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('khata_btn_reverse'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('khata_reverse_confirm'),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    hintText: context.tr('khata_reverse_reason'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.outline(
                      text: context.tr('btn_cancel'),
                      size: AppButtonSize.sm,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: 8),
                    AppButton.danger(
                      text: context.tr('btn_confirm'),
                      size: AppButtonSize.sm,
                      onPressed: () async {
                        final ok = await context.read<KhataController>().reverseTransaction(
                              khataId,
                              tx.id.toString(),
                              customerMobile,
                              reason: reasonCtrl.text.trim(),
                            );
                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('khata_toast_reversed'))),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL: EDIT KHATA TRANSACTION ENTRY (SECURE)
  // ==========================================
  void _showEditTransactionModal(
    BuildContext context,
    KhataTransactionModel tx,
    String khataId,
    String customerMobile,
    double currentCustomerBalance,
  ) {
    final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: tx.notes);
    final billNoCtrl = TextEditingController(text: tx.billNumber ?? '');
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool isSaving = false;
    bool obscurePin = true;
    String? validationError;

    final quickReasons = [
      context.isHindi ? 'गलत राशि सुधार' : 'Amount Correction',
      context.isHindi ? 'बिल संशोधन' : 'Bill Updated',
      context.isHindi ? 'डिस्काउंट समायोजन' : 'Discount Adjustment',
      context.isHindi ? 'ग्राहक अनुरोध' : 'Customer Request',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final double enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final double amountDiff = enteredAmount - tx.amount;
          final double projectedBalance = tx.isCredit
              ? currentCustomerBalance + amountDiff
              : currentCustomerBalance - amountDiff;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isHindi ? 'लेजर प्रविष्टि संपादित करें' : 'Edit Ledger Entry',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                tx.isCredit
                                    ? (context.isHindi ? 'उधार प्रविष्टि (GIVE CREDIT)' : 'Credit Given Entry')
                                    : (context.isHindi ? 'जमा प्रविष्टि (PAYMENT)' : 'Payment Received Entry'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tx.isCredit ? AppColors.error : AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Current vs Projected Impact Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.isHindi ? 'मूल राशि:' : 'Original Amount:',
                                style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                              ),
                              Text(
                                '₹${tx.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.isHindi ? 'अनुमानित बकाया:' : 'Projected Due:',
                                style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹${currentCustomerBalance.toStringAsFixed(0)} ➔ ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colorTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    '₹${projectedBalance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: projectedBalance > currentCustomerBalance
                                          ? AppColors.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount Field
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.isHindi ? 'नई संशोधित राशि (₹) *' : 'New Amount (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Bill Number & Notes Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: billNoCtrl,
                            decoration: InputDecoration(
                              labelText: context.isHindi ? 'बिल सं. (वैकल्पिक)' : 'Bill No (Opt)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: notesCtrl,
                            decoration: InputDecoration(
                              labelText: context.isHindi ? 'विवरण (वैकल्पिक)' : 'Notes (Opt)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Mandatory Audit Reason Label
                    Text(
                      context.isHindi ? 'संशोधन का कारण (अनिवार्य) *' : 'Reason for Modification (Mandatory) *',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: quickReasons.map((chipText) {
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              reasonCtrl.text = chipText;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: reasonCtrl.text == chipText
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: reasonCtrl.text == chipText
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            child: Text(
                              chipText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: reasonCtrl.text == chipText ? FontWeight.bold : FontWeight.normal,
                                color: reasonCtrl.text == chipText ? AppColors.primary : context.colorTextSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: context.isHindi ? 'कारण लिखें (कम से कम 3 अक्षर)' : 'Reason (min 3 chars)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Master Security PIN / Password
                    TextField(
                      controller: pinCtrl,
                      obscureText: obscurePin,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: context.isHindi ? 'सुरक्षा पिन / पासवर्ड *' : 'Security PIN / Password *',
                        hintText: context.isHindi ? 'मास्टर पिन (1234) या खाता पासवर्ड' : 'Master PIN (1234) or Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                        ),
                      ),
                    ),

                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.outline(
                          text: context.tr('btn_cancel'),
                          size: AppButtonSize.sm,
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        AppButton.primary(
                          text: isSaving
                              ? (context.isHindi ? 'अपडेट हो रहा है...' : 'Saving...')
                              : (context.isHindi ? 'सुरक्षित अपडेट करें' : 'Save Changes'),
                          size: AppButtonSize.sm,
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                                  final reason = reasonCtrl.text.trim();
                                  final pin = pinCtrl.text.trim();

                                  if (amt <= 0) {
                                    setDialogState(() {
                                      validationError = context.isHindi
                                          ? 'कृपया मान्य राशि (> 0) दर्ज करें'
                                          : 'Please enter a valid amount (> 0)';
                                    });
                                    return;
                                  }

                                  if (reason.length < 3) {
                                    setDialogState(() {
                                      validationError = context.isHindi
                                          ? 'कारण लिखना अनिवार्य है (कम से कम 3 अक्षर)'
                                          : 'Mandatory reason required (min 3 chars)';
                                    });
                                    return;
                                  }

                                  setDialogState(() {
                                    isSaving = true;
                                    validationError = null;
                                  });

                                  final khataCtrl = context.read<KhataController>();
                                  final success = await khataCtrl.updateTransaction(
                                    khataId: khataId,
                                    txId: tx.id.toString(),
                                    customerMobile: customerMobile,
                                    amount: amt,
                                    notes: notesCtrl.text.trim(),
                                    billNumber: billNoCtrl.text.trim(),
                                    reason: reason,
                                    securityPin: pin,
                                    password: pin,
                                  );

                                  if (ctx.mounted) {
                                    if (success) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.isHindi
                                                ? '✓ प्रविष्टि सफलतापूर्वक अपडेट की गई'
                                                : '✓ Entry updated successfully',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      setDialogState(() {
                                        isSaving = false;
                                        validationError = khataCtrl.errorMessage ??
                                            (context.isHindi
                                                ? 'अपडेट विफल हुआ। कृपया पिन/पासवर्ड जांचें।'
                                                : 'Update failed. Please check PIN/password.');
                                      });
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // DIALOG: DELETE TRANSACTION ENTRY (SAFE 2-STEP WITH AUDIT)
  // ==========================================
  void _showDeleteTransactionDialog(
    BuildContext context,
    KhataTransactionModel tx,
    String khataId,
    String customerMobile, [
    double currentCustomerBalance = 0.0,
  ]) {
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool isDeleting = false;
    bool obscurePin = true;
    String? validationError;

    final quickReasons = [
      context.isHindi ? 'गलत प्रविष्टि' : 'Mistake Entry',
      context.isHindi ? 'डुप्लीकेट बिल' : 'Duplicate Bill',
      context.isHindi ? 'बिल रद्द हुआ' : 'Bill Cancelled',
      context.isHindi ? 'ग्राहक से समझौता' : 'Customer Settlement',
    ];

    // Deletion reversal impact:
    // If we delete CREDIT: customer owed this, now they don't -> balance decreases
    // If we delete PAYMENT: customer paid this, now it's reversed -> balance increases
    final double resultingBalance = tx.isCredit
        ? currentCustomerBalance - tx.amount
        : currentCustomerBalance + tx.amount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.isHindi ? 'प्रविष्टि रद्द / डिलीट करें' : 'Cancel / Delete Entry',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Security & Reversal Explanation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, size: 16, color: AppColors.error),
                              const SizedBox(width: 6),
                              Text(
                                context.isHindi ? 'सुरक्षित वित्तीय ऑडिट' : 'Secure Financial Audit',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.isHindi
                                ? 'यह प्रविष्टि पूरी तरह मिटाई नहीं जाएगी, बल्कि "रद्द" (Soft Cancelled) की जाएगी। लेजर बैलेंस स्वतः समायोजित होगा।'
                                : 'This entry will not be erased; it will be marked "Cancelled" with an audit trail. Balance will be recalculated.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.isHindi ? 'प्रभाव:' : 'Balance Impact:',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹${currentCustomerBalance.toStringAsFixed(0)} ➔ ₹${resultingBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mandatory Reason Chips
                    Text(
                      context.isHindi ? 'डिलीट करने का कारण (अनिवार्य) *' : 'Reason for Deletion (Mandatory) *',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: quickReasons.map((chipText) {
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              reasonCtrl.text = chipText;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: reasonCtrl.text == chipText
                                  ? AppColors.error.withValues(alpha: 0.15)
                                  : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: reasonCtrl.text == chipText
                                    ? AppColors.error
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                            ),
                            child: Text(
                              chipText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: reasonCtrl.text == chipText ? FontWeight.bold : FontWeight.normal,
                                color: reasonCtrl.text == chipText ? AppColors.error : context.colorTextSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: context.isHindi ? 'कारण लिखें (उदा. गलत एंट्री दर्ज हो गई)' : 'Reason (e.g. Wrong entry)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // PIN / Password
                    TextField(
                      controller: pinCtrl,
                      obscureText: obscurePin,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: context.isHindi ? 'मास्टर सुरक्षा पिन / पासवर्ड *' : 'Security PIN / Password *',
                        hintText: context.isHindi ? 'मास्टर पिन (1234) या पासवर्ड' : 'Master PIN (1234) or Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                        ),
                      ),
                    ),

                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.outline(
                          text: context.tr('btn_cancel'),
                          size: AppButtonSize.sm,
                          onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        AppButton.danger(
                          text: isDeleting
                              ? (context.isHindi ? 'डिलीट हो रहा है...' : 'Deleting...')
                              : (context.isHindi ? 'सुरक्षित डिलीट करें' : 'Delete Entry'),
                          size: AppButtonSize.sm,
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  final reason = reasonCtrl.text.trim();
                                  final pin = pinCtrl.text.trim();

                                  if (reason.length < 3) {
                                    setDialogState(() {
                                      validationError = context.isHindi
                                          ? 'डिलीट करने का कारण लिखना अनिवार्य है (कम से कम 3 अक्षर)'
                                          : 'Mandatory reason required (min 3 chars)';
                                    });
                                    return;
                                  }

                                  setDialogState(() {
                                    isDeleting = true;
                                    validationError = null;
                                  });

                                  final khataCtrl = context.read<KhataController>();
                                  final success = await khataCtrl.deleteTransaction(
                                    khataId,
                                    tx.id.toString(),
                                    customerMobile,
                                    reason: reason,
                                    securityPin: pin,
                                    password: pin,
                                  );

                                  if (ctx.mounted) {
                                    if (success) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.isHindi
                                                ? '✓ प्रविष्टि सफलतापूर्वक रद्द कर दी गई'
                                                : '✓ Entry cancelled successfully',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      setDialogState(() {
                                        isDeleting = false;
                                        validationError = khataCtrl.errorMessage ??
                                            (context.isHindi
                                                ? 'डिलीट विफल हुआ। कृपया पिन/पासवर्ड जांचें।'
                                                : 'Delete failed. Check PIN/password.');
                                      });
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // DIALOG: DELETE CUSTOMER KHATA ACCOUNT (SAFE 2-STEP)
  // ==========================================
  void _showDeleteCustomerDialog(
    BuildContext context,
    KhataCustomerModel customer,
  ) {
    final bool hasPendingDues = customer.balance.abs() > 0.01;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasPendingDues
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          hasPendingDues ? Icons.warning_amber_rounded : Icons.delete_forever_rounded,
                          color: hasPendingDues ? AppColors.warning : AppColors.error,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasPendingDues
                              ? (context.isHindi ? 'खाता डिलीट नहीं हो सकता' : 'Cannot Delete Account')
                              : (context.isHindi ? 'ग्राहक खाता डिलीट करें' : 'Delete Customer Account'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (hasPendingDues) ...[
                    Text(
                      context.isHindi
                          ? 'इस ग्राहक (${customer.name}) का ₹${customer.balance.toStringAsFixed(0)} का उधारी बैलेंस बाकी है। सुरक्षा कारणों से खाता डिलीट करने से पहले बैलेंस 0 (चुका) करें।'
                          : '${customer.name} has an active balance of ₹${customer.balance.toStringAsFixed(0)}. Please settle the balance before deleting this account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton.primary(
                        text: context.isHindi ? 'ठीक है' : 'OK',
                        size: AppButtonSize.sm,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ] else ...[
                    Text(
                      context.isHindi
                          ? 'क्या आप वाकई ${customer.name} (${customer.mobile}) का खाता हमेशा के लिए डिलीट करना चाहते हैं? यह क्रिया वापस नहीं की जा सकती।'
                          : 'Are you sure you want to permanently delete ${customer.name}\'s (${customer.mobile}) khata account?',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.outline(
                          text: context.tr('btn_cancel'),
                          size: AppButtonSize.sm,
                          onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        AppButton.danger(
                          text: isDeleting ? 'Deleting...' : (context.isHindi ? 'डिलीट करें' : 'Delete Account'),
                          size: AppButtonSize.sm,
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  setDialogState(() => isDeleting = true);
                                  final khataCtrl = context.read<KhataController>();
                                  final success = await khataCtrl.deleteCustomer(
                                    customer.id.toString(),
                                    customer.mobile,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? (context.isHindi ? '✓ ग्राहक खाता डिलीट हुआ' : '✓ Customer account deleted')
                                              : (khataCtrl.errorMessage ?? 'Failed to delete customer'),
                                        ),
                                        backgroundColor: success ? AppColors.success : AppColors.error,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SHEET: CUSTOMER PASSBOOK & STATEMENT
  // ==========================================
  void _showCustomerStatementSheet(BuildContext context, KhataCustomerModel customer) {
    context.read<KhataController>().loadStatement(customer.mobile);
    String activeFilter = 'all'; // 'all', 'credit', 'payment'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Consumer<KhataController>(
            builder: (context, khata, _) {
              final liveCustomer = khata.customers.firstWhere(
                (c) => c.mobile == customer.mobile || (customer.id.toString().isNotEmpty && c.id == customer.id),
                orElse: () => customer,
              );
              final isOverdue = liveCustomer.isOverdue;
              final utilization = liveCustomer.creditUtilizationPercent;

              // Filter transactions based on active pill
              final allTxs = khata.currentCustomerStatement;
              final filteredTxs = allTxs.where((tx) {
                if (activeFilter == 'credit') return tx.isCredit;
                if (activeFilter == 'payment') return tx.isPayment;
                return true;
              }).toList();

              return Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.90,
                      maxWidth: 620,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle Pill
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header Row (Customer info & Close)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  liveCustomer.name.isNotEmpty ? liveCustomer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
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
                                      liveCustomer.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      children: [
                                        Text(
                                          liveCustomer.mobile,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          ' • ${allTxs.length} ${context.tr('khata_entries_count')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? Colors.white : AppColors.textPrimary),
                                tooltip: context.isHindi ? 'ग्राहक विकल्प' : 'Customer Options',
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val == 'delete_customer') {
                                    _showDeleteCustomerDialog(context, liveCustomer);
                                  } else if (val == 'send_pdf') {
                                    khata.openStatementPdf(context, liveCustomer.mobile, customer: liveCustomer);
                                  }
                                },
                                itemBuilder: (menuCtx) => [
                                  PopupMenuItem<String>(
                                    value: 'send_pdf',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text(menuCtx.isHindi ? 'पीडीएफ लेजर डाउनलोड' : 'Download PDF Statement'),
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
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                splashRadius: 18,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Scrollable Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 14,
                              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Net Outstanding Dues Hero Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: (liveCustomer.balance > 0 ? AppColors.error : AppColors.success)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: (liveCustomer.balance > 0 ? AppColors.error : AppColors.success)
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.tr('khata_statement_dues'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (isOverdue)
                                            AppBadge(
                                              label: context.tr('khata_tab_overdue'),
                                              type: AppBadgeType.error,
                                            )
                                          else if (liveCustomer.balance == 0)
                                            AppBadge(
                                              label: context.tr('khata_settled_badge'),
                                              type: AppBadgeType.success,
                                            )
                                          else
                                            AppBadge(
                                              label: context.tr('khata_status_due'),
                                              type: AppBadgeType.neutral,
                                            ),
                                        ],
                                      ),
                                      FittedBox(
                                        child: Text(
                                          '₹${liveCustomer.balance.abs().toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: liveCustomer.balance > 0 ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 2. Credit Limit & Promise Date Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showSetCreditLimitDialog(context, liveCustomer),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorder : AppColors.border,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    context.tr('khata_credit_limit_label'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '₹${liveCustomer.creditLimit.toStringAsFixed(0)} (${utilization.toStringAsFixed(0)}%)',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showSetPromiseDateDialog(context, liveCustomer),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorder : AppColors.border,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    context.tr('khata_promise_label'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primary),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                liveCustomer.promiseDate != null
                                                    ? DateFormat('dd MMM yyyy').format(liveCustomer.promiseDate!)
                                                    : 'Not Set',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // 2B. Daily Micro-Installment Settle Card (Chillar Settle)
                                KhataMicroPlanCard(
                                  customerPhone: liveCustomer.mobile,
                                  customerName: liveCustomer.name,
                                  currentBalance: liveCustomer.balance,
                                ),
                                const SizedBox(height: 10),

                                // 3. Primary Quick Action Buttons (+Udhar & +Jama)
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton.danger(
                                        icon: Icons.arrow_outward_rounded,
                                        text: context.tr('khata_dialog_give_credit'),
                                        isFullWidth: true,
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await Future.delayed(const Duration(milliseconds: 150));
                                          if (context.mounted) {
                                            _showAddTransactionModal(context, customer: liveCustomer, isCredit: true);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        icon: Icons.arrow_downward_rounded,
                                        text: context.tr('khata_dialog_receive_payment'),
                                        variant: AppButtonVariant.success,
                                        isFullWidth: true,
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await Future.delayed(const Duration(milliseconds: 150));
                                          if (context.mounted) {
                                            _showAddTransactionModal(context, customer: liveCustomer, isCredit: false);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // 4. Secondary Utilities Toolbar (PDF, WhatsApp, Copy)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                                        label: Text(
                                          context.tr('khata_btn_download_pdf'),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => khata.openStatementPdf(context, liveCustomer.mobile, customer: liveCustomer),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF25D366)),
                                        label: Text(
                                          context.tr('khata_btn_whatsapp_reminder'),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF25D366)),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF25D366)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => khata.sendWhatsAppReminder(context, liveCustomer, transactions: allTxs),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
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
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // 5. Transactions History Header & Filter Pills
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.tr('khata_history_title'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (allTxs.length > 1)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildFilterPill(
                                            label: context.tr('khata_filter_all'),
                                            isSelected: activeFilter == 'all',
                                            isDark: isDark,
                                            onTap: () => setModalState(() => activeFilter = 'all'),
                                          ),
                                          const SizedBox(width: 4),
                                          _buildFilterPill(
                                            label: context.tr('khata_filter_credit'),
                                            isSelected: activeFilter == 'credit',
                                            isDark: isDark,
                                            onTap: () => setModalState(() => activeFilter = 'credit'),
                                          ),
                                          const SizedBox(width: 4),
                                          _buildFilterPill(
                                            label: context.tr('khata_filter_payment'),
                                            isSelected: activeFilter == 'payment',
                                            isDark: isDark,
                                            onTap: () => setModalState(() => activeFilter = 'payment'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // 6. Transactions Passbook List (Zero nested scroll-fighting)
                                if (khata.isStatementLoading)
                                  const AppListSkeleton(itemCount: 4)
                                else if (filteredTxs.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 36,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr('khata_history_empty'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('khata_empty_statement_action'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredTxs.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                                    itemBuilder: (context, idx) {
                                      final tx = filteredTxs[idx];
                                      final isCredit = tx.isCredit;
                                      final isCancelled = tx.isCancelled;
                                      final isEdited = tx.editReason.isNotEmpty;

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isCancelled
                                              ? (isDark ? AppColors.error.withValues(alpha: 0.05) : AppColors.error.withValues(alpha: 0.03))
                                              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCancelled
                                                ? AppColors.error.withValues(alpha: 0.25)
                                                : (isDark ? AppColors.darkBorder : AppColors.border),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Status Icon Indicator
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isCancelled
                                                    ? AppColors.error.withValues(alpha: 0.1)
                                                    : (isCredit ? AppColors.error : AppColors.success).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isCancelled
                                                    ? Icons.block_rounded
                                                    : (isCredit ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded),
                                                color: isCancelled ? AppColors.error : (isCredit ? AppColors.error : AppColors.success),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Details Column
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        isCredit
                                                            ? context.tr('khata_dialog_give_credit')
                                                            : context.tr('khata_dialog_receive_payment'),
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 13,
                                                          color: isCancelled
                                                              ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                                                              : null,
                                                        ),
                                                      ),
                                                      if (isCancelled) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.error.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                                          ),
                                                          child: Text(
                                                            context.isHindi ? 'रद्द (CANCELLED)' : 'CANCELLED',
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.error,
                                                            ),
                                                          ),
                                                        ),
                                                      ] else if (isEdited) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primary.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            context.isHindi ? 'संपादित' : 'EDITED',
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (tx.paymentMode.isNotEmpty && tx.paymentMode.toLowerCase() != 'cash') ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primary.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            tx.paymentMode.toUpperCase(),
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                                        ),
                                                      ),
                                                      if (tx.billNumber != null && tx.billNumber!.isNotEmpty) ...[
                                                        Text(
                                                          ' • #${tx.billNumber}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                      if (isEdited && tx.originalAmount != null && tx.originalAmount! > 0 && tx.originalAmount != tx.amount) ...[
                                                        Text(
                                                          ' • ${context.isHindi ? "मूल" : "Orig"}: ₹${tx.originalAmount!.toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (tx.notes.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      tx.notes,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                  if (isCancelled && tx.deleteReason.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${context.isHindi ? "कारण" : "Reason"}: ${tx.deleteReason}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontStyle: FontStyle.italic,
                                                        color: AppColors.error,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ] else if (isEdited && tx.editReason.isNotEmpty) ...[
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
                                                    fontSize: isCancelled ? 13 : 14,
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
                                                message: context.isHindi ? 'यह प्रविष्टि रद्द की जा चुकी है' : 'This entry is cancelled',
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
                                                    _showEditTransactionModal(
                                                      context,
                                                      tx,
                                                      liveCustomer.id.toString(),
                                                      liveCustomer.mobile,
                                                      liveCustomer.balance,
                                                    );
                                                  } else if (val == 'reverse') {
                                                    _showReverseDialog(
                                                      context,
                                                      tx,
                                                      liveCustomer.id.toString(),
                                                      liveCustomer.mobile,
                                                    );
                                                  } else if (val == 'delete') {
                                                    _showDeleteTransactionDialog(
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  case 'add':
                    _showAddTransactionModal(context, isCredit: true);
                    break;
                  case 'broadcast':
                    khata.broadcastWhatsAppOverdueReminders(context);
                    break;
                  case 'aging':
                    _showAgingBreakdownSheet(context);
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
                PopupMenuItem(
                  value: 'aging',
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'उधारी एजिंग रिपोर्ट' : 'View Aging Report'),
                    ],
                  ),
                ),
                if (khata.overdueCount > 0)
                  PopupMenuItem(
                    value: 'broadcast',
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFF25D366), size: 18),
                        const SizedBox(width: 10),
                        Text(ctx.isHindi ? 'व्हाट्सएप तगादा भेजें' : 'Send WhatsApp Reminders'),
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
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            context.tr('khata_add_btn'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.colorPrimaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('khata_banner_title'),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: context.colorTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${khata.debtorsCount} ${context.tr('khata_kpi_debtors')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.colorTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showAddTransactionModal(context, isCredit: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(100, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.remove_circle_outline, size: 14),
                              label: Text(context.isHindi ? 'दिए (उधारी)' : '+ Give Credit'),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _showAddTransactionModal(context, isCredit: false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(color: AppColors.success, width: 1.2),
                                minimumSize: const Size(100, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.add_circle_outline, size: 14),
                              label: Text(context.isHindi ? 'मिले (जमा)' : '+ Settle Cash'),
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
                    ? AppColors.error.withValues(alpha: 0.12)
                    : (isAdvance
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.success.withValues(alpha: 0.12)),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: hasDues
                        ? AppColors.error
                        : (isAdvance ? AppColors.primary : AppColors.success),
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
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.mobile,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
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
                        fontSize: 17,
                        color: hasDues
                            ? AppColors.error
                            : (isAdvance ? AppColors.primary : AppColors.success),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.error),
                        const SizedBox(width: 3),
                        Text(
                          context.tr('khata_tab_overdue'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (c.promiseDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 11, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Promise: ${DateFormat('dd MMM').format(c.promiseDate!)}',
                          style: const TextStyle(
                            fontSize: 10,
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

          // Bottom Action Row (WhatsApp Reminder, +Udhar, +Jama)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              if (hasDues)
                InkWell(
                  onTap: () => khata.sendWhatsAppReminder(context, c),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF25D366).withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF25D366)),
                        SizedBox(width: 4),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1EBE5D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick + Udhar
                  InkWell(
                    onTap: () => _showAddTransactionModal(context, customer: c, isCredit: true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_outward_rounded, size: 11, color: AppColors.error),
                          const SizedBox(width: 3),
                          Text(
                            context.tr('khata_give_credit_short'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quick + Jama
                  InkWell(
                    onTap: () => _showAddTransactionModal(context, customer: c, isCredit: false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 11, color: AppColors.success),
                          const SizedBox(width: 3),
                          Text(
                            context.tr('khata_receive_payment_short'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
