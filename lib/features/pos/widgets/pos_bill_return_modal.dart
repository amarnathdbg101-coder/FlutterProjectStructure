import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';

/// Interactive In-Store POS Bill Return & Restock Modal Sheet
class PosBillReturnModal extends StatefulWidget {
  final SaleModel sale;
  final VoidCallback? onReturnSuccess;

  const PosBillReturnModal({
    super.key,
    required this.sale,
    this.onReturnSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required SaleModel sale,
    VoidCallback? onReturnSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosBillReturnModal(
        sale: sale,
        onReturnSuccess: onReturnSuccess,
      ),
    );
  }

  @override
  State<PosBillReturnModal> createState() => _PosBillReturnModalState();
}

class _PosBillReturnModalState extends State<PosBillReturnModal> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final Map<String, int> _selectedReturnQtys = {}; // productId -> return qty
  String _refundMode = 'cash'; // 'cash', 'khata', 'credit_note'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate return items with default 0 qty
    for (final item in widget.sale.items) {
      final pid = item.product.id;
      if (pid.isNotEmpty && !pid.startsWith('custom_')) {
        _selectedReturnQtys[pid] = 0;
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _computedTotalRefund {
    double total = 0.0;
    for (final item in widget.sale.items) {
      final pid = item.product.id;
      final qty = _selectedReturnQtys[pid] ?? 0;
      if (qty > 0) {
        total += (item.effectivePrice * qty);
      }
    }
    return total;
  }

  int get _totalReturnItemCount {
    int count = 0;
    _selectedReturnQtys.forEach((_, q) => count += q);
    return count;
  }

  Future<void> _submitReturn() async {
    final returnItems = <Map<String, dynamic>>[];
    _selectedReturnQtys.forEach((pid, qty) {
      if (qty > 0) {
        returnItems.add({
          'product_id': pid,
          'quantity': qty,
        });
      }
    });

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.isHindi ? 'कृपया वापसी के लिए कम से कम एक सामान चुनें' : 'Please select at least one item to return'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final pos = context.read<PosController>();

    final res = await pos.processBillReturn(
      billNumber: widget.sale.billNumber ?? '',
      items: returnItems,
      refundMode: _refundMode,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success) {
      Navigator.pop(context);
      widget.onReturnSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.isHindi
              ? '✓ वापसी दर्ज हुई और सामान स्टॉक में जुड़ गया (रिफंड: ₹${_computedTotalRefund.toStringAsFixed(0)})'
              : '✓ Return processed & items restocked to inventory (Refund: ₹${_computedTotalRefund.toStringAsFixed(0)})'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? (context.isHindi ? 'वापसी दर्ज नहीं हो सकी' : 'Failed to process return')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final totalRefund = _computedTotalRefund;
    final returnItemsCount = _totalReturnItemCount;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 14,
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 580,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_return_rounded, color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'समान वापसी / रिफंड (POS Return)' : 'Process Bill Return & Refund',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Bill #: ${widget.sale.billNumber ?? "WALK-IN"}',
                      style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isHindi ? 'वापस किया जाने वाला सामान चुनें:' : 'Select items to return & restock:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Items List with Stepper
                  ...widget.sale.items.map((item) {
                    final pid = item.product.id;
                    final maxQty = item.quantity;
                    final isCustom = pid.startsWith('custom_') || pid.isEmpty;
                    final returnQty = _selectedReturnQtys[pid] ?? 0;
                    final isSelected = returnQty > 0;

                    if (isCustom) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.colorBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.product.name} (Ad-hoc custom item - cannot be restocked)',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : context.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : context.colorBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                _selectedReturnQtys[pid] = (val == true) ? 1 : 0;
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '₹${item.effectivePrice.toStringAsFixed(0)} / ${item.product.unit.isNotEmpty ? item.product.unit : 'unit'} | Sold: $maxQty',
                                  style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            InkWell(
                              onTap: () {
                                if (returnQty > 1) {
                                  setState(() => _selectedReturnQtys[pid] = returnQty - 1);
                                } else {
                                  setState(() => _selectedReturnQtys[pid] = 0);
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.colorSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: context.colorBorder),
                                ),
                                child: const Icon(Icons.remove, size: 16),
                              ),
                            ),
                            Container(
                              width: 34,
                              alignment: Alignment.center,
                              child: Text('$returnQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ),
                            InkWell(
                              onTap: () {
                                if (returnQty < maxQty) {
                                  setState(() => _selectedReturnQtys[pid] = returnQty + 1);
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.colorSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: context.colorBorder),
                                ),
                                child: const Icon(Icons.add, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${(item.effectivePrice * returnQty).toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Refund Mode Selector
                  Text(
                    isHindi ? 'रिफंड का तरीका (Refund Mode):' : 'Refund Mode:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(isHindi ? '💵 नकद रिफंड (Cash)' : '💵 Cash Refund'),
                        selected: _refundMode == 'cash',
                        onSelected: (val) => setState(() => _refundMode = 'cash'),
                      ),
                      ChoiceChip(
                        label: Text(isHindi ? '📒 खाता एडजस्ट (Khata Credit)' : '📒 Khata Adjust'),
                        selected: _refundMode == 'khata',
                        onSelected: (val) => setState(() => _refundMode = 'khata'),
                      ),
                      ChoiceChip(
                        label: Text(isHindi ? '🎟️ स्टोर क्रेडिट (Credit Note)' : '🎟️ Store Credit Note'),
                        selected: _refundMode == 'credit_note',
                        onSelected: (val) => setState(() => _refundMode = 'credit_note'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reason / Notes
                  TextField(
                    controller: _reasonCtrl,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'वापसी का कारण (वैकल्पिक)' : 'Reason for Return (Optional)',
                      hintText: isHindi ? 'उदा: खराब सामान, गलत साइज, एक्सपायरी' : 'e.g. Defective piece, wrong size, exchange',
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Refund Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'कुल रिफंड राशि:' : 'Total Refund Payable:',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '$returnItemsCount ${isHindi ? 'सामान वापस' : 'items returning'}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        Text(
                          '₹${totalRefund.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(
              _isSubmitting
                  ? (isHindi ? 'वापसी दर्ज हो रही है...' : 'Processing Return...')
                  : (isHindi ? 'वापसी दर्ज करें और स्टॉक में जोड़ें' : 'Confirm Return & Restock Inventory'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: (_isSubmitting || returnItemsCount == 0) ? null : _submitReturn,
          ),
        ],
      ),
    );
  }
}
