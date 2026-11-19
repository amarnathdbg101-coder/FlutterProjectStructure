import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/screens/today_sales_screen.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodaySalesScreen Clean UI/UX Tests', () {
    late PosController pos;
    late LanguageController langCtrl;
    late AuthController authCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.clearCache();

      // Seed 2 sample sales
      final now = DateTime.now();
      final sale1 = SaleModel(
        billNumber: '1001',
        customerPhone: '9876543210',
        items: [
          PosCartItem(
            product: ProductModel(id: 'p1', name: 'Tata Salt 1kg', price: 28.0, stock: 50, category: 'Grocery'),
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

      final sale2 = SaleModel(
        billNumber: '1002',
        customerPhone: '9876543211',
        items: [
          PosCartItem(
            product: ProductModel(id: 'p2', name: 'Fortune Oil 1L', price: 145.0, stock: 20, category: 'Oil'),
            quantity: 1,
            customPrice: 145.0,
          ),
        ],
        subtotal: 145.0,
        discountAmount: 0.0,
        totalAmount: 145.0,
        paymentMethod: 'upi',
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      await LocalCacheService.saveCompletedSale(sale1);
      await LocalCacheService.saveCompletedSale(sale2);

      pos = PosController();
      langCtrl = LanguageController();
      authCtrl = AuthController();
    });

    tearDown(() {
      pos.dispose();
      langCtrl.dispose();
      authCtrl.dispose();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<PosController>.value(value: pos),
          ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ],
        child: const MaterialApp(
          home: TodaySalesScreen(),
        ),
      );
    }

    testWidgets('renders executive hero card, 3-tab segmented switch, and time-sorted items', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1. Verify Executive Hero Card
      expect(find.text('₹201'), findsOneWidget); // 56 + 145 = 201
      expect(find.text('Cash: '), findsOneWidget);
      expect(find.text('UPI: '), findsOneWidget);

      // 2. Verify 3-Tab Segmented Switcher
      expect(find.text('Sold Items'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Top Ranking'), findsOneWidget);

      // 3. Verify Sold Items Tab lists the products
      expect(find.text('Fortune Oil 1L'), findsOneWidget);
      expect(find.text('Tata Salt 1kg'), findsOneWidget);

      // 4. Switch to Bills tab
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();

      expect(find.text('Bill #1002'), findsOneWidget);
      expect(find.text('Bill #1001'), findsOneWidget);

      // 5. Test search filter
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, '1001');
      await tester.pumpAndSettle();

      // Only Bill 1001 should be visible
      expect(find.text('Bill #1001'), findsOneWidget);
      expect(find.text('Bill #1002'), findsNothing);
    });
  });
}
