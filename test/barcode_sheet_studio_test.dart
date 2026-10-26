import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/category_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/screens/barcode_sheet_studio_screen.dart';
import 'package:flutter_project_structure/features/products/services/barcode_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarcodeGeneratorService & SheetPackingStats Tests', () {
    test('calculatePacking computes accurate A4-65 micro sheet utilization', () {
      // 1. Two stickers on A4-65
      final stats2 = BarcodeGeneratorService.calculatePacking(
        totalStickers: 2,
        format: BarcodeLabelFormat.a4Sheet65,
      );
      expect(stats2.totalStickers, 2);
      expect(stats2.labelsPerPage, 65);
      expect(stats2.pagesNeeded, 1);
      expect(stats2.emptySlotsOnLastPage, 63);
      expect(stats2.utilizationPercentage, closeTo((2 / 65) * 100, 0.1));

      // 2. 70 stickers on A4-65 (requires 2 pages)
      final stats70 = BarcodeGeneratorService.calculatePacking(
        totalStickers: 70,
        format: BarcodeLabelFormat.a4Sheet65,
      );
      expect(stats70.pagesNeeded, 2);
      expect(stats70.emptySlotsOnLastPage, 60); // 130 capacity - 70 = 60

      // 3. Zero stickers
      final statsZero = BarcodeGeneratorService.calculatePacking(
        totalStickers: 0,
        format: BarcodeLabelFormat.a4Sheet65,
      );
      expect(statsZero.pagesNeeded, 0);
      expect(statsZero.emptySlotsOnLastPage, 0);
    });

    test('calculatePacking handles A4-40 and A4-24 standard sheets', () {
      // 40 compact sheet with 10 stickers
      final stats40 = BarcodeGeneratorService.calculatePacking(
        totalStickers: 10,
        format: BarcodeLabelFormat.a4Sheet40,
      );
      expect(stats40.labelsPerPage, 40);
      expect(stats40.pagesNeeded, 1);
      expect(stats40.emptySlotsOnLastPage, 30);

      // 24 standard sheet with 25 stickers (2 pages)
      final stats24 = BarcodeGeneratorService.calculatePacking(
        totalStickers: 25,
        format: BarcodeLabelFormat.a4Sheet24,
      );
      expect(stats24.labelsPerPage, 24);
      expect(stats24.pagesNeeded, 2);
      expect(stats24.emptySlotsOnLastPage, 23);
    });

    test('generatePdfBytes generates valid bytes for A4-65 micro and A4-40 sheets with multi-product mixing', () async {
      final p1 = ProductModel(
        id: '1',
        name: 'Everest Garam Masala 100g',
        barcode: '8901786111111',
        sku: 'EVE-GM-100',
        price: 78.0,
        comparePrice: 85.0,
        stock: 20,
        unit: 'box',
        category: 'Spices',
      );
      final p2 = ProductModel(
        id: '2',
        name: 'Dove Bar Soap 75g',
        barcode: '8901030999999',
        sku: 'DOVE-SOAP-75G',
        price: 54.0,
        stock: 15,
        unit: 'bar',
        category: 'Personal Care',
      );

      final mixedItems = [
        BarcodeLabelItem.fromProduct(product: p1),
        BarcodeLabelItem.fromProduct(product: p1), // 2 of p1
        BarcodeLabelItem.fromProduct(product: p2), // 1 of p2
      ];

      // A4-65 Micro Sheet
      final microBytes = await BarcodeGeneratorService.generatePdfBytes(
        items: mixedItems,
        format: BarcodeLabelFormat.a4Sheet65,
      );
      expect(microBytes.isNotEmpty, isTrue);
      expect(microBytes.length, greaterThan(1000));

      // A4-40 Compact Sheet
      final compactBytes = await BarcodeGeneratorService.generatePdfBytes(
        items: mixedItems,
        format: BarcodeLabelFormat.a4Sheet40,
      );
      expect(compactBytes.isNotEmpty, isTrue);
      expect(compactBytes.length, greaterThan(1000));
    });
  });

  group('BarcodeSheetStudioScreen Widget & Responsiveness Tests', () {
    late List<ProductModel> catalog;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      catalog = [
        ProductModel(
          id: 'prod-1',
          name: 'Tata Salt 1kg',
          barcode: '8901030000001',
          sku: 'TATA-SALT',
          price: 28.0,
          comparePrice: 30.0,
          stock: 45,
          unit: 'pkt',
          category: 'Grocery',
        ),
        ProductModel(
          id: 'prod-2',
          name: 'Maggi 2-Minute Noodles 70g',
          barcode: '8901058852619',
          sku: 'MAGGI-70G',
          price: 14.0,
          stock: 60,
          unit: 'pkt',
          category: 'Snacks',
        ),
      ];

      await LocalCacheService.saveProducts(catalog);
    });

    testWidgets('BarcodeSheetStudioScreen renders queue, format choices, and live stats with zero overflow on mobile (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();
      final prodCtrl = ProductController();
      final catCtrl = CategoryController();
      prodCtrl.setProductsForTesting(catalog);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
            ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
            ChangeNotifierProvider<CategoryController>.value(value: catCtrl),
          ],
          child: MaterialApp(
            home: BarcodeSheetStudioScreen(
              initialProduct: catalog.first,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify AppBar and initial product queued
      expect(find.textContaining('Barcode Print Studio'), findsOneWidget);
      expect(find.text('Tata Salt 1kg'), findsWidgets);
      expect(find.text('₹28'), findsWidgets);

      // 2. Format options exist
      expect(find.textContaining('A4 • 65 Micro'), findsOneWidget);
      expect(find.textContaining('A4 • 40 Compact'), findsOneWidget);
      expect(find.textContaining('A4 • 24 Standard'), findsOneWidget);

      // 3. Verify Bottom Action Buttons
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.textContaining('Print Barcode Sheet'), findsOneWidget);

      // 4. Tap '+' stepper button to increase quantity
      final addIconFinder = find.byIcon(Icons.add_circle_outline_rounded);
      expect(addIconFinder, findsOneWidget);
      await tester.tap(addIconFinder);
      await tester.pump();

      // Now total count is 2
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('BarcodeSheetStudioScreen renders responsive two-column layout on Desktop (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();
      final prodCtrl = ProductController();
      final catCtrl = CategoryController();
      prodCtrl.setProductsForTesting(catalog);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
            ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
            ChangeNotifierProvider<CategoryController>.value(value: catCtrl),
          ],
          child: const MaterialApp(
            home: BarcodeSheetStudioScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Empty state
      expect(find.text('Print Queue is Empty'), findsOneWidget);

      // Format options and paper stats visible
      expect(find.text('1. Select Sticker Sheet Format'), findsOneWidget);
      expect(find.text('3. Sheet Utilization & Paper Stats'), findsOneWidget);
    });
  });
}
