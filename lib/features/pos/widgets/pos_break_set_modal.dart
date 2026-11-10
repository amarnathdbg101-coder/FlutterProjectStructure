import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../models/pos_model.dart';

/// ✂️ PosBreakSetModal: Garments Set Decomposition Engine
/// Allows cashiers to break 2-piece / 3-piece composite suit sets on-the-fly
/// when a customer only wants to purchase a single piece (e.g. Kurti only, or Kurti + Dupatta).
class PosBreakSetModal extends StatefulWidget {
  final PosCartItem item;
  final void Function({
    required String selectedPieceName,
    required double selectedPiecePrice,
    required List<Map<String, dynamic>> remainingLoosePieces,
  }) onBreakSet;

  const PosBreakSetModal({
    super.key,
    required this.item,
    required this.onBreakSet,
  });

  static Future<void> show({
    required BuildContext context,
    required PosCartItem item,
    required void Function({
      required String selectedPieceName,
      required double selectedPiecePrice,
      required List<Map<String, dynamic>> remainingLoosePieces,
    }) onBreakSet,
  }) {
    return AppModalSheet.show(
      context: context,
      builder: (_) => PosBreakSetModal(
        item: item,
        onBreakSet: onBreakSet,
      ),
    );
  }

  @override
  State<PosBreakSetModal> createState() => _PosBreakSetModalState();
}

class _PosBreakSetModalState extends State<PosBreakSetModal> {
  late final double _setTotal;

  // Split pieces config: Name, default ratio, price controller, isSelected
  late final List<_BreakPieceItem> _pieces;

  @override
  void initState() {
    super.initState();
    _setTotal = widget.item.customPrice;

    // Default 3-Piece Breakdown (60% Kurti, 25% Bottom, 15% Dupatta)
    final kurtiPrice = (_setTotal * 0.60).roundToDouble();
    final pantPrice = (_setTotal * 0.25).roundToDouble();
    final dupattaPrice = (_setTotal - kurtiPrice - pantPrice);

    _pieces = [
      _BreakPieceItem(
        name: 'कुर्ती / टॉप (Kurti Only)',
        ratio: 0.60,
        controller: TextEditingController(text: kurtiPrice.toStringAsFixed(0)),
        isSelectedForCustomer: true, // Selected by default
      ),
      _BreakPieceItem(
        name: 'पैंट / प्लाज़ो (Pant / Bottom Only)',
        ratio: 0.25,
        controller: TextEditingController(text: pantPrice.toStringAsFixed(0)),
        isSelectedForCustomer: false,
      ),
      _BreakPieceItem(
        name: 'दुपट्टा / स्टोल (Dupatta Only)',
        ratio: 0.15,
        controller: TextEditingController(text: dupattaPrice.toStringAsFixed(0)),
        isSelectedForCustomer: false,
      ),
    ];
  }

  @override
  void dispose() {
    for (final p in _pieces) {
      p.controller.dispose();
    }
    super.dispose();
  }

  double get _customerSellingTotal {
    double sum = 0.0;
    for (final p in _pieces) {
      if (p.isSelectedForCustomer) {
        sum += double.tryParse(p.controller.text) ?? 0.0;
      }
    }
    return sum;
  }

  void _submit() {
    final selectedPieces = _pieces.where((p) => p.isSelectedForCustomer).toList();
    if (selectedPieces.isEmpty) return;

    final customerTitle = selectedPieces.length == 1
        ? '${widget.item.product.name} (${selectedPieces.first.name})'
        : '${widget.item.product.name} (${selectedPieces.map((p) => p.name.split(' ').first).join(' + ')})';

    final remainingLoose = <Map<String, dynamic>>[];
    for (final p in _pieces) {
      if (!p.isSelectedForCustomer) {
        remainingLoose.add({
          'name': '${widget.item.product.name} - ${p.name}',
          'price': double.tryParse(p.controller.text) ?? 0.0,
        });
      }
    }

    widget.onBreakSet(
      selectedPieceName: customerTitle,
      selectedPiecePrice: _customerSellingTotal,
      remainingLoosePieces: remainingLoose,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.content_cut_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? '✂️ सूट / सेट ब्रेक (टुकड़े अलग करें)' : '✂️ Break Garment Set (Sell Loose Piece)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Full Set Price Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHindi ? 'पूरे सेट की मूल दर:' : 'Original Full Set Rate:',
                  style: TextStyle(fontSize: 12.5, color: context.colorTextSecondary),
                ),
                AppPriceTag(price: _setTotal, size: AppPriceSize.md),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            isHindi ? 'ग्राहक क्या खरीद रहा है? (टिक करें):' : 'Which piece is the customer buying?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Breakdown Pieces List
          ..._pieces.map((piece) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: piece.isSelectedForCustomer
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : context.colorSurfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: piece.isSelectedForCustomer ? AppColors.primary : context.colorBorder,
                  width: piece.isSelectedForCustomer ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: piece.isSelectedForCustomer,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        piece.isSelectedForCustomer = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      piece.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: piece.isSelectedForCustomer ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 85,
                    child: TextField(
                      controller: piece.controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),

          // Split Summary & Remaining Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'बचे हुए टुकड़े स्वचालित रूप से ढीले स्टॉक (Loose Pieces) में दर्ज हो जाएंगे।'
                        : 'Unsold remaining pieces will be auto-saved as loose stock.',
                    style: const TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action CTA
          AppButton(
            text: _customerSellingTotal > 0
                ? (isHindi
                    ? '✓ चुने हुए टुकड़े बिल में रखें (₹${_customerSellingTotal.toStringAsFixed(0)})'
                    : '✓ Sell Selected Pieces (₹${_customerSellingTotal.toStringAsFixed(0)})')
                : (isHindi ? 'कम से कम एक टुकड़ा चुनें' : 'Select at least one piece'),
            size: AppButtonSize.lg,
            isFullWidth: true,
            icon: Icons.check_circle_outline_rounded,
            onPressed: _customerSellingTotal > 0 ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _BreakPieceItem {
  final String name;
  final double ratio;
  final TextEditingController controller;
  bool isSelectedForCustomer;

  _BreakPieceItem({
    required this.name,
    required this.ratio,
    required this.controller,
    required this.isSelectedForCustomer,
  });
}
