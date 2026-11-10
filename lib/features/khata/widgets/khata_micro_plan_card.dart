import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/micro_plan_controller.dart';
import '../../pos/models/pos_features_model.dart';

class KhataMicroPlanCard extends StatefulWidget {
  final String customerPhone;
  final String customerName;
  final double currentBalance;

  const KhataMicroPlanCard({
    super.key,
    required this.customerPhone,
    required this.customerName,
    required this.currentBalance,
  });

  @override
  State<KhataMicroPlanCard> createState() => _KhataMicroPlanCardState();
}

class _KhataMicroPlanCardState extends State<KhataMicroPlanCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MicroPlanController>().getPlanForCustomer(widget.customerPhone);
    });
  }

  void _showStartPlanDialog() {
    final debtCtrl = TextEditingController(text: widget.currentBalance.toStringAsFixed(0));
    final dailyCtrl = TextEditingController(text: '100');
    final daysCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.savings_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('Start Daily Micro-Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Convert ${widget.customerName}\'s outstanding udhar into easy daily micro-installments (Chillar Settle):',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: debtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total Debt to Settle (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dailyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Daily Installment (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Target Days',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
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
                final debt = double.tryParse(debtCtrl.text.trim()) ?? widget.currentBalance;
                final daily = double.tryParse(dailyCtrl.text.trim()) ?? 100.0;
                final days = int.tryParse(daysCtrl.text.trim()) ?? 30;

                final ok = await context.read<MicroPlanController>().createPlan(
                      customerPhone: widget.customerPhone,
                      customerName: widget.customerName,
                      totalDebt: debt,
                      dailyAmount: daily,
                      targetDays: days,
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Start Plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(KhataMicroPlan plan) {
    final amountCtrl = TextEditingController(text: plan.dailyAmount.toStringAsFixed(0));
    String paymentMode = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 24),
              SizedBox(width: 8),
              Text('Log Daily Installment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collect daily micro-payment from ${widget.customerName}:',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Installment Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => paymentMode = val);
                },
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
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? plan.dailyAmount;
                final ok = await context.read<MicroPlanController>().recordPayment(
                      planId: plan.id,
                      amount: amt,
                      paymentMethod: paymentMode,
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final microCtrl = context.watch<MicroPlanController>();
    final plan = microCtrl.activePlan;

    if (plan == null) {
      if (widget.currentBalance <= 0) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.savings_rounded, color: Color(0xFF16A34A), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Chillar Settle Plan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                  ),
                  Text(
                    'Collect ₹50-₹100 daily to recover ₹${widget.currentBalance.toStringAsFixed(0)} fast without friction.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _showStartPlanDialog,
              child: const Text('Start Plan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final percent = plan.progressPercentage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_repeat_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  const Text(
                    'Daily Micro-Plan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  if (plan.currentStreak > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔥 ${plan.currentStreak}d Streak',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '₹${plan.dailyAmount.toStringAsFixed(0)} / day',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${plan.collectedAmount.toStringAsFixed(0)} of ₹${plan.totalDebt.toStringAsFixed(0)} paid (${(percent * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Text(
                '₹${plan.remainingAmount.toStringAsFixed(0)} left',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showRecordPaymentDialog(plan),
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: Text('Pay Today\'s ₹${plan.dailyAmount.toStringAsFixed(0)} Installment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
