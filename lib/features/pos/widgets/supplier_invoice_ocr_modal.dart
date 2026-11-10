import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../controllers/ai_features_controller.dart';
import '../repositories/pos_advanced_repository.dart';

class SupplierInvoiceOcrModal {
  static void show(BuildContext context) {
    final hintCtrl = TextEditingController();
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          final aiCtrl = ctx.watch<AIFeaturesController>();
          final invoice = aiCtrl.lastInvoice;
          final isParsing = aiCtrl.isParsingInvoice;

          Future<void> pickImage(ImageSource source) async {
            try {
              final picked = await picker.pickImage(
                source: source,
                maxWidth: 1280,
                maxHeight: 1280,
                imageQuality: 80,
                requestFullMetadata: false,
              );
              if (picked != null) {
                final (_, bytes) = await normalizeXFile(picked, maxDimension: 1600);


                await aiCtrl.parseSupplierInvoice(
                  imageBytes: bytes,
                  distributorHint: hintCtrl.text.trim(),
                );
              }
            } catch (e) {
              if (dialogCtx.mounted) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Failed to load image: $e')),
                );
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text('Supplier Invoice OCR Ingestion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      'Capture or upload a supplier wholesale parchi/invoice photo. AI will automatically extract items, batches, costs, and GST:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: hintCtrl,
                      decoration: InputDecoration(
                        labelText: 'Distributor / Agency Name (Optional Hint)',
                        hintText: 'e.g. HUL Super Distributor',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isParsing ? null : () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isParsing ? null : () => pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),

                    if (isParsing) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text(
                              'AI Vision Engine analyzing invoice text & line items...',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (invoice != null && !isParsing) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invoice.distributorName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Invoice #${invoice.invoiceNumber} • ${invoice.invoiceDate}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${invoice.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            const Text(
                              'Extracted Items for Inward Stock:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: invoice.items.length,
                                separatorBuilder: (_, _) => const Divider(height: 8),
                                itemBuilder: (itemCtx, idx) {
                                  final item = invoice.items[idx];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Qty: ${item.quantity} • Cost: ₹${item.unitCost.toStringAsFixed(1)} • MRP: ₹${item.suggestedMRP.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
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
                  aiCtrl.clearInvoice();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Close'),
              ),
              if (invoice != null && !isParsing) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    // Inward batches into inventory
                    final repo = PosAdvancedRepository();
                    int count = 0;
                    for (final item in invoice.items) {
                      await repo.createProductBatch({
                        'product_id': 'PROD-OCR-${DateTime.now().millisecondsSinceEpoch}-$count',
                        'product_name': item.productName,
                        'batch_number': item.batchNumber.isNotEmpty ? item.batchNumber : 'LOT-${DateTime.now().millisecondsSinceEpoch}',
                        'expiry_date': item.expiryDate.isNotEmpty
                            ? item.expiryDate
                            : DateTime.now().add(const Duration(days: 180)).toIso8601String(),
                        'initial_quantity': item.quantity.toDouble(),
                        'purchase_cost': item.unitCost,
                        'mrp': item.suggestedMRP,
                      });
                      count++;
                    }
                    aiCtrl.clearInvoice();
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Inwarded $count batch lots from invoice into store inventory!'),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_task_rounded, size: 16),
                  label: const Text('Inward to Inventory'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

