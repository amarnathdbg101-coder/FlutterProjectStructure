import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/widgets/price_checker_dialog.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/services/smart_barcode_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Global Smart Barcode Auto-Fill Flow Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
    });

    test('Dove Shampoo EAN-13 and GTIN-14 resolution', () async {
      // Standard 13-digit EAN-13
      final dove = await SmartBarcodeCatalogService.lookup('8901030382910');
      expect(dove, isNotNull);
      expect(dove!.brand, 'Dove');
      expect(dove.name, contains('Dove'));
      expect(dove.mrp, greaterThan(0));
      expect(dove.sellingPrice, greaterThan(0));

      // GTIN-14 with leading 0 scanned by industrial camera
      final doveGtin14 = await SmartBarcodeCatalogService.lookup('08901030382910');
      expect(doveGtin14, isNotNull);
      expect(doveGtin14!.name, dove.name);

      // CategoryRegistry maps master catalog 'Personal Care' to canonical 'Personal Care & Beauty'
      final canonicalCat = CategoryRegistry.formatCategoryName(dove.category);
      expect(canonicalCat, 'Personal Care & Beauty');
      expect(CategoryRegistry.canonicalCategories.contains(canonicalCat), isTrue);
    });

    test('Parle-G Biscuits EAN-13 resolution and category canonical mapping', () async {
      final parle = await SmartBarcodeCatalogService.lookup('8901499001017');
      expect(parle, isNotNull);
      expect(parle!.brand, 'Parle');
      expect(parle.name, contains('Parle-G'));
      expect(parle.mrp, greaterThan(0));
      expect(parle.sellingPrice, greaterThan(0));

      // Maps 'Snacks & Branded Foods' to canonical 'Snacks & Munchies'
      final canonicalCat = CategoryRegistry.formatCategoryName(parle.category);
      expect(canonicalCat, 'Snacks & Munchies');
      expect(CategoryRegistry.canonicalCategories.contains(canonicalCat), isTrue);
    });

    test('Maggi 2-Minute Noodles resolution and category canonical mapping', () async {
      final maggi = await SmartBarcodeCatalogService.lookup('8901058852104');
      expect(maggi, isNotNull);
      expect(maggi!.brand, 'Maggi');
      expect(maggi.name, contains('Maggi'));
      expect(maggi.mrp, 14.0);
      expect(maggi.sellingPrice, 14.0);

      final canonicalCat = CategoryRegistry.formatCategoryName(maggi.category);
      expect(canonicalCat, 'Grocery & Staples');
      expect(CategoryRegistry.canonicalCategories.contains(canonicalCat), isTrue);
    });

    test('Fogg Scent and Fogg Body Spray resolution', () async {
      // 1. Fogg Scent Xpressio 100ml exact match
      final foggScent = await SmartBarcodeCatalogService.lookup('8904238300081');
      expect(foggScent, isNotNull);
      expect(foggScent!.name, contains('Fogg Scent Xpressio'));
      expect(foggScent.brand, 'Fogg');
      expect(foggScent.category, 'Personal Care & Beauty');
      expect(foggScent.mrp, 499.0);
      expect(foggScent.sellingPrice, 449.0);
      expect(foggScent.unit, '100ml');

      // 2. Fogg Napoleon Body Spray 150ml exact match
      final foggDeo = await SmartBarcodeCatalogService.lookup('8908001158244');
      expect(foggDeo, isNotNull);
      expect(foggDeo!.name, contains('Fogg Napoleon'));
      expect(foggDeo.brand, 'Fogg');
      expect(foggDeo.category, 'Personal Care & Beauty');
      expect(foggDeo.mrp, 250.0);
      expect(foggDeo.unit, '150ml');

      // 3. Unknown Fogg Scent barcode prefix match (8904238...)
      final foggScentPrefix = await SmartBarcodeCatalogService.lookup('8904238999999');
      expect(foggScentPrefix, isNotNull);
      expect(foggScentPrefix!.isPrefixMatch, isTrue);
      expect(foggScentPrefix.brand, 'Fogg Scent / Perfume');
      expect(foggScentPrefix.category, 'Personal Care & Beauty');
      expect(foggScentPrefix.mrp, greaterThan(0));

      // 4. Unknown Fogg Body Spray barcode prefix match (8908001...)
      final foggDeoPrefix = await SmartBarcodeCatalogService.lookup('8908001999999');
      expect(foggDeoPrefix, isNotNull);
      expect(foggDeoPrefix!.isPrefixMatch, isTrue);
      expect(foggDeoPrefix.brand, 'Fogg Body Spray / Deodorant');
      expect(foggDeoPrefix.category, 'Personal Care & Beauty');
    });

    test('FMCG Prefix Heuristics contain valid estimated MRP and selling prices', () async {
      // 8901030 = Hindustan Unilever prefix
      final unileverUnknown = await SmartBarcodeCatalogService.lookup('8901030999999');
      expect(unileverUnknown, isNotNull);
      expect(unileverUnknown!.isPrefixMatch, isTrue);
      expect(unileverUnknown.mrp, greaterThan(0));
      expect(unileverUnknown.sellingPrice, greaterThan(0));

      // 8901499 = Parle prefix
      final parleUnknown = await SmartBarcodeCatalogService.lookup('8901499999999');
      expect(parleUnknown, isNotNull);
      expect(parleUnknown!.isPrefixMatch, isTrue);
      expect(parleUnknown.mrp, greaterThan(0));

      // 8901058 = Nestlé prefix
      final nestleUnknown = await SmartBarcodeCatalogService.lookup('8901058999999');
      expect(nestleUnknown, isNotNull);
      expect(nestleUnknown!.isPrefixMatch, isTrue);
      expect(nestleUnknown.mrp, greaterThan(0));
    });

    testWidgets('PriceCheckerDialog renders Global Master Catalog card for unlisted Dove barcode', (tester) async {
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
            home: Scaffold(
              body: PriceCheckerDialog(initialQuery: '8901030382910'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Should identify and display Global Master Catalog match
      expect(find.textContaining('Found in Global Master Catalog'), findsOneWidget);
      expect(find.textContaining('Dove Daily Shine'), findsOneWidget);
      expect(find.textContaining('Brand: Dove'), findsOneWidget);

      // 2. 1-Tap Add to Store Inventory button is present
      expect(find.textContaining('Add to Store Inventory'), findsOneWidget);
    });

    testWidgets('PriceCheckerDialog renders Global Master Catalog card for unlisted Maggi barcode', (tester) async {
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
            home: Scaffold(
              body: PriceCheckerDialog(initialQuery: '8901058852104'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Found in Global Master Catalog'), findsOneWidget);
      expect(find.textContaining('Maggi 2-Minute Masala'), findsOneWidget);
      expect(find.textContaining('Brand: Maggi'), findsOneWidget);
      expect(find.textContaining('Add to Store Inventory'), findsOneWidget);
    });
  });
}
