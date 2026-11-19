import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/services/audio_haptic_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../controllers/khata_controller.dart';
import '../models/khata_model.dart';
import '../repositories/khata_repository.dart';

class KhataDialogs {
  static void showAddTransactionModal(
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
                        if (!currentIsCredit && ((selectedCustomer?.balance ?? customer?.balance ?? 0) > 0)) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                              label: Text(
                                context.isHindi
                                    ? 'पूरा चुकता (₹${(selectedCustomer?.balance ?? customer?.balance ?? 0).toStringAsFixed(0)})'
                                    : 'Full Settle (₹${(selectedCustomer?.balance ?? customer?.balance ?? 0).toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                              backgroundColor: AppColors.success.withValues(alpha: 0.12),
                              side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: () {
                                setModalState(() {
                                  amountCtrl.text = (selectedCustomer?.balance ?? customer?.balance ?? 0).toStringAsFixed(0);
                                });
                              },
                            ),
                          ),
                        ],
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
                              AppAudioHapticFeedback.success();
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
  static Future<void> showSetPromiseDateDialog(BuildContext context, KhataCustomerModel customer) async {
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
  static void showSetCreditLimitDialog(BuildContext context, KhataCustomerModel customer) {
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
  static void showReverseDialog(
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
  static void showEditTransactionModal(
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
  static void showDeleteTransactionDialog(
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
  static void showDeleteCustomerDialog(
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

}
