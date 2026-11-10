import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/ai_features_controller.dart';
import '../controllers/pos_controller.dart';
import '../../products/models/product_model.dart';

class DeadStockBundlerModal {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<AIFeaturesController>(
        builder: (ctx, aiCtrl, _) {
          final bundles = aiCtrl.deadStockBundles;
          final isLoading = aiCtrl.isLoadingBundles;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 8),
                Text('Dead-Stock Smart Bundler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      'AI pairs unsold/slow-moving inventory with top fast-moving anchor products as irresistible discount combo packs to liquidate dead stock:',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ] else if (bundles.isEmpty) ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'No dead stock found! Store inventory is moving smoothly.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => aiCtrl.loadDeadStockBundles(),
                              child: const Text('Scan Inventory'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: bundles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final b = bundles[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
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
                                      Expanded(
                                        child: Text(
                                          b.bundleName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Save ₹${b.customerSavings.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF16A34A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '⚓ Anchor: ${b.fastMovingAnchor}\n📦 Dead Stock: ${b.slowMovingItem}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                  if (b.pitchLineHinglish.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '"${b.pitchLineHinglish}"',
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                  const Divider(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '₹${b.originalTotal.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '₹${b.bundlePrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          final posCtrl = context.read<PosController>();
                                          final prod = ProductModel(
                                            id: 'bundle_${DateTime.now().millisecondsSinceEpoch}',
                                            name: b.bundleName,
                                            price: b.bundlePrice,
                                            stock: 50,
                                            category: 'Combo Offer',
                                          );
                                          posCtrl.addToCart(prod, quantity: 1);
                                          Navigator.pop(dialogCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('✓ Loaded "${b.bundleName}" (₹${b.bundlePrice.toStringAsFixed(0)}) into POS cart!'),
                                              backgroundColor: const Color(0xFF16A34A),
                                            ),
                                          );
                                        },
                                        child: const Text('Add Bundle', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
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
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

