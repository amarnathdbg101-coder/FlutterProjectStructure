import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/widgets/batch_barcode_pairing_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatchBarcodePairingDialog Tests', () {
    late List<ProductModel> unmappedProducts;

    setUp(() {
      unmappedProducts = [
        ProductModel(
          id: 'p-101',
          name: 'Surf Excel Quick Wash 1kg',
          price: 145.0,
          comparePrice: 160.0,
          stock: 15,
          unit: 'packet',
          category: 'Cleaning & Household',
          attributes: {},
          sku: 'SURF-101',
          barcode: '',
          images: const [],
        ),
        ProductModel(
          id: 'p-102',
          name: 'Chana Dal Desi 500g',
          price: 65.0,
          comparePrice: 70.0,
          stock: 20,
          unit: 'packet',
          category: 'Grocery & Staples',
          attributes: {},
          sku: 'DAL-102',
          barcode: '',
          images: const [],
        ),
      ];
    });

    testWidgets('renders active product card, step counter, progress bar and skip/manual buttons', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final languageCtrl = LanguageController();

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>.value(
          value: languageCtrl,
          child: MaterialApp(
            home: Scaffold(
              body: BatchBarcodePairingDialog(
                unmappedProducts: unmappedProducts,
                onAssignBarcode: (product, code) async => true,
                onAutoGenerate: (product) async => true,
                onCheckDuplicate: (code) => false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Verify Header and Active Product info
      expect(find.textContaining('Batch Barcode Pairing'), findsOneWidget);
      expect(find.textContaining('Product 1 / 2'), findsOneWidget);
      expect(find.text('Surf Excel Quick Wash 1kg'), findsOneWidget);
      expect(find.text('₹145'), findsOneWidget);

      // 2. Verify Action Buttons (Skip, Auto Code, Manual)
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Auto Code'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);

      // 3. Tap Skip button -> moves to next product
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(find.text('Chana Dal Desi 500g'), findsOneWidget);
      expect(find.text('₹65'), findsOneWidget);
    });

    testWidgets('auto-generate button pairs product and advances queue', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final languageCtrl = LanguageController();
      bool autoGenCalled = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageController>.value(
          value: languageCtrl,
          child: MaterialApp(
            home: Scaffold(
              body: BatchBarcodePairingDialog(
                unmappedProducts: [unmappedProducts.first],
                onAssignBarcode: (product, code) async => true,
                onAutoGenerate: (product) async {
                  autoGenCalled = true;
                  return true;
                },
                onCheckDuplicate: (code) => false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Auto Code'), findsOneWidget);
      await tester.tap(find.text('Auto Code'));
      await tester.pump();

      expect(autoGenCalled, isTrue);
      // Wait for auto-advance delay (350ms)
      await tester.pump(const Duration(milliseconds: 500));

      // After last item is paired, celebration screen should be displayed
      expect(find.text('🎉 Batch Completed!'), findsOneWidget);
      expect(find.text('View Updated Catalog'), findsOneWidget);
    });
  });
}
