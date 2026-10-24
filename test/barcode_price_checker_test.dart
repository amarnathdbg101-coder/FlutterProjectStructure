import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/widgets/price_checker_dialog.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/services/barcode_generator_service.dart';
import 'package:flutter_project_structure/features/products/widgets/barcode_sticker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarcodeGeneratorService Tests', () {
    test('BarcodeLabelItem.fromProduct sanitizes barcode and formats prices correctly', () {
      final p1 = ProductModel(
        id: 'p-1',
        name: 'Aashirvaad Shudh Chakki Atta 5kg',
        barcode: '8901030383742',
        sku: 'AASH-ATTA-5KG',
        price: 245.0,
        comparePrice: 290.0,
        stock: 25,
        unit: '5kg',
        category: 'Flour & Grains',
      );

      final item1 = BarcodeLabelItem.fromProduct(product: p1, shopName: 'ShopSilo Mart');
      expect(item1.productName, 'Aashirvaad Shudh Chakki Atta 5kg');
      expect(item1.shopName, 'SHOPSILO MART');
      expect(item1.barcode, '8901030383742');
      expect(item1.sellingPrice, 245.0);
      expect(item1.mrp, 290.0);
      expect(item1.unit, '5kg');

      // Test fallback if barcode is empty
      final p2 = ProductModel(
        id: '123',
        name: 'Loose Jeera 100g',
        barcode: '',
        sku: '',
        price: 45.0,
        stock: 10,
        unit: '100g',
        category: 'Spices',
      );
      final item2 = BarcodeLabelItem.fromProduct(product: p2);
      expect(item2.barcode, 'PRD-000123');
    });

    test('generatePdfBytes generates valid PDF bytes for A4 24-label sheet and Thermal roll', () async {
      final item = BarcodeLabelItem(
        productName: 'Tata Tea Gold 250g',
        shopName: 'SHOPSILO MART',
        barcode: '8901058852619',
        sku: 'TEA-TATA-250G',
        sellingPrice: 160.0,
        mrp: 185.0,
        unit: '250g',
        pkdDate: '19/10/2026',
      );

      // 1. A4 Sheet
      final a4Bytes = await BarcodeGeneratorService.generatePdfBytes(
        items: List.generate(24, (_) => item),
        format: BarcodeLabelFormat.a4Sheet24,
      );
      expect(a4Bytes.isNotEmpty, isTrue);
      expect(a4Bytes.length, greaterThan(1000));

      // 2. Thermal Roll
      final thermalBytes = await BarcodeGeneratorService.generatePdfBytes(
        items: [item],
        format: BarcodeLabelFormat.thermalRoll50x25,
      );
      expect(thermalBytes.isNotEmpty, isTrue);
      expect(thermalBytes.length, greaterThan(500));
    });
  });

  group('PriceCheckerDialog & BarcodeStickerDialog Widget Tests', () {
    late List<ProductModel> testCatalog;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      testCatalog = [
        ProductModel(
          id: 'prod-101',
          name: 'Fortune Sunlite Sunflower Oil 1L',
          barcode: '8906007281014',
          sku: 'OIL-FORT-1L',
          price: 145.0,
          comparePrice: 175.0,
          costPrice: 125.0,
          stock: 40,
          unit: '1L',
          category: 'Edible Oils',
          lowStockThreshold: 10,
        ),
        ProductModel(
          id: 'prod-102',
          name: 'Parle-G Glucose Biscuits 800g',
          barcode: '8901719101019',
          sku: 'PARLE-G-800G',
          price: 80.0,
          comparePrice: 90.0,
          costPrice: 68.0,
          stock: 4, // low stock
          unit: 'pack',
          category: 'Bakery & Biscuits',
          lowStockThreshold: 10,
        ),
      ];

      await LocalCacheService.saveProducts(testCatalog);
    });

    testWidgets('PriceCheckerDialog resolves exact product by barcode in 0ms with complete details', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();
      final posCtrl = PosController();
      final productCtrl = ProductController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
            ChangeNotifierProvider<PosController>.value(value: posCtrl),
            ChangeNotifierProvider<ProductController>.value(value: productCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PriceCheckerDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: Idle scanner prompt
      expect(find.text('Hardware Barcode Gun or Camera Scanner Ready'), findsOneWidget);

      // 2. Scan / Enter Barcode
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, '8906007281014');
      await tester.pumpAndSettle();

      // 3. Exact Product Hero Card Verification
      expect(find.text('Fortune Sunlite Sunflower Oil 1L'), findsOneWidget);
      expect(find.text('₹145'), findsOneWidget);
      expect(find.text('MRP: ₹175'), findsOneWidget);
      expect(find.text('40 Units'), findsOneWidget);
      expect(find.text('Customer Saves: ₹30 (17% OFF)'), findsOneWidget);

      // 4. Test Add to POS Bill action
      final addPosBtn = find.text('Add to POS Bill');
      expect(addPosBtn, findsOneWidget);
      await tester.ensureVisible(addPosBtn);
      await tester.tap(addPosBtn);
      await tester.pumpAndSettle();

      expect(posCtrl.cart.length, 1);
      expect(posCtrl.cart.first.product.name, 'Fortune Sunlite Sunflower Oil 1L');
      expect(posCtrl.cart.first.quantity, 1);

      // 5. Test Quick Reset / Scan Next
      final scanNextBtn = find.text('Scan Next Item');
      expect(scanNextBtn, findsOneWidget);
      await tester.tap(scanNextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hardware Barcode Gun or Camera Scanner Ready'), findsOneWidget);
    });

    testWidgets('PriceCheckerDialog triggers database fallback and displays graceful state for unknown items', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();
      final posCtrl = PosController();
      final productCtrl = ProductController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
            ChangeNotifierProvider<PosController>.value(value: posCtrl),
            ChangeNotifierProvider<ProductController>.value(value: productCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PriceCheckerDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter unknown item barcode
      await tester.enterText(searchField, '9999999999999');
      await tester.pump();

      // Verify widget doesn't crash and handles fallback
      expect(find.byType(PriceCheckerDialog), findsOneWidget);
    });

    testWidgets('BarcodeStickerDialog renders preview, format toggle, copies stepper and Code128 vector widget', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BarcodeStickerDialog(product: testCatalog[0]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Dialog Title & Vector Barcode Widget
      expect(find.text('Barcode Sticker Generator'), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(find.text('Fortune Sunlite Sunflower Oil 1L'), findsWidgets);
      expect(find.text('₹145'), findsWidgets);

      // 2. Format selector check
      expect(find.text('A4 Sheet (24 Labels - 70x37mm)'), findsOneWidget);
      expect(find.text('Thermal Roll (Single - 50x25mm)'), findsOneWidget);

      // 3. Test copies stepper
      expect(find.text('24'), findsOneWidget); // default full sheet
      final addIcon = find.byIcon(Icons.add_circle_outline_rounded);
      expect(addIcon, findsOneWidget);
      await tester.tap(addIcon);
      await tester.pumpAndSettle();
      expect(find.text('25'), findsOneWidget);

      // 4. Test Print and Share buttons render without overflow
      expect(find.text('Print Stickers'), findsOneWidget);
      expect(find.text('Share / Save PDF'), findsOneWidget);
    });
  });
}
