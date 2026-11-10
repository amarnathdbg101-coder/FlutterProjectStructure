import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/hotkey_controller.dart';
import '../../products/models/product_model.dart';

class PosHotkeyGrid extends StatefulWidget {
  final Function(ProductModel product, double qty) onAddProduct;

  const PosHotkeyGrid({
    super.key,
    required this.onAddProduct,
  });

  @override
  State<PosHotkeyGrid> createState() => _PosHotkeyGridState();
}

class _PosHotkeyGridState extends State<PosHotkeyGrid> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HotkeyController>().loadHotkeys();
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
    } catch (_) {}
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final hotkeyCtrl = context.watch<HotkeyController>();
    final hotkeys = hotkeyCtrl.hotkeys;

    if (hotkeys.isEmpty && !hotkeyCtrl.isLoading) {
      return Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Touch Counter Hotkeys: 1-Tap fast billing',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => hotkeyCtrl.autoPopulate(),
              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
              label: const Text('Auto-Populate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0F172A)),
                SizedBox(width: 4),
                Text(
                  'HOT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hotkeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = hotkeys[index];
                final color = _parseColor(item.colorCode);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final prod = ProductModel(
                        id: item.productId,
                        name: item.productName.isNotEmpty ? item.productName : item.label,
                        price: item.sellingPrice,
                        stock: item.stockQuantity.toInt(),
                        category: 'General Store',
                        barcode: item.barcode,
                      );
                      widget.onAddProduct(prod, item.quickQuantity);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '₹${item.sellingPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => hotkeyCtrl.autoPopulate(),
            tooltip: 'Refresh Top Sellers',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
