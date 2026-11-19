import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';

/// Represents an exact Indian textile & retail commercial color shade with Hindi trade name and Hex code.
class ColorShadeModel {
  final String shadeName;
  final String hindiName;
  final String hexCode;

  const ColorShadeModel({
    required this.shadeName,
    required this.hindiName,
    required this.hexCode,
  });

  Color get color {
    final clean = hexCode.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Colors.grey;
  }

  String get displayName => hindiName.isNotEmpty ? '$shadeName ($hindiName)' : shadeName;

  factory ColorShadeModel.fromMap(Map<String, dynamic> map) {
    return ColorShadeModel(
      shadeName: map['shade_name']?.toString() ?? '',
      hindiName: map['hindi_name']?.toString() ?? '',
      hexCode: map['hex_code']?.toString() ?? '#808080',
    );
  }
}

/// Checks whether a product category or title belongs to a color-critical trade domain
/// (such as textiles, apparel, blouse pieces, petticoats, sarees, footwear, cosmetics, bangles).
/// Returns `false` for groceries, FMCG, packaged foods, staples, beverages, hardware, electronics, etc.
bool isColorCriticalProduct({String? category, String? name}) {
  final combined = '${category ?? ''} ${name ?? ''}'.toLowerCase();
  if (combined.trim().isEmpty) return false;

  final words = combined
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toSet();

  // 1. Explicit Color-Critical Apparel, Textiles, Cosmetics & Fashion Tokens
  const colorCriticalTokens = {
    // Indian Textiles & Women's Wear
    'blouse', 'petticoat', 'saree', 'sari', 'sarees', 'kurti', 'kurtis', 'kurta', 'salwar', 'suit', 'suits',
    'dupatta', 'dupattas', 'chunni', 'lehenga', 'choli', 'abaya', 'burqa', 'hijab', 'frock',
    'gown', 'dress', 'dresses', 'top', 'tops', 'tunic', 'legging', 'leggings', 'plazo', 'palazzo', 'dhoti', 'lungi',
    'gamcha', 'rumal', 'handkerchief', 'scarf', 'stole', 'shawl', 'towel', 'towels', 'gamchha',
    // Fabrics & Tailoring
    'fabric', 'fabrics', 'cloth', 'clothing', 'kapda', 'thaan', 'aster', 'lining', 'silk', 'cotton',
    'chiffon', 'georgette', 'crepe', 'rayon', 'linen', 'velvet', 'net', 'zari',
    'thread', 'threads', 'nalka', 'dhaga', 'ribbon', 'lace', 'gota',
    // Men's & Western Apparel
    'shirt', 'shirts', 'tshirt', 'jeans', 'pant', 'pants', 'trouser', 'trousers',
    'cargo', 'shorts', 'trackpant', 'jacket', 'jackets', 'hoodie', 'sweater', 'blazer',
    'coat', 'sherwani', 'vest', 'baniyan', 'underwear', 'brief', 'bra', 'panty',
    // Home Textiles
    'bedsheet', 'bedsheets', 'chadar', 'curtain', 'curtains', 'parda', 'cushion', 'blanket',
    // Footwear
    'shoe', 'shoes', 'sneaker', 'sneakers', 'sandal', 'sandals', 'chappal', 'chappals', 'slipper', 'slippers', 'jutti', 'mojdi', 'heels', 'boots',
    // Cosmetics & Styling
    'lipstick', 'lipsticks', 'sindoor', 'eyeliner', 'blush', 'foundation', 'bangle', 'bangles', 'churi', 'chudi', 'purse', 'handbag', 'handbags',
    // Paint
    'paint', 'paints', 'distemper', 'enamel', 'primer',
  };

  for (final token in colorCriticalTokens) {
    if (words.contains(token)) return true;
  }

  // 2. Multi-word phrases
  const colorCriticalPhrases = [
    'nail polish', 'hair dye', 'hair color', 'eye shadow', 'pillow cover', 'formal pant', 'matching center'
  ];
  for (final phrase in colorCriticalPhrases) {
    if (combined.contains(phrase)) return true;
  }

  // 3. Category domain check
  final lowerCat = (category ?? '').toLowerCase();
  if (lowerCat.contains('cloth') || lowerCat.contains('apparel') ||
      lowerCat.contains('fashion') || lowerCat.contains('textile') ||
      lowerCat.contains('garment') || lowerCat.contains('cosmetic') ||
      lowerCat.contains('footwear')) {
    return true;
  }

  return false;
}

