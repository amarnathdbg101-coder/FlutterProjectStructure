import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/services/audio_haptic_service.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../controllers/pos_controller.dart';

/// ⚡ PosQuickAddModal: 15-Second In-POS Product Registration & Instant Cart Add
///
/// Designed specifically for retail speed:
/// - 0ms interruption: Never navigates away from the active POS screen.
/// - Speech-to-Text Voice Mic: Cashier can speak item name effortlessly.
/// - Auto-SKU Generator: Instant barcode/SKU creation when unbarcoded.
/// - Profit Margin Preview: Live calculation of margin based on Cost & Selling price.
/// - Instantly adds 1 unit to the active customer bill and syncs to backend.
class PosQuickAddModal extends StatefulWidget {
  final PosController pos;
  final String? initialQuery;

  const PosQuickAddModal({
    super.key,
    required this.pos,
    this.initialQuery,
  });

  static Future<bool?> show({
    required BuildContext context,
    required PosController pos,
    String? initialQuery,
  }) {
    return AppModalSheet.show<bool>(
      context: context,
      builder: (ctx) => PosQuickAddModal(
        pos: pos,
        initialQuery: initialQuery,
      ),
    );
  }

  @override
  State<PosQuickAddModal> createState() => _PosQuickAddModalState();
}

class _PosQuickAddModalState extends State<PosQuickAddModal> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _stockCtrl;

  String _selectedUnit = 'pcs';
  bool _isSaving = false;

  final List<String> _units = ['pcs', 'kg', 'pack', 'box', 'ltr', 'gm', 'meter'];

  @override
  void initState() {
    super.initState();
    final raw = (widget.initialQuery ?? '').trim();
    final isBarcodeLike = raw.isNotEmpty && RegExp(r'^[0-9A-Za-z\-_]{6,}$').hasMatch(raw) && !raw.contains(' ');

    _nameCtrl = TextEditingController(text: isBarcodeLike ? '' : raw);
    _barcodeCtrl = TextEditingController(
      text: isBarcodeLike ? raw : 'SKU${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _priceCtrl = TextEditingController();
    _mrpCtrl = TextEditingController();
    _costCtrl = TextEditingController();
    _stockCtrl = TextEditingController(text: '50');

    _priceCtrl.addListener(_onPriceOrCostChanged);
    _costCtrl.addListener(_onPriceOrCostChanged);
  }

  void _onPriceOrCostChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _generateAutoSku() {
    final newSku = 'SKU${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _barcodeCtrl.text = newSku;
    AppAudioHapticFeedback.selection();
    setState(() {});
  }

  double get _sellingPrice => double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
  double get _costPrice => double.tryParse(_costCtrl.text.trim()) ?? 0.0;

  double get _calculatedMarginPct {
    if (_sellingPrice <= 0 || _costPrice <= 0 || _sellingPrice < _costPrice) return 0.0;
    return ((_sellingPrice - _costPrice) / _sellingPrice) * 100;
  }

  Future<void> _handleSaveAndAddToCart() async {
    final name = _nameCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();
    final price = _sellingPrice;
    final mrp = double.tryParse(_mrpCtrl.text.trim()) ?? price;
    final cost = _costPrice;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 50;

    final isHindi = context.isHindi;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? 'कृपया वस्तु का नाम दर्ज करें' : 'Please enter item name'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? 'बारकोड या SKU आवश्यक है' : 'Barcode or SKU is required'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? 'मान्य बिक्री मूल्य दर्ज करें' : 'Please enter a valid selling price'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await widget.pos.quickRegisterBarcodeAndAddToCart(
        barcode: barcode,
        name: name,
        price: price,
        mrp: mrp > 0 ? mrp : price,
        costPrice: cost,
        stock: stock,
        unit: _selectedUnit,
        category: 'General Store',
      );

      if (!mounted) return;

      if (success) {
        AppAudioHapticFeedback.scanSuccess();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi
                ? '⚡ "$name" बिल में जोड़ा गया और इन्वेंट्री में सेव हुआ!'
                : '⚡ "$name" added to active bill & saved to inventory!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'सामान जोड़ने में विफल' : 'Failed to register product'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final marginPct = _calculatedMarginPct;

    return AppModalSheet(
      title: isHindi ? '⚡ तुरंत नया सामान जोड़ें' : '⚡ Quick Product Registration',
      subtitle: isHindi
          ? 'बिल में तुरंत 0ms में जुड़ेगा और इन्वेंट्री में सेव होगा'
          : 'Instantly adds to bill (0ms) & saves to inventory',
      bottomActions: AppButton(
        text: isHindi
            ? '⚡ बिल में जोड़ें और सेव करें (0ms)'
            : '⚡ Add to Bill & Save (0ms)',
        icon: Icons.bolt_rounded,
        size: AppButtonSize.lg,
        isFullWidth: true,
        isLoading: _isSaving,
        onPressed: _handleSaveAndAddToCart,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Item Name with Speech-to-Text Voice Mic
            TextField(
              controller: _nameCtrl,
              autofocus: _nameCtrl.text.isEmpty,
              decoration: InputDecoration(
                labelText: isHindi ? 'वस्तु का नाम *' : 'Product Name *',
                hintText: isHindi ? 'उदा. सर्फ एक्सेल 500g' : 'e.g. Surf Excel 500g',
                suffixIcon: AppVoiceIconButton(
                  controller: _nameCtrl,
                  hint: isHindi ? 'वस्तु का नाम' : 'Product name',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Barcode / SKU field with Auto-SKU button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'बारकोड / SKU *' : 'Barcode / SKU *',
                      hintText: '8901234567890',
                      prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton.outline(
                  text: 'Auto SKU',
                  icon: Icons.auto_fix_high_rounded,
                  size: AppButtonSize.sm,
                  onPressed: _generateAutoSku,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Selling Price & MRP Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isHindi ? 'बिक्री मूल्य (₹) *' : 'Selling Price (₹) *',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _mrpCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isHindi ? 'MRP (₹)' : 'MRP (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Cost Price & Stock Quantity Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isHindi ? 'लागत मूल्य (₹)' : 'Cost Price (₹)',
                      prefixText: '₹ ',
                      hintText: 'Optional',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'प्रारंभिक स्टॉक' : 'Initial Stock',
                      hintText: '50',
                    ),
                  ),
                ),
              ],
            ),

            // Live Profit Margin preview if cost entered
            if (_sellingPrice > 0 && _costPrice > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sellingPrice >= _costPrice
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sellingPrice >= _costPrice
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: _sellingPrice >= _costPrice ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _sellingPrice >= _costPrice
                            ? (isHindi
                                ? 'अनुमानित मुनाफ़ा: +₹${(_sellingPrice - _costPrice).toStringAsFixed(1)} (${marginPct.toStringAsFixed(0)}% मार्जिन)'
                                : 'Est. Gross Margin: +₹${(_sellingPrice - _costPrice).toStringAsFixed(1)} (${marginPct.toStringAsFixed(0)}%)')
                            : (isHindi
                                ? 'चेतावनी: बिक्री मूल्य लागत से कम है (नुकसान)!'
                                : 'Warning: Selling price below cost (Loss)!'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _sellingPrice >= _costPrice ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // 5. Unit Selector Chips
            Text(
              isHindi ? 'इकाई (Unit):' : 'Unit of Measurement:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colorTextMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _units.map((unit) {
                final isSelected = _selectedUnit == unit;
                return ChoiceChip(
                  label: Text(unit),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedUnit = unit);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
