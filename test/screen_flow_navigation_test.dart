import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/widgets/merchant_shell.dart';
import 'package:flutter_project_structure/core/widgets/merchant_drawer.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductController productCtrl;
  late PosController posCtrl;
  late AuthController authCtrl;
  late LanguageController langCtrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    productCtrl = ProductController();
    posCtrl = PosController();
    authCtrl = AuthController();
    authCtrl.setShopForTesting(
      ShopModel(
        id: 'shop-1',
        name: 'ShopSilo Supermarket',
        slug: 'shopsilo-supermarket',
        phone: '9876543210',
      ),
    );
    langCtrl = LanguageController();
  });

  Widget buildTestApp({required Widget child}) {
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

  group('Professional Screen Flow & Navigation Tests', () {
    testWidgets('MerchantShell renders bottom navigation bar for root tabs', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const MerchantShell(
            currentIndex: 0,
            showBottomNav: true,
            child: Text('Dashboard Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Content'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('MerchantShell hides bottom navigation bar for secondary screens', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const MerchantShell(
            currentIndex: -1,
            showBottomNav: false,
            child: Text('Secondary Detail Screen'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Secondary Detail Screen'), findsOneWidget);
      // Bottom navigation bar must NOT be present on detail screens
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('MerchantDrawer contains complete list of primary tabs and feature screens', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            drawer: const MerchantDrawer(),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify essential business tiles are all present
      expect(find.text('Discounts & Promotions'), findsOneWidget);
      expect(find.text('Business Reports & Analytics'), findsOneWidget);
      expect(find.text('Purchase & Procurement'), findsOneWidget);
      expect(find.text('Store Pickup Orders'), findsOneWidget);
    });
  });
}

