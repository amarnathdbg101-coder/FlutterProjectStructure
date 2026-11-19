import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/analytics/controllers/analytics_controller.dart';
import 'package:flutter_project_structure/features/analytics/models/analytics_model.dart';
import 'package:flutter_project_structure/features/analytics/screens/analytics_screen.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/screens/today_sales_screen.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profit and Sales Clean & Professional UI/UX Tests', () {
    late PosController pos;
    late AnalyticsController analyticsCtrl;
    late LanguageController langCtrl;
    late AuthController authCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.clearCache();

      // Seed 2 sample sales with product cost prices
      final now = DateTime.now();
      final sale1 = SaleModel(
        billNumber: '1001',
        customerPhone: '9876543210',
        items: [
          PosCartItem(
            product: ProductModel(
              id: 'p1',
              name: 'Basmati Rice 1kg',
              price: 100.0,
              costPrice: 80.0,
              stock: 50,
              category: 'Grocery',
            ),
            quantity: 2,
            customPrice: 100.0,
          ),
        ],
        subtotal: 200.0,
        discountAmount: 0.0,
        totalAmount: 200.0,
        paymentMethod: 'cash',
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      final sale2 = SaleModel(
        billNumber: '1002',
        customerPhone: '9876543211',
        items: [
          PosCartItem(
            product: ProductModel(
              id: 'p2',
              name: 'Mustard Oil 1L',
              price: 150.0,
              costPrice: 120.0,
              stock: 20,
              category: 'Oil',
            ),
            quantity: 1,
            customPrice: 150.0,
          ),
        ],
        subtotal: 150.0,
        discountAmount: 0.0,
        totalAmount: 150.0,
        paymentMethod: 'upi',
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      await LocalCacheService.saveCompletedSale(sale1);
      await LocalCacheService.saveCompletedSale(sale2);

      // Seed analytics model
      final sampleAnalytics = AnalyticsModel(
        totalRevenue: 350.0,
        totalCost: 280.0,
        totalExpenses: 20.0,
        netPocketProfit: 50.0,
        averageMarginPct: 14.3,
        totalSalesCount: 2,
        bestProfitable: [
          AnalyticsProductItem(
            productId: 'p1',
            name: 'Basmati Rice 1kg',
            soldQty: 2,
            currentStock: 48,
            profitAmount: 40.0,
            marginPct: 20.0,
            daysInStock: 5,
          ),
        ],
        deadStock: [
          AnalyticsProductItem(
            productId: 'p9',
            name: 'Old Stock Flour 5kg',
            soldQty: 0,
            currentStock: 12,
            profitAmount: 0.0,
            marginPct: 0.0,
            daysInStock: 45,
          ),
        ],
      );
      await LocalCacheService.saveAnalytics(sampleAnalytics);

      pos = PosController();
      analyticsCtrl = AnalyticsController();
      langCtrl = LanguageController();
      authCtrl = AuthController();
    });

    tearDown(() {
      pos.dispose();
      analyticsCtrl.dispose();
      langCtrl.dispose();
      authCtrl.dispose();
    });

    Widget createTodaySalesWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<PosController>.value(value: pos),
          ChangeNotifierProvider<AnalyticsController>.value(value: analyticsCtrl),
          ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ],
        child: const MaterialApp(
          home: TodaySalesScreen(),
        ),
      );
    }

    Widget createAnalyticsWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AnalyticsController>.value(value: analyticsCtrl),
          ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ],
        child: const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );
    }

    testWidgets('TodaySalesScreen displays unified sales, net profit, and expandable P&L formula', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTodaySalesWidget());
      await tester.pumpAndSettle();

      // 1. Verify Sales and Net Profit Metrics in Hero Card
      expect(find.text('₹350'), findsOneWidget); // Total Sales: 200 + 150 = 350
      expect(find.text('Net Profit'), findsWidgets);
      expect(find.text('Cash: '), findsOneWidget);
      expect(find.text('UPI: '), findsOneWidget);

      // 2. Expand Profit Breakdown details
      final pnlButton = find.text('P&L Details');
      expect(pnlButton, findsOneWidget);
      await tester.tap(pnlButton);
      await tester.pumpAndSettle();

      // Formula lines should be visible
      expect(find.text('SHOP PROFIT & LOSS MATHEMATICS'), findsOneWidget);
      expect(find.text('+ Total Sales Revenue'), findsOneWidget);
      expect(find.text('- Cost of Goods Sold (COGS)'), findsOneWidget);

      // 3. Switch to Bills tab and verify direct 1-tap Share and Print buttons
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();

      expect(find.text('Bill #1002'), findsOneWidget);
      expect(find.text('Bill #1001'), findsOneWidget);
      expect(find.text('Share'), findsNWidgets(2));
      expect(find.text('Print'), findsNWidgets(2));
      expect(find.text('Return'), findsNWidgets(2));
    });

    testWidgets('AnalyticsScreen renders executive clean P&L card and fast action links without gradients', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createAnalyticsWidget());
      await tester.pumpAndSettle();

      // 1. Executive Net Pocket Profit card
      expect(find.text('NET POCKET PROFIT'), findsOneWidget);
      expect(find.text('₹50'), findsNWidgets(2)); // Hero + P&L formula row

      // 2. Breakdown rows
      expect(find.text('FINANCIAL PROFIT BREAKDOWN'), findsOneWidget);
      expect(find.text('+ Total Sales Revenue'), findsOneWidget);
      expect(find.text('- Inventory Cost (COGS)'), findsOneWidget);
      expect(find.text('- Store Daily Expenses'), findsOneWidget);

      // 3. Quick action shortcuts
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);

      // 4. Profitable products & Dead stock
      expect(find.text('TOP PROFITABLE PRODUCTS'), findsOneWidget);
      expect(find.text('Basmati Rice 1kg'), findsOneWidget);
      expect(find.text('DEAD STOCK ALERT'), findsOneWidget);
      expect(find.text('Old Stock Flour 5kg'), findsOneWidget);
    });
  });
}
