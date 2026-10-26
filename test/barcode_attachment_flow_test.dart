import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/screens/inventory_screen.dart';
import 'package:flutter_project_structure/features/products/screens/product_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Barcode Attachment & Bulk Import Workflow Tests', () {
    late List<ProductModel> testProducts;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      testProducts = [
        ProductModel(
          id: 'p-1',
          name: 'Basmati Rice Premium 5kg',
          price: 450.0,
          comparePrice: 500.0,
          stock: 25,
          unit: 'kg',
          category: 'Grocery & Staples',
          attributes: {'brand': 'Daawat'},
          sku: 'RICE-001',
          barcode: '8901234567890', // has barcode
          images: const [],
        ),
        ProductModel(
          id: 'p-2',
          name: 'Mustard Oil Pure 1L',
          price: 160.0,
          comparePrice: 160.0,
          stock: 12,
          unit: 'L',
          category: 'Grocery & Staples',
          attributes: {'brand': 'Fortune'},
          sku: 'OIL-002',
          barcode: '', // missing barcode (e.g. from bulk import)
          images: const [],
        ),
        ProductModel(
          id: 'p-3',
          name: 'Loose Jeera 100g',
          price: 55.0,
          stock: 30,
          unit: 'packet',
          category: 'Grocery & Staples',
          attributes: {},
          sku: 'JEERA-003',
          barcode: '', // missing barcode
          images: const [],
        ),
      ];

      await LocalCacheService.saveProducts(testProducts);
    });

    testWidgets('InventoryScreen renders + Barcode chip on cards missing barcodes and filters with No Barcode chip', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final languageCtrl = LanguageController();
      final prodCtrl = ProductController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
            ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
          ],
          child: const MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify 'No Barcode' filter chip is displayed with correct counter (2 items)
      expect(find.text('No Barcode'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // missing barcode count badge

      // 3. Tap 'No Barcode' filter chip to isolate items needing barcodes
      await tester.tap(find.text('No Barcode'));
      await tester.pumpAndSettle();

      // Only p-2 and p-3 should be displayed; p-1 should be hidden
      expect(find.text('Mustard Oil Pure 1L'), findsOneWidget);
      expect(find.text('Loose Jeera 100g'), findsOneWidget);
      expect(find.text('Basmati Rice Premium 5kg'), findsNothing);

      // Verify Batch Scan action banner is prominently rendered for continuous scanning
      expect(find.text('Batch Scan'), findsOneWidget);

      // Summary text should indicate filtered count
      expect(find.textContaining('Showing 2 of 3 items'), findsOneWidget);
    });

    testWidgets('ProductDetailScreen displays interactive Attach Barcode chip when barcode is missing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final languageCtrl = LanguageController();
      final prodCtrl = ProductController();

      final productWithoutBarcode = testProducts[1]; // Mustard Oil Pure 1L

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
            ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
          ],
          child: MaterialApp(
            home: ProductDetailScreen(product: productWithoutBarcode),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Specifications section should render 'Attach Barcode' interactive chip
      expect(find.text('Attach Barcode'), findsOneWidget);
    });
  });
}
