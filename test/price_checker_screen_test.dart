import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/screens/price_checker_screen.dart';
import 'package:flutter_project_structure/features/dashboard/widgets/dashboard_price_checker_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductController productCtrl;
  late PosController posCtrl;
  late AuthController authCtrl;
  late LanguageController langCtrl;
  late List<ProductModel> testProducts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    testProducts = [
      ProductModel(
        id: 'p-1',
        name: 'Fortune Sunlite Sunflower Oil 1L',
        barcode: '8906007281014',
        sku: 'OIL-FORT-1L',
        price: 145.0,
        comparePrice: 175.0,
        costPrice: 125.0,
        stock: 30,
        unit: '1L',
        category: 'Edible Oils',
      ),
      ProductModel(
        id: 'p-2',
        name: 'Aashirvaad Shudh Chakki Atta 5kg',
        barcode: '8901030383742',
        sku: 'AASH-ATTA-5KG',
        price: 240.0,
        comparePrice: 280.0,
        costPrice: 210.0,
        stock: 12,
        unit: '5kg',
        category: 'Flour & Grains',
      ),
    ];

    productCtrl = ProductController();
    productCtrl.setProductsForTesting(testProducts);

    posCtrl = PosController();
    authCtrl = AuthController();
    authCtrl.setShopForTesting(
      ShopModel(
        id: 'shop-1',
        name: 'ShopSilo Mart',
        slug: 'shopsilo-mart',
        phone: '9876543210',
      ),
    );
    langCtrl = LanguageController();
  });

  Widget buildTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductController>.value(value: productCtrl),
        ChangeNotifierProvider<PosController>.value(value: posCtrl),
        ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Instant Price Checker Tests', () {
    testWidgets('DashboardPriceCheckerCard renders title and opens the checker', (tester) async {
      await tester.pumpWidget(buildTestWidget(const DashboardPriceCheckerCard()));
      await tester.pumpAndSettle();

      expect(find.text('Instant Price & Stock Checker'), findsOneWidget);
      expect(find.text('FAST'), findsOneWidget);
      expect(find.byIcon(Icons.price_check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    });

    testWidgets('PriceCheckerScreen renders search bar, filters and finds product by barcode', (tester) async {
      await tester.pumpWidget(buildTestWidget(const PriceCheckerScreen()));
      await tester.pumpAndSettle();

      // Verify search field is displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Scan barcode'), findsOneWidget);

      // Verify initial guide card is displayed
      expect(find.text('Instant Counter Price Lookup'), findsOneWidget);

      // Enter Barcode in Search Field
      await tester.enterText(find.byType(TextField), '8906007281014');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify Hero card is rendered with product details
      expect(find.text('Fortune Sunlite Sunflower Oil 1L'), findsOneWidget);
      expect(find.text('₹145'), findsOneWidget);
      expect(find.text('MRP: ₹175'), findsOneWidget);
      expect(find.text('✓ In Stock: 30'), findsOneWidget);

      // Tap Privacy Shield to toggle Wholesale Margin
      expect(find.textContaining('Cost: ₹125'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Wholesale margin hidden'), findsOneWidget);

      // Add to POS Cart
      await tester.tap(find.text('Add to POS Cart'));
      await tester.pumpAndSettle();

      expect(posCtrl.cart.length, 1);
      expect(posCtrl.cart.first.product.name, 'Fortune Sunlite Sunflower Oil 1L');
    });

    testWidgets('PriceCheckerScreen auto-lookups with initialBarcode parameter', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const PriceCheckerScreen(initialBarcode: '8901030383742'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify exact product resolved instantly
      expect(find.text('Aashirvaad Shudh Chakki Atta 5kg'), findsOneWidget);
      expect(find.text('₹240'), findsOneWidget);
      expect(find.text('MRP: ₹280'), findsOneWidget);
    });
  });
}
