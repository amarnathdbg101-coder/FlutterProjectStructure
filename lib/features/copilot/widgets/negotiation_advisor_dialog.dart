import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../pos/models/pos_model.dart';
import '../controllers/copilot_controller.dart';
import '../models/copilot_model.dart';

/// Confidential, margin-aware AI Negotiation Advisor Modal for POS counter.
/// Protects merchant profit, enforces hard cost floors, and provides winning scripts.
class NegotiationAdvisorDialog extends StatefulWidget {
  final PosCartItem item;
  final PosController pos;

  const NegotiationAdvisorDialog({
    super.key,
    required this.item,
    required this.pos,
  });

  static Future<void> show({
    required BuildContext context,
    required PosCartItem item,
    required PosController pos,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => NegotiationAdvisorDialog(item: item, pos: pos),
    );
  }

  @override
  State<NegotiationAdvisorDialog> createState() => _NegotiationAdvisorDialogState();
}

class _NegotiationAdvisorDialogState extends State<NegotiationAdvisorDialog> {
  late TextEditingController _priceCtrl;
  BargainEvaluationModel? _evaluation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.item.effectivePrice.toStringAsFixed(0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _evaluateOffer(double.tryParse(_priceCtrl.text) ?? widget.item.effectivePrice);
      }
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _evaluateOffer(double offeredPrice) async {
    if (offeredPrice <= 0) return;
    setState(() => _isLoading = true);

    final copilot = context.read<CopilotController>();
    BargainEvaluationModel? result = await copilot.evaluateBargain(
      productId: widget.item.product.id,
      offeredPrice: offeredPrice,
    );

    // 💡 Instant Offline Fallback Resilience: If cloud is offline, compute on-device!
    if (result == null && mounted) {
      final product = widget.item.product;
      final cost = product.costPrice > 0 ? product.costPrice : (product.price * 0.70);
      final floor = cost * 1.15;
      final isAcceptable = offeredPrice >= floor;
      final netProfit = offeredPrice - cost;

      String script;
      String warning = '';
      if (offeredPrice < cost) {
        warning = context.isHindi
            ? 'ऑफ़लाइन चेतावनी: दर ख़रीद मूल्य से कम है!'
            : 'Offline Warning: Rate is below purchase cost!';
        script = context.isHindi
            ? 'भैया कम से कम ₹${floor.toStringAsFixed(0)} में तय करें, नीचे नहीं दे सकते।'
            : 'Sir, please finalize at ₹${floor.toStringAsFixed(0)} minimum.';
      } else if (offeredPrice < floor) {
        script = context.isHindi
            ? 'भैया ₹${floor.toStringAsFixed(0)} में तय करें, इससे कम संभव नहीं है।'
            : 'Sir, ₹${floor.toStringAsFixed(0)} is our best possible rate.';
      } else {
        script = context.isHindi
            ? 'ठीक है भैया, ₹${offeredPrice.toStringAsFixed(0)} में पैक कर रहे हैं।'
            : 'Agreed, packing at ₹${offeredPrice.toStringAsFixed(0)}.';
      }

      result = BargainEvaluationModel(
        productId: product.id,
        productName: product.name,
        originalPrice: product.price,
        customerOfferedPrice: offeredPrice,
        costPrice: cost,
        hardFloorPrice: floor,
        isAcceptable: isAcceptable,
        suggestedCounterOffer: isAcceptable ? offeredPrice : floor,
        netProfitINR: netProfit > 0 ? netProfit : 0.0,
        inventoryAgeDays: 0,
        abcTier: 'B',
        xyzTier: 'Y',
        customerRFM: 'REGULAR',
        salesScript: script,
        warningMessage: warning,
      );
    }

    if (mounted) {
      setState(() {
        _evaluation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    Color statusColor = const Color(0xFF10B981);
    IconData statusIcon = Icons.check_circle_outline_rounded;
    String statusTitle = isHindi ? 'सुरक्षित सौदा' : 'Profitable Deal';

    if (_evaluation != null) {
      if (!_evaluation!.isAcceptable) {
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_outlined;
        statusTitle = isHindi ? 'हानिकारक सौदा • अस्वीकार करें' : 'Danger: Below Safe Floor';
      } else if (_evaluation!.warningMessage.isNotEmpty) {
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.warning_amber_rounded;
        statusTitle = isHindi ? 'डेड स्टॉक निकासी सौदा' : 'Dead Stock Clearance';
      }
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? 'गोपनीय सौदेबाजी सलाहकार' : 'Confidential Negotiation Advisor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.product.name} (MRP: ₹${item.product.price.toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Price Input with real-time check button
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isHindi ? 'ऑफर दर' : 'Offered Rate',
                        prefixText: '₹ ',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (val) {
                        final p = double.tryParse(val.trim());
                        if (p != null) _evaluateOffer(p);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            final p = double.tryParse(_priceCtrl.text.trim());
                            if (p != null) _evaluateOffer(p);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isHindi ? 'जांचें' : 'Check'),
                  ),
                ],
              ),
            const SizedBox(height: 14),

            // Evaluation Card
            if (_evaluation != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_evaluation!.isAcceptable && _evaluation!.netProfitINR > 0)
                          Text(
                            '+₹${_evaluation!.netProfitINR.toStringAsFixed(0)} ${isHindi ? "मुनाफ़ा" : "Profit"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                      ],
                    ),
                    if (_evaluation!.warningMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _evaluation!.warningMessage,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.record_voice_over_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${isHindi ? "ग्राहक से कहें:" : "Say to customer:"} "${_evaluation!.salesScript}"',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isHindi ? 'अनुशंसित दर:' : 'Recommended:',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '₹${_evaluation!.suggestedCounterOffer.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            _priceCtrl.text = _evaluation!.suggestedCounterOffer.toStringAsFixed(0);
                            _evaluateOffer(_evaluation!.suggestedCounterOffer);
                          },
                          child: Text(
                            isHindi ? 'यह दर भरें' : 'Use this rate',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final p = double.tryParse(_priceCtrl.text.trim());
                      if (p != null && p >= 0) {
                        widget.pos.updateCartItemPrice(widget.item, p);
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isHindi ? 'सौदा लागू करें' : 'Apply Deal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
