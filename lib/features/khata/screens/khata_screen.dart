import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/khata_controller.dart';
import '../models/khata_model.dart';
import '../repositories/khata_repository.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
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
                    Container(
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
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  customer.mobile,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${customer.balance.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: customer.balance > 0 ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      ),
                      onChanged: (_) {
                        if (selectedCustomer != null) {
                          setModalState(() => selectedCustomer = null);
                        }
                      },
                    ),
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
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Notes / Reason
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('khata_field_notes'),
                      prefixIcon: const Icon(Icons.notes_rounded),
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
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('btn_cancel')),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentIsCredit ? AppColors.error : AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('khata_toast_saved')),
                                backgroundColor: AppColors.success,
                              ),
                            );
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
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.tr('btn_save')),
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
          final modalHeight = (screenHeight * 0.85).clamp(480.0, 720.0);

          return Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: modalHeight,
                constraints: const BoxConstraints(maxWidth: 580),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  bottom: keyboardHeight > 0 ? keyboardHeight + 12 : 20,
                  top: 16,
                  left: 20,
                  right: 20,
                ),
                child: buildFormContent(sheetCtx, setModalState),
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
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('btn_cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
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
                      child: Text(context.tr('btn_save')),
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
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('btn_cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
                      child: Text(context.tr('btn_confirm')),
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
  // SHEET: CUSTOMER PASSBOOK & STATEMENT
  // ==========================================
  void _showCustomerStatementSheet(BuildContext context, KhataCustomerModel customer) {
    context.read<KhataController>().loadStatement(customer.mobile);

    Widget buildSheet(BuildContext ctx) {
      return Consumer<KhataController>(
        builder: (context, khata, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isOverdue = customer.isOverdue;
          final utilization = customer.creditUtilizationPercent;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
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
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            customer.mobile,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Pending Dues Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (customer.balance > 0 ? AppColors.error : AppColors.success)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (customer.balance > 0 ? AppColors.error : AppColors.success)
                          .withValues(alpha: 0.3),
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          if (isOverdue) ...[
                            const SizedBox(height: 4),
                            AppBadge(
                              label: context.tr('khata_tab_overdue'),
                              type: AppBadgeType.error,
                            ),
                          ],
                        ],
                      ),
                      FittedBox(
                        child: Text(
                          '₹${customer.balance.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: customer.balance > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Credit Limit & Promise Date Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showSetCreditLimitDialog(context, customer),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
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
                              const SizedBox(height: 2),
                              Text(
                                '₹${customer.creditLimit.toStringAsFixed(0)} (${utilization.toStringAsFixed(0)}%)',
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
                        onTap: () => _showSetPromiseDateDialog(context, customer),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
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
                              const SizedBox(height: 2),
                              Text(
                                customer.promiseDate != null
                                    ? DateFormat('dd MMM yyyy').format(customer.promiseDate!)
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
                const SizedBox(height: 14),

                // Quick Action Buttons Row (WhatsApp, PDF, +Udhar, +Jama)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: Text(context.tr('khata_btn_whatsapp_reminder')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () => khata.sendWhatsAppReminder(context, customer),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: Text(context.tr('khata_btn_download_pdf')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      ),
                      onPressed: () => khata.openStatementPdf(context, customer.mobile, customer: customer),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                        label: Text(context.tr('khata_dialog_give_credit')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Future.delayed(const Duration(milliseconds: 150));
                          if (context.mounted) {
                            _showAddTransactionModal(context, customer: customer, isCredit: true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                        label: Text(context.tr('khata_dialog_receive_payment')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Future.delayed(const Duration(milliseconds: 150));
                          if (context.mounted) {
                            _showAddTransactionModal(context, customer: customer, isCredit: false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transactions History Header
                AppSectionHeader(
                  title: context.tr('khata_history_title'),
                  padding: const EdgeInsets.only(bottom: 8),
                ),

                // Transactions List
                SizedBox(
                  height: 250,
                  child: khata.isStatementLoading
                      ? const Center(child: CircularProgressIndicator())
                      : khata.currentCustomerStatement.isEmpty
                          ? Center(
                              child: Text(
                                context.tr('khata_history_empty'),
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: khata.currentCustomerStatement.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final tx = khata.currentCustomerStatement[idx];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: (tx.isCredit ? AppColors.error : AppColors.success)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      tx.isCredit
                                          ? Icons.arrow_outward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: tx.isCredit ? AppColors.error : AppColors.success,
                                      size: 18,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tx.isCredit
                                              ? context.tr('khata_dialog_give_credit')
                                              : context.tr('khata_dialog_receive_payment'),
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        '${tx.isCredit ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: tx.isCredit ? AppColors.error : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                            ),
                                          ),
                                          if (tx.billNumber != null && tx.billNumber!.isNotEmpty)
                                            Text(
                                              'Bill: ${tx.billNumber}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (tx.notes.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tx.notes,
                                          style: const TextStyle(fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.undo_rounded, size: 16),
                                    tooltip: context.tr('khata_btn_reverse'),
                                    onPressed: () => _showReverseDialog(
                                      context,
                                      tx,
                                      customer.id.toString(),
                                      customer.mobile,
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                    maxWidth: 580,
                  ),
                  child: SingleChildScrollView(
                    child: buildSheet(ctx),
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
  // MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final khata = context.watch<KhataController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MerchantShell(
      currentIndex: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('khata_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.campaign_rounded, color: Color(0xFF25D366)),
              tooltip: 'Broadcast WhatsApp Reminders to Overdue Debtors',
              onPressed: () => khata.broadcastWhatsAppOverdueReminders(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => khata.loadCustomers(),
            ),
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
        body: ResponsiveContainer(
          maxWidth: 1200,
          child: Column(
            children: [
              // Executive Summary Banner
              AppSummaryBanner(
                title: context.tr('khata_banner_title'),
                amount: '₹${khata.totalMarketDebt.toStringAsFixed(0)}',
                subtitle:
                    '${khata.debtorsCount} ${context.tr('khata_kpi_debtors')} • ${khata.overdueCount} ${context.tr('khata_kpi_overdue')}',
                icon: Icons.menu_book_rounded,
                actionLabel: context.tr('khata_add_btn'),
                onAction: () => _showAddTransactionModal(context, isCredit: true),
              ),

              // Aging Analysis Stat Cards Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppStatCard(
                        title: context.tr('khata_aging_0_30'),
                        value: '₹${khata.aging?.currentDays0To30.toStringAsFixed(0) ?? '0'}',
                        subtitle: 'Current dues',
                        icon: Icons.timelapse_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: context.tr('khata_aging_31_60'),
                        value: '₹${khata.aging?.days31To60.toStringAsFixed(0) ?? '0'}',
                        subtitle: 'Follow up',
                        icon: Icons.alarm_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: context.tr('khata_aging_60_plus'),
                        value: '₹${khata.aging?.days61Plus.toStringAsFixed(0) ?? '0'}',
                        subtitle: 'Urgent collection',
                        icon: Icons.warning_amber_rounded,
                        isAlert: (khata.aging?.days61Plus ?? 0) > 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.tr('khata_search_hint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              khata.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) => khata.setSearchQuery(query),
                ),
              ),
              const SizedBox(height: 8),

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
                    ? const Center(child: CircularProgressIndicator())
                    : khata.filteredCustomers.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('khata_empty_title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
        children: [
          // Top Row: Avatar, Name, Mobile & Balance
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: hasDues
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: hasDues ? AppColors.error : AppColors.primary,
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
            Row(
              children: [
                if (c.isOverdue)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
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

          const Spacer(),

          // Bottom Action Row (WhatsApp Reminder, +Udhar, +Jama)
          Row(
            children: [
              // 1-Tap WhatsApp Reminder
              if (hasDues) ...[
                InkWell(
                  onTap: () => khata.sendWhatsAppReminder(context, c),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF25D366)),
                        SizedBox(width: 4),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1EBE5D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              const Spacer(),

              // Quick + Udhar
              InkWell(
                onTap: () => _showAddTransactionModal(context, customer: c, isCredit: true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_outward_rounded, size: 13, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('khata_dialog_give_credit'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('khata_dialog_receive_payment'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
