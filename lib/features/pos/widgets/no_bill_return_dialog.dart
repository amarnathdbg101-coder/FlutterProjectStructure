import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/pos_controller.dart';

class NoBillReturnDialog {
  static void show(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<PosController>(
        builder: (ctx, claimCtrl, _) {
          final results = claimCtrl.lookupResults;
          final isSearching = claimCtrl.isLookingUpReturns;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text('No-Bill Return Lookup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer has lost physical bill? Enter mobile number or scan product barcode to find the exact purchase date & price paid within the last 30 days:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Customer Mobile (Optional)',
                        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: barcodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Product Barcode / SKU (Optional)',
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isSearching
                            ? null
                            : () => claimCtrl.lookupReturns(
                                  phone: phoneCtrl.text.trim(),
                                  barcode: barcodeCtrl.text.trim(),
                                ),
                        icon: isSearching
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Search Historical Sales'),
                      ),
                    ),

                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Verified Past Purchases:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = results[idx];
                            final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.saleDate);

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Bill #${item.billNumber} • $dateStr',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        Text(
                                          'Paid: ₹${item.netPrice.toStringAsFixed(2)} (Qty: ${item.quantitySold.toStringAsFixed(0)})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      // Trigger POS return for this item
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Selected "${item.productName}" for return against Bill #${item.billNumber}'),
                                          backgroundColor: const Color(0xFF0F172A),
                                        ),
                                      );
                                    },
                                    child: const Text('Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  claimCtrl.clearLookup();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