/// Standard Master Registry of Indian Textile, Blouse, Petticoat & Apparel Trade Shades.
const List<ColorShadeModel> kIndianTextileShadeRegistry = [
  // Greens & Parrot Shades (Crucial for Matching Centers & Blouse Pieces)
  ColorShadeModel(shadeName: 'Sugapankhi', hindiName: 'सुगापंखी/तोता', hexCode: '#7CB342'),
  ColorShadeModel(shadeName: 'Pista Green', hindiName: 'पिस्ता', hexCode: '#A8D8B9'),
  ColorShadeModel(shadeName: 'Rama Green', hindiName: 'रामा ग्रीन', hexCode: '#00827F'),
  ColorShadeModel(shadeName: 'Mehendi Green', hindiName: 'मेहंदी', hexCode: '#556B2F'),
  ColorShadeModel(shadeName: 'Bottle Green', hindiName: 'बॉटल ग्रीन', hexCode: '#004D40'),
  ColorShadeModel(shadeName: 'Morpankhi', hindiName: 'मोरपंखी', hexCode: '#005B5C'),

  // Yellows & Oranges
  ColorShadeModel(shadeName: 'Lemon Yellow', hindiName: 'पीला/नींबू', hexCode: '#FFF176'),
  ColorShadeModel(shadeName: 'Haldi Yellow', hindiName: 'हल्दी/सरसों', hexCode: '#FFB300'),
  ColorShadeModel(shadeName: 'Mustard Yellow', hindiName: 'राई/मस्टर्ड', hexCode: '#E5A823'),
  ColorShadeModel(shadeName: 'Rust', hindiName: 'गेरुआ/रस्ट', hexCode: '#B7410E'),
  ColorShadeModel(shadeName: 'Peach', hindiName: 'पीच', hexCode: '#FFAB91'),

  // Pinks & Reds
  ColorShadeModel(shadeName: 'Rani Pink', hindiName: 'रानी', hexCode: '#D81B60'),
  ColorShadeModel(shadeName: 'Baby Pink', hindiName: 'गुलाबी', hexCode: '#F48FB1'),
  ColorShadeModel(shadeName: 'Gajari', hindiName: 'गाजरी', hexCode: '#FF6F61'),
  ColorShadeModel(shadeName: 'Pyazi', hindiName: 'प्याज़ी', hexCode: '#A36B7E'),
  ColorShadeModel(shadeName: 'Blood Red', hindiName: 'लाल', hexCode: '#D32F2F'),
  ColorShadeModel(shadeName: 'Tamatar Red', hindiName: 'टमाटर लाल', hexCode: '#E53935'),
  ColorShadeModel(shadeName: 'Maroon', hindiName: 'मैरून', hexCode: '#800000'),
  ColorShadeModel(shadeName: 'Katha', hindiName: 'कत्था/कत्थई', hexCode: '#5D2524'),

  // Blues & Purples
  ColorShadeModel(shadeName: 'Firozi', hindiName: 'फ़िरोज़ी', hexCode: '#00BCD4'),
  ColorShadeModel(shadeName: 'Royal Blue', hindiName: 'रॉयल ब्लू', hexCode: '#1565C0'),
  ColorShadeModel(shadeName: 'Navy Blue', hindiName: 'नेवी ब्लू', hexCode: '#000080'),
  ColorShadeModel(shadeName: 'Wine', hindiName: 'वाइन/जामुनी', hexCode: '#4A154B'),
  ColorShadeModel(shadeName: 'Purple', hindiName: 'बैंगनी', hexCode: '#7B1FA2'),

  // Neutrals & Zari
  ColorShadeModel(shadeName: 'Off White', hindiName: 'सफेद', hexCode: '#FAF0E6'),
  ColorShadeModel(shadeName: 'Badami / Cream', hindiName: 'बादामी', hexCode: '#FFF8E7'),
  ColorShadeModel(shadeName: 'Chiku / Beige', hindiName: 'चीकू/बेज', hexCode: '#D7C4B7'),
  ColorShadeModel(shadeName: 'Coffee Brown', hindiName: 'भूरा', hexCode: '#4E342E'),
  ColorShadeModel(shadeName: 'Slate Grey', hindiName: 'ग्रे', hexCode: '#757575'),
  ColorShadeModel(shadeName: 'Z-Black', hindiName: 'काला', hexCode: '#1A1A1A'),
  ColorShadeModel(shadeName: 'Golden / Zari', hindiName: 'गोल्डन', hexCode: '#D4AF37'),
  ColorShadeModel(shadeName: 'Silver', hindiName: 'सिल्वर', hexCode: '#C0C0C0'),
];

/// Interactive Color Shade Calibrator Widget:
/// Displays the detected primary shade with a live color circle,
/// horizontal 1-tap quick correction chips, and a full shade picker.
class ColorShadeSelector extends StatefulWidget {
  final ColorShadeModel initialShade;
  final List<ColorShadeModel> alternatives;
  final ValueChanged<ColorShadeModel> onShadeSelected;
  final bool compact;

  const ColorShadeSelector({
    super.key,
    required this.initialShade,
    this.alternatives = const [],
    required this.onShadeSelected,
    this.compact = false,
  });

