import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/ai_features_controller.dart';
import '../controllers/pos_controller.dart';
import '../../products/models/product_model.dart';

class VoiceBillModal {
  static void show(BuildContext context) {
    final speechCtrl = TextEditingController(text: '2 packet bread, 1 butter aur 3 Tata salt');

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<AIFeaturesController>(
        builder: (ctx, aiCtrl, _) {
          final voiceResult = aiCtrl.lastVoiceBill;
          final isProcessing = aiCtrl.isProcessingVoice;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.mic_rounded, color: Color(0xFFDC2626), size: 26),
                SizedBox(width: 8),
                Text('Voice-to-Bill Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      'Speak or type your customer order in everyday Hinglish. AI will parse items, quantities, and rates automatically into bill:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: speechCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Spoken / Typed Order',
                        hintText: 'e.g. 2 packet doodh, 1 bread, 500g butter',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.mic_rounded, color: Color(0xFFDC2626)),
                          tooltip: 'Dictate Order',
                          onPressed: () {
                            // Quick toggle voice sample
                            speechCtrl.text = '2 packet bread, 1 butter aur 3 Tata salt';
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isProcessing ? null : () => aiCtrl.processVoiceInput(speechCtrl.text.trim()),
                        icon: isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Parse Order via AI', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (voiceResult != null) ...[
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
                                const Text('Matched Items for Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '₹${voiceResult.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: voiceResult.matchedItems.length,
                                separatorBuilder: (_, _) => const Divider(height: 6),
                                itemBuilder: (context, idx) {
                                  final item = voiceResult.matchedItems[idx];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.quantity.toStringAsFixed(0)}x ${item.productName}',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
                            if (voiceResult.unmatchedText.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '⚠️ Unmatched Words: ${voiceResult.unmatchedText.join(", ")}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                              ),
                            ],
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
                  aiCtrl.clearVoiceBill();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Close'),
              ),
              if (voiceResult != null && voiceResult.matchedItems.isNotEmpty) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final posCtrl = context.read<PosController>();
                    for (final item in voiceResult.matchedItems) {
                      final prod = ProductModel(
                        id: item.productId.isNotEmpty ? item.productId : 'voice_${DateTime.now().millisecondsSinceEpoch}',
                        name: item.productName,
                        price: item.unitPrice,
                        stock: 50,
                        unit: item.unit,
                        category: 'General Store',
                      );
                      posCtrl.addToCart(prod, quantity: item.quantity.toInt() > 0 ? item.quantity.toInt() : 1);
                    }
                    aiCtrl.clearVoiceBill();
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Loaded ${voiceResult.matchedItems.length} voice items into POS cart!'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('Add to Active Bill'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

