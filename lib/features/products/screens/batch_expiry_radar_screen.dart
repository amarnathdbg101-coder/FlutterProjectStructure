import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../controllers/batch_expiry_controller.dart';

class BatchExpiryRadarScreen extends StatefulWidget {
  const BatchExpiryRadarScreen({super.key});

  @override
  State<BatchExpiryRadarScreen> createState() => _BatchExpiryRadarScreenState();
}

class _BatchExpiryRadarScreenState extends State<BatchExpiryRadarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchExpiryController>().loadNearExpiry();
    });
  }

  void _showAddBatchDialog() {
    final prodCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    DateTime selectedExpiry = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('Register Product Batch Lot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Track expiry dates and automatic price markdowns for fresh lots:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: prodCtrl,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g. Amul Butter 500g',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: batchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Batch / Lot Number',
                    hintText: 'e.g. LOT-2026-MAY',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: mrpCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'MRP (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Purchase Cost (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogCtx,
                      initialDate: selectedExpiry,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) {
                      setState(() => selectedExpiry = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expiry Date:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        Text(
                          DateFormat('dd MMM yyyy').format(selectedExpiry),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 10.0;
                final mrp = double.tryParse(mrpCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                final ok = await context.read<BatchExpiryController>().createBatch(
                      productId: 'PROD-LOT-${DateTime.now().millisecondsSinceEpoch}',
                      productName: prodCtrl.text.trim(),
                      batchNumber: batchCtrl.text.trim(),
                      expiryDate: selectedExpiry,
                      initialQuantity: qty,
                      purchaseCost: cost,
                      mrp: mrp,
                    );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Batch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchCtrl = context.watch<BatchExpiryController>();
    final batches = batchCtrl.batches;
    final selectedWindow = batchCtrl.selectedDaysWindow;
    final isScanning = batchCtrl.isScanningMarkdown;
    final isHindi = context.isHindi;

    return Scaffold(
      backgroundColor: context.colorSurfaceSubtle,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/merchant/inventory'),
        title: Text(
          isHindi ? 'एक्सपायरी रडार' : 'Batch Expiry Radar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: context.colorTextPrimary),
        ),
        backgroundColor: context.colorSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: isHindi ? 'ताज़ा करें' : 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: context.colorTextPrimary, size: 22),
            onPressed: () => batchCtrl.loadNearExpiry(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          isHindi ? '+ नया लॉट जोड़ें' : '+ Add Batch',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        onPressed: _showAddBatchDialog,
      ),
      body: Column(
        children: [
          // Header Action Banner: Run Markdown Scan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.colorSurface,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'क्लियरेंस ऑटो-छूट (Auto-Markdown)' : 'Clearance Auto-Markdown',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: context.colorTextPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHindi
                            ? 'एक्सपायर होने से पहले सामान पर छूट लगाकर नुकसान से बचें।'
                            : 'Auto-discount lots nearing expiry to liquidate stock before expiry loss.',
                        style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                  onPressed: isScanning ? null : () => batchCtrl.runMarkdownScan(),
                  icon: isScanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.discount_rounded, size: 16),
                  label: Text(
                    isHindi ? 'छूट लगाएं' : 'Run Markdown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colorBorder),

          // Days Window Filter Bar
          Container(
            height: 48,
            color: context.colorSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  isHindi ? 'अवधि:' : 'Horizon:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colorTextMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [15, 30, 60, 90].map((days) {
                        final isSelected = selectedWindow == days;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              isHindi ? '$days दिन' : '$days Days',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.primary : context.colorTextSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: context.colorPrimaryLight,
                            backgroundColor: context.colorSurfaceSubtle,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : context.colorBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                            onSelected: (_) => batchCtrl.setDaysWindow(days),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colorBorder),

          // Batch Lots List
          Expanded(
            child: batchCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : batches.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: AppColors.successLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                isHindi
                                  ? '🎉 अगले $selectedWindow दिनों में कोई एक्सपायरी नहीं!'
                                  : 'Zero batches expiring within the next $selectedWindow days!',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isHindi
                                  ? 'आपकी दुकान का सारा स्टॉक ताज़ा और सुरक्षित है।'
                                  : 'Your store inventory is fresh and safe from expiry losses.',
                                style: TextStyle(fontSize: 12.5, color: context.colorTextMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: batches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final batch = batches[idx];
                          final expiryStr = DateFormat('dd MMM yyyy').format(batch.expiryDate);

                          Color urgencyColor;
                          String urgencyLabel;

                          if (batch.daysToExpiry <= 7) {
                            urgencyColor = const Color(0xFFDC2626);
                            urgencyLabel = isHindi ? '🔴 गंभीर (${batch.daysToExpiry} दिन बाकी)' : 'CRITICAL (${batch.daysToExpiry}d left)';
                          } else if (batch.daysToExpiry <= 30) {
                            urgencyColor = const Color(0xFFD97706);
                            urgencyLabel = isHindi ? '🟠 चेतावनी (${batch.daysToExpiry} दिन बाकी)' : 'WARNING (${batch.daysToExpiry}d left)';
                          } else {
                            urgencyColor = const Color(0xFF2563EB);
                            urgencyLabel = isHindi ? '${batch.daysToExpiry} दिन बाकी' : '${batch.daysToExpiry} days left';
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.colorSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: urgencyColor.withValues(alpha: 0.35)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        batch.productName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.colorTextPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: urgencyColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        urgencyLabel,
                                        style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'लॉट #${batch.batchNumber} • Expiry: $expiryStr',
                                  style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${isHindi ? "दुकान में स्टॉक" : "Stock In Hand"}: ${batch.currentQuantity.toStringAsFixed(0)} units',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colorTextPrimary),
                                    ),
                                    Text(
                                      'MRP: ₹${batch.mrp.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                if (batch.markdownDiscount > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.trending_down_rounded, size: 14, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${isHindi ? "सक्रिय छूट" : "Active Markdown"}: ${batch.markdownDiscount.toStringAsFixed(0)}% OFF (Promo Price: ₹${(batch.mrp * (1 - batch.markdownDiscount / 100)).toStringAsFixed(0)})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
