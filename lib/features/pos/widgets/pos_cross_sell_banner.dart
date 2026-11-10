import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/ai_features_controller.dart';
import '../controllers/pos_controller.dart';
import '../../products/models/product_model.dart';

class PosCrossSellBanner extends StatelessWidget {
  const PosCrossSellBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final aiCtrl = context.watch<AIFeaturesController>();
    final suggestions = aiCtrl.crossSellSuggestions;

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final topPick = suggestions.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Cross-Sell: ${topPick.suggestedProductName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E3A8A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(₹${topPick.estimatedPrice.toStringAsFixed(0)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
                if (topPick.cashierScriptHinglish.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '"${topPick.cashierScriptHinglish}"',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF1E40AF)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              final posCtrl = context.read<PosController>();
              final customProduct = ProductModel(
                id: 'cross_${DateTime.now().millisecondsSinceEpoch}',
                name: topPick.suggestedProductName,
                price: topPick.estimatedPrice,
                stock: 99,
                category: topPick.category.isNotEmpty ? topPick.category : 'General Store',
              );
              posCtrl.addToCart(customProduct, quantity: 1);
              aiCtrl.clearCrossSell();
            },
            child: const Text('+ Add', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => aiCtrl.clearCrossSell(),
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

