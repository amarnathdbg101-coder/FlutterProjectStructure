import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/scan_and_go_controller.dart';
import '../controllers/pos_controller.dart';
import '../../products/models/product_model.dart';

class ScanAndGoModal {
  static void show(BuildContext context) {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<ScanAndGoController>(
        builder: (ctx, scanCtrl, _) {
          final session = scanCtrl.verifiedSession;
          final isConverting = scanCtrl.isConverting;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 26),
                SizedBox(width: 8),
                Text('Scan & Go Queue Buster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      'Enter customer\'s 6-digit mobile self-checkout code to verify basket and bypass the counter queue:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: session == null,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '• • • • • •',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onSubmitted: (code) {
                              if (code.length == 6) scanCtrl.verifyCode(code);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: scanCtrl.isLoading
                              ? null
                              : () => scanCtrl.verifyCode(codeCtrl.text.trim()),
                          child: scanCtrl.isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    if (session != null) ...[
                      const SizedBox(height: 16),
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
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Code: ${session.verificationCode}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${session.items.length} items',
                                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: session.items.length,
                                separatorBuilder: (_, _) => const Divider(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = session.items[idx];
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity.toStringAsFixed(0)}x ${item.productName}',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Basket Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '₹${session.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ],
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
                  scanCtrl.clearSession();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel'),
              ),
              if (session != null) ...[
                OutlinedButton(
                  onPressed: () {
                    // Load items into active POS cart
                    final posCtrl = context.read<PosController>();
                    for (final item in session.items) {
                      final prod = ProductModel(
                        id: item.productId,
                        name: item.productName,
                        price: item.unitPrice,
                        stock: item.quantity.toInt() > 0 ? item.quantity.toInt() : 1,
                        category: 'General Store',
                        barcode: item.barcode,
                      );
                      posCtrl.addToCart(prod, quantity: item.quantity.toInt());
                    }
                    scanCtrl.clearSession();
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Load into POS Cart'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isConverting
                      ? null
                      : () async {
                          final ok = await scanCtrl.convertToBill(session.verificationCode);
                          if (ok && dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                  child: isConverting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('1-Tap Convert to Bill'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
