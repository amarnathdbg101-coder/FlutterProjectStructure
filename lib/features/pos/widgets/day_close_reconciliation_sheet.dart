import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../auth/controllers/auth_controller.dart';
import '../repositories/pos_repository.dart';

/// Interactive Day Close & Cash Reconciliation Bottom Sheet (गल्ला मिलान & Z-Report)
class DayCloseReconciliationSheet extends StatefulWidget {
  final DateTime? initialDate;

  const DayCloseReconciliationSheet({super.key, this.initialDate});

  static Future<void> show(BuildContext context, {DateTime? date}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DayCloseReconciliationSheet(initialDate: date),
    );
  }

  @override
  State<DayCloseReconciliationSheet> createState() => _DayCloseReconciliationSheetState();
}

class _DayCloseReconciliationSheetState extends State<DayCloseReconciliationSheet> {
  final PosRepository _repo = PosRepository();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _report;
  late DateTime _selectedDate;

  // Physical Denomination Notes Counter
  bool _showCashCounter = false;
  final Map<int, int> _noteCounts = {
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _repo.getDayCloseReport();
      if (!mounted) return;

      if (res.success && res.data != null) {
        setState(() {
          _report = res.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.error ?? 'Could not fetch day close report';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _physicalCountedTotal {
    double sum = 0.0;
    _noteCounts.forEach((denom, count) {
      sum += (denom * count);
    });
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);

    final cashSales = (_report?['cash_sales'] as num?)?.toDouble() ?? 0.0;
    final upiSales = (_report?['upi_sales'] as num?)?.toDouble() ?? 0.0;
    final creditGiven = (_report?['credit_given'] as num?)?.toDouble() ?? 0.0;
    final totalGross = (_report?['total_gross_sales'] as num?)?.toDouble() ?? 0.0;
    final billsCount = (_report?['total_bills_count'] as num?)?.toInt() ?? 0;
    final khataCash = (_report?['khata_cash_collected'] as num?)?.toDouble() ?? 0.0;
    final khataUpi = (_report?['khata_upi_collected'] as num?)?.toDouble() ?? 0.0;
    final cashExpenses = (_report?['cash_expenses_paid'] as num?)?.toDouble() ?? 0.0;
    final expectedCash = (_report?['expected_cash_in_drawer'] as num?)?.toDouble() ?? (cashSales + khataCash - cashExpenses);

    final physicalTotal = _physicalCountedTotal;
    final cashDiff = physicalTotal > 0 ? (physicalTotal - expectedCash) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 14,
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: 620,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'दुकान बंद / गल्ला मिलान' : 'Day Close & Cash Reconciliation',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isHindi ? 'रीफ्रेश' : 'Refresh',
                onPressed: _isLoading ? null : _loadReport,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadReport, child: Text(isHindi ? 'पुनः प्रयास करें' : 'Retry')),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. HERO DRAWER EXPECTED CASH CARD
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.colorSurfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.savings_rounded, color: AppColors.primary, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        isHindi ? 'गल्ले में अपेक्षित नकद (Expected Cash)' : 'Expected Cash in Cash Drawer',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.colorTextSecondary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${expectedCash.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isHindi ? 'नकद बिक्री + जमा उधार - नकद खर्चे' : 'Cash Sales + Khata Cash - Cash Expenses',
                                    style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. 4-GRID EXECUTIVE METRICS
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    title: isHindi ? 'कुल बिक्री (टर्नओवर)' : 'Total Gross Sales',
                                    value: '₹${totalGross.toStringAsFixed(0)}',
                                    subtitle: '$billsCount ${isHindi ? 'बिल बने' : 'bills'}',
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricTile(
                                    title: isHindi ? 'UPI / ऑनलाइन बिक्री' : 'UPI / Online Sales',
                                    value: '₹${upiSales.toStringAsFixed(0)}',
                                    subtitle: isHindi ? 'डिजिटल पेमेंट' : 'Digital Collections',
                                    color: const Color(0xFF00897B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    title: isHindi ? 'आज दिया गया उधार' : 'Credit / Udhar Given',
                                    value: '₹${creditGiven.toStringAsFixed(0)}',
                                    subtitle: isHindi ? 'खाता लेजर में जुड़ा' : 'Added to Khata',
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricTile(
                                    title: isHindi ? 'उधार वसूली (नकद+UPI)' : 'Khata Collected',
                                    value: '₹${(khataCash + khataUpi).toStringAsFixed(0)}',
                                    subtitle: '₹${khataCash.toStringAsFixed(0)} Cash + ₹${khataUpi.toStringAsFixed(0)} UPI',
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 3. STEP-BY-STEP CASH FLOW BREAKDOWN
                            Text(
                              isHindi ? 'गल्ला नकद हिसाब-किताब' : 'Cash Inflow & Outflow Breakdown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.colorSurfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Column(
                                children: [
                                  _buildFlowRow(
                                    label: isHindi ? '+ काउंटर नकद बिक्री' : '+ Counter Cash Sales',
                                    amount: cashSales,
                                    isPositive: true,
                                  ),
                                  const Divider(height: 14),
                                  _buildFlowRow(
                                    label: isHindi ? '+ पुराना उधार नकद मिला' : '+ Khata Debt Paid in Cash',
                                    amount: khataCash,
                                    isPositive: true,
                                  ),
                                  const Divider(height: 14),
                                  _buildFlowRow(
                                    label: isHindi ? '- गल्ले से किया गया खर्च' : '- Cash Store Expenses Paid',
                                    amount: cashExpenses,
                                    isPositive: false,
                                  ),
                                  const Divider(height: 16, thickness: 1.2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isHindi ? '= अपेक्षित कुल गल्ला नकद' : '= Total Expected Cash',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        '₹${expectedCash.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. PHYSICAL NOTE DENOMINATION COUNTER (TOGGLE)
                            InkWell(
                              onTap: () => setState(() => _showCashCounter = !_showCashCounter),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: context.colorSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colorBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        isHindi ? 'भौतिक नोट गिनें (नोटों की संख्या डालें)' : 'Count Physical Notes in Drawer',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    Icon(
                                      _showCashCounter ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: context.colorTextSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_showCashCounter) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.colorSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colorBorder),
                                ),
                                child: Column(
                                  children: [
                                    ...[500, 200, 100, 50, 20, 10].map((denom) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 60,
                                              child: Text('₹$denom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                            const Text('×', style: TextStyle(color: Colors.grey)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  _buildStepBtn(Icons.remove, () {
                                                    if (_noteCounts[denom]! > 0) {
                                                      setState(() => _noteCounts[denom] = _noteCounts[denom]! - 1);
                                                    }
                                                  }),
                                                  Container(
                                                    width: 44,
                                                    alignment: Alignment.center,
                                                    child: Text('${_noteCounts[denom]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  ),
                                                  _buildStepBtn(Icons.add, () {
                                                    setState(() => _noteCounts[denom] = _noteCounts[denom]! + 1);
                                                  }),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '₹${(denom * _noteCounts[denom]!).toStringAsFixed(0)}',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(isHindi ? 'गिना गया कुल नकद:' : 'Counted Physical Cash:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('₹${physicalTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                    if (physicalTotal > 0) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (cashDiff == 0)
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : (cashDiff < 0)
                                                  ? AppColors.error.withValues(alpha: 0.15)
                                                  : AppColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              cashDiff == 0
                                                  ? Icons.check_circle_rounded
                                                  : (cashDiff < 0 ? Icons.error_outline_rounded : Icons.info_outline_rounded),
                                              size: 16,
                                              color: cashDiff == 0
                                                  ? AppColors.success
                                                  : (cashDiff < 0 ? AppColors.error : AppColors.warning),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                cashDiff == 0
                                                    ? (isHindi ? '✓ गल्ला बिल्कुल सही है! (₹0 फर्क)' : '✓ Drawer Matches Perfectly (₹0 Variance)')
                                                    : (cashDiff < 0
                                                        ? (isHindi ? '⚠️ ₹${(-cashDiff).toStringAsFixed(0)} गल्ले में कम है (Shortage)' : '⚠️ ₹${(-cashDiff).toStringAsFixed(0)} Cash Shortage in Drawer')
                                                        : (isHindi ? 'ℹ️ ₹${cashDiff.toStringAsFixed(0)} गल्ले में अतिरिक्त है (Surplus)' : 'ℹ️ ₹${cashDiff.toStringAsFixed(0)} Cash Surplus in Drawer')),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: cashDiff == 0
                                                      ? AppColors.success
                                                      : (cashDiff < 0 ? AppColors.error : AppColors.warning),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // 5. ACTION BUTTONS: WHATSAPP STATEMENT & PRINT Z-REPORT
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              label: Text(
                                isHindi ? 'व्हाट्सएप पर डेली क्लोजिंग स्टेटमेंट भेजें' : 'Share Daily Closing Summary on WhatsApp',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _shareOnWhatsApp(
                                isHindi: isHindi,
                                dateStr: dateStr,
                                cashSales: cashSales,
                                upiSales: upiSales,
                                creditGiven: creditGiven,
                                totalGross: totalGross,
                                billsCount: billsCount,
                                khataCash: khataCash,
                                cashExpenses: cashExpenses,
                                expectedCash: expectedCash,
                              ),
                            ),
                            const SizedBox(height: 8),

                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 42),
                              ),
                              icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.primary),
                              label: Text(
                                isHindi ? 'डेली Z-Report प्रिंट करें (58mm/80mm)' : 'Print Daily Z-Report Slip',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _printZReportPdf(
                                isHindi: isHindi,
                                dateStr: dateStr,
                                cashSales: cashSales,
                                upiSales: upiSales,
                                creditGiven: creditGiven,
                                totalGross: totalGross,
                                billsCount: billsCount,
                                khataCash: khataCash,
                                cashExpenses: cashExpenses,
                                expectedCash: expectedCash,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.colorBorder),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: context.colorTextSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: context.colorTextMuted)),
        ],
      ),
    );
  }

  Widget _buildFlowRow({
    required String label,
    required double amount,
    required bool isPositive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5)),
        Text(
          '${isPositive ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: isPositive ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }

  Future<void> _shareOnWhatsApp({
    required bool isHindi,
    required String dateStr,
    required double cashSales,
    required double upiSales,
    required double creditGiven,
    required double totalGross,
    required int billsCount,
    required double khataCash,
    required double cashExpenses,
    required double expectedCash,
  }) async {
    final shop = context.read<AuthController>().currentShop;
    final shopName = shop?.name ?? 'ShopSilo Store';

    final text = isHindi
        ? '''
🏪 *दुकान दैनिक क्लोजिंग रिपोर्ट (Daily Close)*
🏬 *दुकान:* $shopName
📅 *दिनांक:* $dateStr
━━━━━━━━━━━━━━━━━━━━
📊 *दैनिक कारोबार (Sales Turnover):*
• कुल बिक्री: *₹${totalGross.toStringAsFixed(0)}* ($billsCount बिल)
• नकद बिक्री (Cash Sales): ₹${cashSales.toStringAsFixed(0)}
• UPI / डिजिटल: ₹${upiSales.toStringAsFixed(0)}
• आज दिया गया उधार (Credit): ₹${creditGiven.toStringAsFixed(0)}

💵 *गल्ला नकद मिलान (Drawer Cash):*
+ नकद बिक्री: ₹${cashSales.toStringAsFixed(0)}
+ पुराना उधार नकद मिला: ₹${khataCash.toStringAsFixed(0)}
- नकद खर्चे: ₹${cashExpenses.toStringAsFixed(0)}
────────────────────
💰 *गल्ले में कुल नकद (Expected Cash): ₹${expectedCash.toStringAsFixed(0)}*
━━━━━━━━━━━━━━━━━━━━
_सॉफ्टवेयर: ShopSilo | shopsilo.in_
'''
        : '''
🏪 *DAILY STORE CLOSING STATEMENT*
🏬 *Store:* $shopName
📅 *Date:* $dateStr
━━━━━━━━━━━━━━━━━━━━
📊 *Turnover & Sales Summary:*
• Gross Sales: *₹${totalGross.toStringAsFixed(0)}* ($billsCount bills)
• Cash Sales: ₹${cashSales.toStringAsFixed(0)}
• UPI / Online: ₹${upiSales.toStringAsFixed(0)}
• Credit (Udhar) Given: ₹${creditGiven.toStringAsFixed(0)}

💵 *Cash Drawer Reconciliation:*
+ Cash Sales: ₹${cashSales.toStringAsFixed(0)}
+ Khata Cash Recovered: ₹${khataCash.toStringAsFixed(0)}
- Cash Expenses: ₹${cashExpenses.toStringAsFixed(0)}
────────────────────
💰 *Expected Cash in Drawer: ₹${expectedCash.toStringAsFixed(0)}*
━━━━━━━━━━━━━━━━━━━━
_Generated via ShopSilo | shopsilo.in_
''';

    final encoded = Uri.encodeComponent(text.trim());
    final url = Uri.parse('https://wa.me/?text=$encoded');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: text.trim()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'स्टेटमेंट कॉपी हो गया' : 'Statement copied to clipboard'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _printZReportPdf({
    required bool isHindi,
    required String dateStr,
    required double cashSales,
    required double upiSales,
    required double creditGiven,
    required double totalGross,
    required int billsCount,
    required double khataCash,
    required double cashExpenses,
    required double expectedCash,
  }) async {
    final shop = context.read<AuthController>().currentShop;
    final shopName = shop?.name ?? 'ShopSilo Retail Store';

    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 13), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text('END-OF-DAY Z-REPORT / गल्ला क्लोजिंग', style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center),
              pw.Text('Date: $dateStr', style: pw.TextStyle(font: fontRegular, fontSize: 8), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),

              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Gross Sales:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                pw.Text('₹${totalGross.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Bills Count:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('$billsCount', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Cash Sales:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('₹${cashSales.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('UPI / Digital:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('₹${upiSales.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Credit (Udhar) Given:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('₹${creditGiven.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8),

              pw.Text('DRAWER CASH RECONCILIATION', style: pw.TextStyle(font: fontBold, fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('+ Cash Sales:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('₹${cashSales.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('+ Khata Cash Recovered:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('₹${khataCash.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('- Cash Expenses Paid:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                pw.Text('-₹${cashExpenses.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              ]),
              pw.SizedBox(height: 3),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                decoration: const pw.BoxDecoration(
                  border: pw.Border.symmetric(horizontal: pw.BorderSide(width: 1)),
                ),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('EXPECTED CASH:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text('₹${expectedCash.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Generated via ShopSilo | shopsilo.in', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Z_Report_$dateStr',
    );
  }
}
