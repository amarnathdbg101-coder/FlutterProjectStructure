import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/analytics/controllers/analytics_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/screens/today_sales_screen.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Check RenderFlex overflow on standard mobile (360x800)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.clearCache();

    // 1080x2408 with ratio 2.75 is logical 392.7 x 875.6
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final sale1 = SaleModel(
      billNumber: '1001',
      customerPhone: '9876543210',
      items: [
        PosCartItem(
          product: ProductModel(id: 'p1', name: 'Tata Salt 1kg Pack Special', price: 28.0, stock: 50, category: 'Grocery'),
          quantity: 2,
          customPrice: 28.0,
        ),
      ],
      subtotal: 56.0,
      discountAmount: 0.0,
      totalAmount: 56.0,
      paymentMethod: 'cash',
      createdAt: now.subtract(const Duration(hours: 1)),
    );

    await LocalCacheService.saveCompletedSale(sale1);

    final pos = PosController();
    final analytics = AnalyticsController();
    final lang = LanguageController();
    final auth = AuthController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pos),
          ChangeNotifierProvider.value(value: analytics),
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: TodaySalesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Bills tab
    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    // Switch to Top Ranking tab
    await tester.tap(find.text('Top Ranking'));
    await tester.pumpAndSettle();

    // Switch to Sold Items tab
    await tester.tap(find.text('Sold Items'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Check RenderFlex overflow on ultra-small mobile (320x640)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.clearCache();

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    final sale1 = SaleModel(
      billNumber: '1001',
      customerPhone: '9876543210',
      items: [
        PosCartItem(
          product: ProductModel(id: 'p1', name: 'Tata Salt 1kg Pack Special', price: 28.0, stock: 50, category: 'Grocery'),
          quantity: 2,
          customPrice: 28.0,
        ),
      ],
      subtotal: 56.0,
      discountAmount: 0.0,
      totalAmount: 56.0,
      paymentMethod: 'cash',
      createdAt: now.subtract(const Duration(hours: 1)),
    );

    await LocalCacheService.saveCompletedSale(sale1);

    final pos = PosController();
    final analytics = AnalyticsController();
    final lang = LanguageController();
    final auth = AuthController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pos),
          ChangeNotifierProvider.value(value: analytics),
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: TodaySalesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Bills tab
    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    // Switch to Top Ranking tab
    await tester.tap(find.text('Top Ranking'));
    await tester.pumpAndSettle();

    // Switch to Sold Items tab
    await tester.tap(find.text('Sold Items'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
  });
}