  @override
  State<ColorShadeSelector> createState() => _ColorShadeSelectorState();
}

class _ColorShadeSelectorState extends State<ColorShadeSelector> {
  late ColorShadeModel _currentShade;

  @override
  void initState() {
    super.initState();
    _currentShade = widget.initialShade;
  }

  @override
  void didUpdateWidget(covariant ColorShadeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialShade.shadeName != oldWidget.initialShade.shadeName ||
        widget.initialShade.hexCode != oldWidget.initialShade.hexCode) {
      _currentShade = widget.initialShade;
    }
  }

  void _selectShade(ColorShadeModel shade) {
    setState(() {
      _currentShade = shade;
    });
    widget.onShadeSelected(shade);
  }

  void _openFullShadePalette(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 10),
                decoration: BoxDecoration(
                  color: sheetCtx.colorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.palette_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sheetCtx.isHindi ? 'सभी कपड़ा / मैचिंग शेड्स' : 'All Textile Color Shades',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sheetCtx.colorTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextMuted, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: kIndianTextileShadeRegistry.length,
                  itemBuilder: (ctx, idx) {
                    final shade = kIndianTextileShadeRegistry[idx];
                    final isSelected = shade.shadeName.toLowerCase() == _currentShade.shadeName.toLowerCase();

                    return InkWell(
                      onTap: () {
                        _selectShade(shade);
                        Navigator.pop(sheetCtx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : sheetCtx.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : sheetCtx.colorBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: shade.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shade.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: sheetCtx.colorTextPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Weighted Euclidean Color Distance (CompuPhase algorithm).
  /// Models human eye sensitivity to red, green, and blue wavelengths.
  static int _colorDistance(Color c1, Color c2) {
    final v1 = c1.toARGB32();
    final v2 = c2.toARGB32();
    final r1 = (v1 >> 16) & 0xFF;
    final g1 = (v1 >> 8) & 0xFF;
    final b1 = v1 & 0xFF;
    final r2 = (v2 >> 16) & 0xFF;
    final g2 = (v2 >> 8) & 0xFF;
    final b2 = v2 & 0xFF;
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    final rmean = (r1 + r2) ~/ 2;
    return (((512 + rmean) * dr * dr) >> 8) + 4 * dg * dg + (((767 - rmean) * db * db) >> 8);
  }

  @override
  Widget build(BuildContext context) {
    // Unique list of quick chips: primary shade + true chromatic alternatives (without duplicates)
    final Set<String> seenNames = {};
    final List<ColorShadeModel> chips = [];

    // 1. Add current primary shade first
    seenNames.add(_currentShade.shadeName.toLowerCase());
    chips.add(_currentShade);

    // 2. Add AI proposed alternatives, but filter out wildly conflicting color families
    // (e.g. Distance > 100,000 prevents 'Red', 'Maroon', 'Black' from polluting 'Yellow' / 'Sugapankhi' chips)
    for (final alt in widget.alternatives) {
      if (!seenNames.contains(alt.shadeName.toLowerCase()) && alt.shadeName.isNotEmpty) {
        final dist = _colorDistance(alt.color, _currentShade.color);
        if (dist <= 100000) {
          seenNames.add(alt.shadeName.toLowerCase());
          chips.add(alt);
        }
      }
    }

    // 3. If fewer than 5 chips, pad with mathematically closest neighboring shades from Master Registry
    if (chips.length < 5) {
      final sortedRegistry = List<ColorShadeModel>.from(kIndianTextileShadeRegistry)
        ..sort((a, b) =>
            _colorDistance(a.color, _currentShade.color).compareTo(_colorDistance(b.color, _currentShade.color)));

      for (final std in sortedRegistry) {
        if (chips.length >= 5) break;
        if (!seenNames.contains(std.shadeName.toLowerCase())) {
          seenNames.add(std.shadeName.toLowerCase());
          chips.add(std);
        }
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12, vertical: widget.compact ? 8 : 10),
      decoration: BoxDecoration(
        color: context.colorSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Live Color Swatch & Verified Name
          Row(
            children: [
              // Live Color Circle
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _currentShade.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.isHindi ? 'सटीक रंग / शेड:' : 'Color Shade:',
                          style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _currentShade.displayName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: context.colorTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _openFullShadePalette(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        context.isHindi ? 'अन्य शेड्स' : 'More',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Horizontal 1-Tap Quick Correction Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: chips.map((shade) {
                final isSelected = shade.shadeName.toLowerCase() == _currentShade.shadeName.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _selectShade(shade),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? _currentShade.color.withValues(alpha: 0.15) : context.colorSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? _currentShade.color : context.colorBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: shade.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            shade.hindiName.isNotEmpty ? shade.hindiName : shade.shadeName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? context.colorTextPrimary : context.colorTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
