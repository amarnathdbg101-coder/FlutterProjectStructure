import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/cash_drawer_controller.dart';
import 'cash_drawer_modals.dart';

class CashDrawerStatusBar extends StatefulWidget {
  const CashDrawerStatusBar({super.key});

  @override
  State<CashDrawerStatusBar> createState() => _CashDrawerStatusBarState();
}

class _CashDrawerStatusBarState extends State<CashDrawerStatusBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashDrawerController>().fetchCurrentStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawerCtrl = context.watch<CashDrawerController>();
    final isOpen = drawerCtrl.isDrawerOpen;
    final currentCash = drawerCtrl.currentDrawerCash;
    final requiresSafeDrop = drawerCtrl.requiresSafeDrop;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
        border: Border(
          bottom: BorderSide(
            color: isOpen ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shift Indicator
            InkWell(
              onTap: () {
                if (isOpen) {
                  CashDrawerModals.showShiftCloseDialog(context);
                } else {
                  CashDrawerModals.showShiftOpenDialog(context);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 14,
                      color: isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOpen ? 'SHIFT OPEN' : 'SHIFT CLOSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Cash in Drawer / Prompt
            if (isOpen) ...[
              Text(
                'Drawer: ₹${currentCash.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ] else ...[
              const Text(
                '• Tap to open shift',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
              ),
            ],

            const SizedBox(width: 12),

            // Safe Drop Alert Pill
            if (isOpen && requiresSafeDrop) ...[
              InkWell(
                onTap: () => CashDrawerModals.showSafeDropDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 14, color: Color(0xFFB45309)),
                      SizedBox(width: 4),
                      Text(
                        'Safe Drop (> ₹10k)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Quick Drawer Actions
            if (isOpen) ...[
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Drawer Shift Actions',
                onSelected: (val) {
                if (val == 'safe_drop') {
                  CashDrawerModals.showSafeDropDialog(context);
                } else if (val == 'petty_cash') {
                  CashDrawerModals.showPettyExpenseDialog(context);
                } else if (val == 'close_shift') {
                  CashDrawerModals.showShiftCloseDialog(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'safe_drop',
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 18, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text('Perform Safe Drop'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'petty_cash',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Log Petty Expense'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'close_shift',
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Text('Close Shift Reconciliation'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
}
