import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/screens/low_stock_alerts_screen.dart';
import 'package:flutter_project_structure/features/products/services/smart_stock_reorder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartStockReorderService Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();
    });

    test('getRecommendedReorderQuantity calculates 2x threshold or clamps to minimum 5', () {
      final pDefault = ProductModel(
        id: '1',
        name: 'Sugar 1kg',
        price: 45.0,
        stock: 2,
        lowStockThreshold: 0,
        category: 'Grocery & Staples',
      );
      expect(SmartStockReorderService.getRecommendedReorderQuantity(pDefault), 10);

      final pLow = ProductModel(
        id: '2',
        name: 'Salt 1kg',
        price: 20.0,
        stock: 1,
        lowStockThreshold: 2,
        category: 'Grocery & Staples',
      );
      expect(SmartStockReorderService.getRecommendedReorderQuantity(pLow), 5); // 2 * 2 = 4 < 5 -> clamps to 5

      final pHigh = ProductModel(
        id: '3',
        name: 'Sunflower Oil 1L',
        price: 150.0,
        stock: 3,
        lowStockThreshold: 12,
        category: 'Grocery & Staples',
      );
      expect(SmartStockReorderService.getRecommendedReorderQuantity(pHigh), 24); // 12 * 2 = 24
    });

    testWidgets('addToProcurementList adds and deduplicates items in LocalCacheService', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  final product = ProductModel(
                    id: '101',
                    name: 'Dove Shampoo 180ml',
                    price: 190.0,
                    costPrice: 160.0,
                    stock: 2,
                    lowStockThreshold: 6,
                    unit: 'bottle',
                    category: 'Personal Care & Beauty',
                    attributes: {'supplier': 'Hindustan Unilever Distributor'},
                  );

                  // 1st add
                  await SmartStockReorderService.addToProcurementList(
                    context,
                    product,
                    showToast: false,
                  );

                  final itemsAfterFirst = LocalCacheService.getProcurementItems();
                  expect(itemsAfterFirst.length, 1);
                  expect(itemsAfterFirst.first.name, 'Dove Shampoo 180ml');
                  expect(itemsAfterFirst.first.qty, '12 bottles');
                  expect(itemsAfterFirst.first.estimatedPrice, 160.0);

                  // 2nd add with explicit custom quantity
                  await SmartStockReorderService.addToProcurementList(
                    context,
                    product,
                    reorderQuantity: 30,
                    showToast: false,
                  );

                  final itemsAfterSecond = LocalCacheService.getProcurementItems();
                  expect(itemsAfterSecond.length, 1); // Deduplicated, not added twice
                  expect(itemsAfterSecond.first.qty, '30 bottles');
                },
                child: const Text('Add Single'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Add Single'));
      await tester.pumpAndSettle();
    });

    testWidgets('addAllLowStockToProcurement adds multiple low stock products without duplicates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  final products = [
                    ProductModel(
                      id: '201',
                      name: 'Tata Tea Gold 500g',
                      price: 320.0,
                      stock: 1,
                      lowStockThreshold: 5,
                      category: 'Beverages & Drinks',
                    ),
                    ProductModel(
                      id: '202',
                      name: 'Aashirvaad Atta 5kg',
                      price: 260.0,
                      stock: 0,
                      lowStockThreshold: 4,
                      category: 'Grocery & Staples',
                    ),
                  ];

                  final added = await SmartStockReorderService.addAllLowStockToProcurement(
                    context,
                    products,
                    showToast: false,
                  );

                  expect(added, 2);
                  final items = LocalCacheService.getProcurementItems();
                  expect(items.length, 2);

                  // Attempting bulk add again returns 0 new additions
                  final addedAgain = await SmartStockReorderService.addAllLowStockToProcurement(
                    context,
                    products,
                    showToast: false,
                  );
                  expect(addedAgain, 0);
                  expect(LocalCacheService.getProcurementItems().length, 2);
                },
                child: const Text('Add Bulk'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Add Bulk'));
      await tester.pumpAndSettle();
    });

    test('formatSupplierOrderMessage generates clean wholesale orders in English and Hindi', () {
      final products = [
        ProductModel(
          id: '301',
          name: 'Amul Butter 500g',
          price: 275.0,
          costPrice: 250.0,
          stock: 2,
          lowStockThreshold: 5,
          unit: 'pack',
          category: 'Dairy, Bakery & Frozen',
        ),
        ProductModel(
          id: '302',
          name: 'Basmati Rice 5kg',
          price: 490.0,
          costPrice: 440.0,
          stock: 1,
          lowStockThreshold: 3,
          unit: 'bag',
          category: 'Grocery & Staples',
        ),
      ];

      // English
      final enMsg = SmartStockReorderService.formatSupplierOrderMessage(
        products: products,
        shopName: 'ShopSilo Express Mart',
        isHindi: false,
      );
      expect(enMsg, contains('WHOLESALE PURCHASE ORDER'));
      expect(enMsg, contains('Store: *ShopSilo Express Mart*'));
      expect(enMsg, contains('Amul Butter 500g'));
      expect(enMsg, contains('Qty: 10 packs | Est. Rate: ₹250'));
      expect(enMsg, contains('Basmati Rice 5kg'));
      expect(enMsg, contains('Qty: 6 bags | Est. Rate: ₹440'));
      expect(enMsg, contains('Total Items: *2*'));
      expect(enMsg, contains('Est. Total: *₹5140*')); // (10 * 250) + (6 * 440) = 2500 + 2640 = 5140

      // Hindi
      final hiMsg = SmartStockReorderService.formatSupplierOrderMessage(
        products: products,
        shopName: 'दुकान सिलो सुपरमार्ट',
        isHindi: true,
      );
      expect(hiMsg, contains('थोक खरीद ऑर्डर (Wholesale Purchase Order)'));
      expect(hiMsg, contains('दुकान: *दुकान सिलो सुपरमार्ट*'));
      expect(hiMsg, contains('मात्रा: 10 packs | अनुमानित दर: ₹250'));
      expect(hiMsg, contains('कुल वस्तुएं: *2* | अनुमानित कुल: *₹5140*'));
      expect(hiMsg, contains('कृपया इस ऑर्डर की पुष्टि करें'));

      // Strict User Global Rule: Zero Vegetable Imagery or Icons
      expect(enMsg.toLowerCase(), isNot(contains('vegetable')));
      expect(enMsg.toLowerCase(), isNot(contains('mandi')));
      expect(hiMsg, isNot(contains('सब्जी')));
      expect(hiMsg, isNot(contains('मंडी')));
      expect(hiMsg, isNot(contains('🌾')));
    });
  });

  group('LowStockAlertsScreen Widget Tests & Responsiveness', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();
    });

    Widget createTestApp({
      required Size screenSize,
      bool isHindi = false,
      List<ProductModel> products = const [],
    }) {
      final productController = ProductController();
      productController.setProductsForTesting(products);

      final authController = AuthController();
      authController.setShopForTesting(
        ShopModel(
          id: 'shop_1',
          name: isHindi ? 'दुकान सिलो किराना' : 'ShopSilo Superstore',
          slug: 'shopsilo-superstore',
          phone: '9876543210',
          upiId: 'shopsilo@okicici',
        ),
      );

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductController>.value(value: productController),
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<LanguageController>(
            create: (_) {
              final lc = LanguageController();
              if (isHindi) lc.setLanguage(AppLanguage.hindi);
              return lc;
            },
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: const LowStockAlertsScreen(),
          ),
        ),
      );
    }

    testWidgets('renders low stock items, bulk action buttons and quick restock stepper with zero overflow on mobile (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final lowStockList = [
        ProductModel(
          id: 'p1',
          name: 'Fortune Sunlite Sunflower Oil 1L',
          price: 145.0,
          costPrice: 130.0,
          stock: 2,
          lowStockThreshold: 5,
          unit: 'pouch',
          category: 'Grocery & Staples',
        ),
        ProductModel(
          id: 'p2',
          name: 'Parle-G Gold Biscuits 1kg',
          price: 120.0,
          costPrice: 105.0,
          stock: 0,
          lowStockThreshold: 4,
          unit: 'pack',
          category: 'Snacks & Munchies',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(390, 844),
          products: lowStockList,
        ),
      );
      await tester.pumpAndSettle();

      // Verify bulk action buttons render
      expect(find.byIcon(Icons.playlist_add_rounded), findsWidgets);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      // Verify product card and 1-tap Wholesale Reorder buttons render
      expect(find.text('Fortune Sunlite Sunflower Oil 1L'), findsOneWidget);
      expect(find.text('Parle-G Gold Biscuits 1kg'), findsOneWidget);
      expect(find.textContaining('Add to Reorder List'), findsWidgets);

      // Tap 1-tap reorder button on first product
      final reorderButtons = find.textContaining('Add to Reorder List');
      await tester.tap(reorderButtons.first);
      await tester.pumpAndSettle();

      // Verify item was stored in procurement cache
      final procurementItems = LocalCacheService.getProcurementItems();
      expect(procurementItems.any((i) => i.name.contains('Fortune Sunlite')), isTrue);
    });

    testWidgets('renders properly with zero overflow on Desktop viewport (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final lowStockList = [
        ProductModel(
          id: 'p1',
          name: 'Fortune Sunlite Sunflower Oil 1L',
          price: 145.0,
          costPrice: 130.0,
          stock: 2,
          lowStockThreshold: 5,
          unit: 'pouch',
          category: 'Grocery & Staples',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(1280, 800),
          products: lowStockList,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.playlist_add_rounded), findsWidgets);
      expect(find.text('Fortune Sunlite Sunflower Oil 1L'), findsOneWidget);
    });
  });
}
