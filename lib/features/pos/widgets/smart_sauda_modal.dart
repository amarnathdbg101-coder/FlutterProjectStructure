import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/utils/responsive.dart';
import '../models/pos_model.dart';

/// 🤝 Smart Sauda Modal: Privacy-First Bargaining & Rate Negotiation Engine
/// Strictly adheres to:
/// 1. Cost Price Privacy: Never reveals wholesale cost price to counter onlookers.
/// 2. Margin Safety Guardrail: Locks price when minimum floor is reached.
/// 3. 100% Data Consistency: Seamlessly updates cart, bill totals, and audit trail.
class SmartSaudaModal extends StatefulWidget {
  final PosCartItem item;
  final ValueChanged<double> onApplyPrice;

  const SmartSaudaModal({
    super.key,
    required this.item,
    required this.onApplyPrice,
  });

  static Future<void> show({
    required BuildContext context,
    required PosCartItem item,
    required ValueChanged<double> onApplyPrice,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartSaudaModal(
        item: item,
        onApplyPrice: onApplyPrice,
      ),
    );
  }

  @override
  State<SmartSaudaModal> createState() => _SmartSaudaModalState();
}

class _SmartSaudaModalState extends State<SmartSaudaModal> {
  late final TextEditingController _priceCtrl;
  late double _proposedPrice;

  double get originalPrice => widget.item.product.price;

  /// Internal barrier to prevent selling at a loss (NEVER exposed to UI text)
  double get minAllowedPrice {
    final floor = widget.item.product.floorPrice;
    final cost = widget.item.product.costPrice;
    if (floor > 0) return floor;
    if (cost > 0) return cost;
    return originalPrice * 0.80; // Safe default 20% max discount limit
  }

  bool get isSafeDeal => _proposedPrice >= minAllowedPrice;
  bool get hasDiscount => _proposedPrice < originalPrice;
  double get customerSavings => hasDiscount ? (originalPrice - _proposedPrice) * widget.item.quantity : 0.0;

  @override
  void initState() {
    super.initState();
    _proposedPrice = widget.item.customPrice;
    _priceCtrl = TextEditingController(text: _proposedPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _applyNewPrice(double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _proposedPrice = (newPrice * 100).round() / 100;
      _priceCtrl.text = _proposedPrice.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Text('🤝', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'स्मार्ट सौदा (मोलभाव दर)' : 'Smart Sauda (Rate Negotiation)',
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

          // Original Rate Card
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
                  isHindi ? 'मूल सूची दर (Listed Rate)' : 'Listed Rate',
                  style: TextStyle(fontSize: 13, color: context.colorTextSecondary),
                ),
                Text(
                  '₹${originalPrice.toStringAsFixed(0)} / ${widget.item.product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Price Input Field
          Text(
            isHindi ? 'नया सौदा दर (Deal Price per unit) *' : 'Agreed Deal Rate per unit *',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val) ?? 0.0;
                    setState(() => _proposedPrice = parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick 1-Tap Bargain Chips
          Text(
            isHindi ? '1-क्लिक मोलभाव शॉर्टकट:' : '1-Tap Quick Bargain Shortcuts:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.colorTextMuted),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip(
                  label: '- ₹2',
                  onTap: () => _applyNewPrice(originalPrice - 2),
                ),
                _buildQuickChip(
                  label: '- ₹5',
                  onTap: () => _applyNewPrice(originalPrice - 5),
                ),
                _buildQuickChip(
                  label: '- ₹10',
                  onTap: () => _applyNewPrice(originalPrice - 10),
                ),
                _buildQuickChip(
                  label: '5% OFF',
                  onTap: () => _applyNewPrice(originalPrice * 0.95),
                ),
                _buildQuickChip(
                  label: isHindi ? 'मूल दर (Reset)' : 'Reset (₹${originalPrice.toStringAsFixed(0)})',
                  isReset: true,
                  onTap: () => _applyNewPrice(originalPrice),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Private Margin & Safety Shield (CRITICAL: ZERO COST PRICE DISPLAYED)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSafeDeal
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSafeDeal
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSafeDeal ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  color: isSafeDeal ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSafeDeal
                            ? (isHindi ? 'सौदा सुरक्षित (Deal Approved)' : 'Deal Approved (Margin Safe)')
                            : (isHindi ? 'दर सीमा लॉक (Price Locked)' : 'Price Locked (Minimum Limit Reached)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSafeDeal ? AppColors.success : AppColors.error,
                        ),
                      ),
                      if (hasDiscount && isSafeDeal) ...[
                        const SizedBox(height: 2),
                        Text(
                          isHindi
                              ? 'ग्राहक बचत: ₹${customerSavings.toStringAsFixed(0)} (${((originalPrice - _proposedPrice) / originalPrice * 100).toStringAsFixed(0)}% छूट)'
                              : 'Customer Savings: ₹${customerSavings.toStringAsFixed(0)} (${((originalPrice - _proposedPrice) / originalPrice * 100).toStringAsFixed(0)}% OFF)',
                          style: TextStyle(fontSize: 11.5, color: context.colorTextPrimary),
                        ),
                      ] else if (!isSafeDeal) ...[
                        const SizedBox(height: 2),
                        Text(
                          isHindi
                              ? 'दुकान की न्यूनतम सीमा से नीचे मोलभाव संभव नहीं है।'
                              : 'Cannot reduce rate further. Below minimum allowed threshold.',
                          style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (!isSafeDeal || _proposedPrice <= 0)
                      ? null
                      : () {
                          widget.onApplyPrice(_proposedPrice);
                          Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    isHindi ? 'सौदा पक्का करें (Apply ₹${_proposedPrice.toStringAsFixed(0)})' : 'Apply Deal (₹${_proposedPrice.toStringAsFixed(0)})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    bool isReset = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isReset ? context.colorTextSecondary : AppColors.primary,
          ),
        ),
        backgroundColor: isReset
            ? context.colorSurfaceSubtle
            : AppColors.primary.withValues(alpha: 0.08),
        side: BorderSide(
          color: isReset
              ? context.colorBorder
              : AppColors.primary.withValues(alpha: 0.25),
        ),
        onPressed: onTap,
      ),
    );
  }
}
