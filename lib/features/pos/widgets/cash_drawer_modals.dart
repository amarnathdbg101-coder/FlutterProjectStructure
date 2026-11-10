import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/cash_drawer_controller.dart';

class CashDrawerModals {
  static void showShiftOpenDialog(BuildContext context) {
    final cashCtrl = TextEditingController(text: '2000');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Open Cash Drawer Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the physical opening cash (drawer float) counted at shift start:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Opening Cash Float (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Shift Notes (Optional)',
                hintText: 'e.g. Morning shift counter 1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final amount = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
              final ok = await context.read<CashDrawerController>().openSession(
                    openingCash: amount,
                    notes: notesCtrl.text.trim(),
                  );
              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Confirm & Open Shift'),
          ),
        ],
      ),
    );
  }

  static void showShiftCloseDialog(BuildContext context) {
    final drawerCtrl = context.read<CashDrawerController>();
    final session = drawerCtrl.currentSession;
    final expectedCash = session?.expectedCash ?? session?.currentCashInDrawer ?? 0.0;
    final cashCtrl = TextEditingController(text: expectedCash.toStringAsFixed(0));
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          final counted = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
          final discrepancy = counted - expectedCash;

          Color diffColor = const Color(0xFF16A34A);
          if (discrepancy < -1.0) {
            diffColor = const Color(0xFFDC2626); // Shortage
          } else if (discrepancy > 1.0) {
            diffColor = const Color(0xFF2563EB); // Excess
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 10),
                Text('Close Shift Reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Expected Cash in Drawer:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                              '₹${expectedCash.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Safe Drops Made:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('₹${session?.safeDropTotal.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Petty Cash Expenses:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('₹${session?.pettyCashExpenses.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Counted Cash in Hand (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(discrepancy == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 16, color: diffColor),
                        const SizedBox(width: 6),
                        Text(
                          discrepancy == 0
                              ? 'Zero Discrepancy (Perfect match)'
                              : discrepancy < 0
                                  ? 'Cash Shortage: -₹${discrepancy.abs().toStringAsFixed(2)}'
                                  : 'Cash Excess: +₹${discrepancy.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: diffColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Closing Comments',
                      hintText: 'e.g. Shift ended on time',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final amount = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
                  final ok = await drawerCtrl.closeSession(
                    closingCash: amount,
                    notes: notesCtrl.text.trim(),
                  );
                  if (ok && ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Lock & Close Shift'),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showSafeDropDialog(BuildContext context) {
    final drawerCtrl = context.read<CashDrawerController>();
    final cashInDrawer = drawerCtrl.currentDrawerCash;
    final suggestedDrop = (cashInDrawer - 2000.0).clamp(0.0, cashInDrawer);
    final amountCtrl = TextEditingController(text: suggestedDrop > 0 ? suggestedDrop.toStringAsFixed(0) : '5000');
    final envelopeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 10),
            Text('Perform Safe Drop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Cash in Drawer: ₹${cashInDrawer.toStringAsFixed(2)}\nMove excess cash to back-office safe locker for store security.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Safe Drop Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: envelopeCtrl,
              decoration: InputDecoration(
                labelText: 'Envelope / Vault Code (Optional)',
                hintText: 'e.g. ENV-904',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'e.g. Safe drop before evening rush',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final ok = await drawerCtrl.recordSafeDrop(
                amount: amount,
                notes: notesCtrl.text.trim(),
                envelopeNumber: envelopeCtrl.text.trim(),
              );
              if (ok && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Record Safe Drop'),
          ),
        ],
      ),
    );
  }

  static void showPettyExpenseDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = 'TEA_SNACKS';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text('Petty Cash Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record petty expenses paid directly from the counter cash drawer:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Expense Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'TEA_SNACKS', child: Text('Staff Tea & Snacks')),
                  DropdownMenuItem(value: 'CLEANING', child: Text('Cleaning & Maintenance')),
                  DropdownMenuItem(value: 'DELIVERY_PETROL', child: Text('Delivery Petrol / Travel')),
                  DropdownMenuItem(value: 'PACKAGING_TAPE', child: Text('Packaging Tape / Bags')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other Petty Expense')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. Paid cash to tea vendor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final ok = await context.read<CashDrawerController>().recordPettyExpense(
                      amount: amount,
                      category: selectedCategory,
                      notes: notesCtrl.text.trim(),
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
