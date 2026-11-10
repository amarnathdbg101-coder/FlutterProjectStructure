import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/widgets/app_ui_components.dart';

/// ⚡ PosScratchpadModal: High-speed counter calculator for uncataloged loose items.
/// Specially tailored for Indian Cloth & Cosmetic retail:
/// (e.g. Fall-Pico, Alterations, Aster, Matching Buttons, Uncataloged Kajal/Bindi).
class PosScratchpadModal extends StatefulWidget {
  final void Function({required String name, required double price, required int quantity}) onAddItem;

  const PosScratchpadModal({
    super.key,
    required this.onAddItem,
  });

  static Future<void> show({
    required BuildContext context,
    required void Function({required String name, required double price, required int quantity}) onAddItem,
  }) {
    return AppModalSheet.show(
      context: context,
      builder: (_) => PosScratchpadModal(onAddItem: onAddItem),
    );
  }

  @override
  State<PosScratchpadModal> createState() => _PosScratchpadModalState();
}

class _PosScratchpadModalState extends State<PosScratchpadModal> {
  final _exprController = TextEditingController();
  final _nameController = TextEditingController(text: 'विविध सामान');
  double _calculatedTotal = 0.0;
  String _selectedPreset = 'विविध सामान';

  // Popular loose retail items in Indian Cloth & Beauty stores
  final List<Map<String, String>> _retailPresets = [
    {'hi': 'फॉल पिको', 'en': 'Fall & Pico'},
    {'hi': 'सूट फिटिंग / अल्टर', 'en': 'Suit Fitting / Alteration'},
    {'hi': 'मैचिंग अस्तर कपड़ा', 'en': 'Matching Aster Cloth'},
    {'hi': 'दुपट्टा डाई / मैचिंग', 'en': 'Dupatta Dye / Matching'},
    {'hi': 'बटन, ज़िप व लेस', 'en': 'Buttons, Zip & Lace'},
    {'hi': 'बिंदी, काजल व रबर', 'en': 'Bindi, Kajal & Bands'},
    {'hi': 'कॉस्मेटिक स्पंज / कॉटन', 'en': 'Makeup Sponge / Cotton'},
    {'hi': 'विविध सामान', 'en': 'Miscellaneous'},
  ];

  @override
  void initState() {
    super.initState();
    _exprController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _exprController.removeListener(_recalculate);
    _exprController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Evaluates simple addition/multiplication expressions like "40 + 25 + 15" or "30*2 + 10"
  void _recalculate() {
    final text = _exprController.text.trim();
    if (text.isEmpty) {
      setState(() => _calculatedTotal = 0.0);
      return;
    }

    try {
      // Split by '+'
      final parts = text.split('+');
      double sum = 0.0;
      for (final part in parts) {
        final clean = part.trim();
        if (clean.contains('*')) {
          final mulParts = clean.split('*');
          if (mulParts.length == 2) {
            final a = double.tryParse(mulParts[0].trim()) ?? 0.0;
            final b = double.tryParse(mulParts[1].trim()) ?? 0.0;
            sum += (a * b);
          }
        } else {
          final val = double.tryParse(clean) ?? 0.0;
          sum += val;
        }
      }
      setState(() => _calculatedTotal = (sum * 100).round() / 100);
    } catch (_) {
      setState(() => _calculatedTotal = 0.0);
    }
  }

  void _appendAddition(double amount) {
    if (_exprController.text.isEmpty) {
      _exprController.text = amount.toStringAsFixed(0);
    } else {
      _exprController.text = '${_exprController.text} + ${amount.toStringAsFixed(0)}';
    }
  }

  void _submit() {
    if (_calculatedTotal <= 0) return;
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : _selectedPreset;
    widget.onAddItem(
      name: name,
      price: _calculatedTotal,
      quantity: 1,
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
                child: const Icon(Icons.calculate_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? '⚡ काउंटर स्क्रैचपैड (खुला सामान)' : '⚡ Counter Scratchpad (Loose Items)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi
                          ? 'सिलाई, अस्तर, फॉल-पिको या बिना बारकोड का सामान तुरंत जोड़ें'
                          : 'Quick calculator for alterations, aster, fall-pico & loose items',
                      style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
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

          // 1. Calculation Expression & Total Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHindi ? 'गणना (उदा: 50 + 35 + 20):' : 'Calculation (e.g. 50 + 35 + 20):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                    ),
                    if (_exprController.text.isNotEmpty)
                      InkWell(
                        onTap: () => _exprController.clear(),
                        child: Text(
                          isHindi ? 'साफ़ करें' : 'Clear',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _exprController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '40 + 25 + 15',
                    hintStyle: TextStyle(color: context.colorTextMuted.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Divider(height: 18, color: context.colorBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHindi ? 'कुल राशि:' : 'TOTAL PRICE:',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    AppPriceTag(
                      price: _calculatedTotal,
                      size: AppPriceSize.lg,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Quick Increment Adders
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAdder('+ ₹10', () => _appendAddition(10)),
                _buildQuickAdder('+ ₹20', () => _appendAddition(20)),
                _buildQuickAdder('+ ₹50', () => _appendAddition(50)),
                _buildQuickAdder('+ ₹100', () => _appendAddition(100)),
                _buildQuickAdder('+ ₹200', () => _appendAddition(200)),
                _buildQuickAdder('+ ₹500', () => _appendAddition(500)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Quick Retail Presets (Cloth & Beauty)
          Text(
            isHindi ? 'सामान का प्रकार (1-टैप चुनें):' : 'Item Type (1-Tap Select):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colorTextMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _retailPresets.map((preset) {
              final label = isHindi ? preset['hi']! : preset['en']!;
              final isSelected = _selectedPreset == label;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedPreset = label;
                    _nameController.text = label;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : context.colorBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : context.colorTextPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 4. Custom Item Name Input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: isHindi ? 'सामान का नाम दर्ज करें...' : 'Item description...',
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Submit CTA Button
          AppButton(
            text: _calculatedTotal > 0
                ? (isHindi
                    ? '⚡ बिल में जोड़ें (₹${_calculatedTotal.toStringAsFixed(0)})'
                    : '⚡ Add to Active Cart (₹${_calculatedTotal.toStringAsFixed(0)})')
                : (isHindi ? 'राशि दर्ज करें' : 'Enter Calculation Amount'),
            size: AppButtonSize.lg,
            isFullWidth: true,
            icon: Icons.add_shopping_cart_rounded,
            onPressed: _calculatedTotal > 0 ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdder(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colorBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
