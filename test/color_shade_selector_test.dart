import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/products/widgets/color_shade_selector.dart';

void main() {
  group('ColorShadeSelector & Indian Textile Shade Card Tests', () {
    test('kIndianTextileShadeRegistry contains core matching center shades', () {
      final names = kIndianTextileShadeRegistry.map((s) => s.shadeName.toLowerCase()).toSet();
      expect(names.contains('rani pink'), isTrue);
      expect(names.contains('rama green'), isTrue);
      expect(names.contains('firozi'), isTrue);
      expect(names.contains('maroon'), isTrue);
      expect(names.contains('bottle green'), isTrue);
      expect(names.contains('mustard yellow'), isTrue);
      expect(names.contains('navy blue'), isTrue);
      expect(names.contains('wine'), isTrue);
    });

    test('ColorShadeModel parses hex correctly into Color', () {
      const shade = ColorShadeModel(
        shadeName: 'Rani Pink',
        hindiName: 'रानी',
        hexCode: '#D81B60',
      );
      expect(shade.color, const Color(0xFFD81B60));
      expect(shade.displayName, 'Rani Pink (रानी)');
    });

    testWidgets('renders ColorShadeSelector with active swatch and chips', (tester) async {
      ColorShadeModel? selected;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageController(),
          child: MaterialApp(
            home: Scaffold(
              body: ColorShadeSelector(
                initialShade: const ColorShadeModel(
                  shadeName: 'Rani Pink',
                  hindiName: 'रानी',
                  hexCode: '#D81B60',
                ),
                alternatives: const [
                  ColorShadeModel(
                    shadeName: 'Magenta',
                    hindiName: 'मजेंटा',
                    hexCode: '#E0115F',
                  ),
                  ColorShadeModel(
                    shadeName: 'Maroon',
                    hindiName: 'मैरून',
                    hexCode: '#800000',
                  ),
                ],
                onShadeSelected: (s) {
                  selected = s;
                },
              ),
            ),
          ),
        ),
      );

      // Verify header swatch text is displayed
      expect(find.text('Rani Pink (रानी)'), findsOneWidget);
      expect(find.text('रानी'), findsOneWidget);
      expect(find.text('मजेंटा'), findsOneWidget);

      // Tap on Magenta chip
      await tester.tap(find.text('मजेंटा'));
      await tester.pumpAndSettle();

      // Verify callback triggered
      expect(selected, isNotNull);
      expect(selected!.shadeName, 'Magenta');
    });

    test('kIndianTextileShadeRegistry contains Sugapankhi and regional matching shades', () {
      final names = kIndianTextileShadeRegistry.map((s) => s.shadeName.toLowerCase()).toSet();
      expect(names.contains('sugapankhi'), isTrue);
      expect(names.contains('gajari'), isTrue);
      expect(names.contains('pyazi'), isTrue);
      expect(names.contains('morpankhi'), isTrue);
      expect(names.contains('katha'), isTrue);
    });

    testWidgets('filters out wild conflicting alternatives (e.g. Red for Yellow/Sugapankhi)', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageController(),
          child: MaterialApp(
            home: Scaffold(
              body: ColorShadeSelector(
                initialShade: const ColorShadeModel(
                  shadeName: 'Lemon Yellow',
                  hindiName: 'पीला',
                  hexCode: '#FFF176',
                ),
                alternatives: const [
                  ColorShadeModel(
                    shadeName: 'Blood Red',
                    hindiName: 'लाल',
                    hexCode: '#D32F2F', // Distance > 180,000 to Yellow, should be filtered out!
                  ),
                  ColorShadeModel(
                    shadeName: 'Sugapankhi',
                    hindiName: 'सुगापंखी',
                    hexCode: '#7CB342', // Close chromatic neighbor!
                  ),
                ],
                onShadeSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify Sugapankhi is present in the chips
      expect(find.text('सुगापंखी'), findsOneWidget);

      // Verify Blood Red is NOT present in the quick chips because distance is too high!
      expect(find.text('लाल'), findsNothing);
    });

    group('isColorCriticalProduct Category & Product Domain Tests', () {
      test('identifies color-critical textiles, garments, and cosmetics correctly', () {
        expect(isColorCriticalProduct(category: 'Clothing & Fashion', name: 'Cotton Petticoat'), isTrue);
        expect(isColorCriticalProduct(category: 'General Store', name: 'Rubia 2x2 Blouse Piece'), isTrue);
        expect(isColorCriticalProduct(category: 'Ethnic Wear', name: 'Banarasi Silk Saree'), isTrue);
        expect(isColorCriticalProduct(category: 'Apparel', name: 'Rayon Kurti with Dupatta'), isTrue);
        expect(isColorCriticalProduct(category: 'Cosmetics', name: 'Matte Liquid Lipstick'), isTrue);
        expect(isColorCriticalProduct(category: 'Tailoring', name: 'Matching Aster Fabric 1 Meter'), isTrue);
        expect(isColorCriticalProduct(category: 'Fashion', name: 'Men Slim Fit Jeans Pant'), isTrue);
        expect(isColorCriticalProduct(category: 'Footwear', name: 'Bata Formal Leather Shoes'), isTrue);
      });

      test('identifies non-color groceries, FMCG, snacks, and commodities correctly', () {
        expect(isColorCriticalProduct(category: 'Grocery & Staples', name: 'Fortune Kachi Ghani Mustard Oil 1L'), isFalse);
        expect(isColorCriticalProduct(category: 'Kirana', name: 'Tata Salt Vacuum Evaporated 1kg Pouch'), isFalse);
        expect(isColorCriticalProduct(category: 'Snacks', name: 'Parle-G Gold Biscuits 100g'), isFalse);
        expect(isColorCriticalProduct(category: 'Staples', name: 'Aashirvaad Shudh Chakki Atta 10kg'), isFalse);
        expect(isColorCriticalProduct(category: 'Beverages', name: 'Tata Tea Gold Leaf Tea 500g'), isFalse);
        expect(isColorCriticalProduct(category: 'Personal Care', name: 'Dettol Original Bathing Soap 125g'), isFalse);
        expect(isColorCriticalProduct(category: 'Dairy', name: 'Amul Butter 500g Box'), isFalse);
        expect(isColorCriticalProduct(category: 'Hardware', name: 'Finolex 2.5 Sq mm Copper Wire'), isFalse);
        expect(isColorCriticalProduct(category: 'Pharmacy', name: 'Paracetamol 650mg Tablets'), isFalse);
      });
    });
  });
}
