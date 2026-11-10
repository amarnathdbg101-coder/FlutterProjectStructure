import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
import 'package:flutter_project_structure/features/procurement/controllers/procurement_controller.dart';
import 'package:flutter_project_structure/features/procurement/models/procurement_model.dart';
import 'package:flutter_project_structure/features/procurement/screens/procurement_list_screen.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProcurementController procCtrl;
  late ProductController prodCtrl;
  late AuthController authCtrl;
  late LanguageController langCtrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    procCtrl = ProcurementController();
    prodCtrl = ProductController();
    authCtrl = AuthController();
    authCtrl.setShopForTesting(
      ShopModel(
        id: 'shop-1',
        name: 'Mandi Super Store',
        slug: 'mandi-super-store',
        phone: '9876543210',
      ),
    );
    langCtrl = LanguageController();
  });

  Widget buildTestScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProcurementController>.value(value: procCtrl),
        ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
        ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
      ],
      child: const MaterialApp(
        home: ProcurementListScreen(),
      ),
    );
  }

  group('ProcurementListScreen Clean Architecture & UI Tests', () {
    testWidgets('renders empty state cleanly with FAB and summary banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify FAB is present
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Verify summary banner shows 0 items
      expect(find.text('0 Items'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);

      // Verify empty state is displayed
      expect(find.text('Sourcing list is empty'), findsOneWidget);
    });

    testWidgets('renders structured items with unit and rate cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      // Pre-seed cached items
      await LocalCacheService.saveProcurementItems([
        ProcurementItemModel(
          id: 'item_1',
          name: 'Sharbati Wheat',
          qty: '10 बोरी (Bags)',
          category: 'Grocery & Staples',
          estimatedPrice: 2400,
          dealerName: 'Kisan Trading Co.',
        ),
      ]);

      procCtrl = ProcurementController();

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify item card appears with structured badges
      expect(find.text('Sharbati Wheat'), findsOneWidget);
      expect(find.text('10 बोरी (Bags)'), findsOneWidget);
      expect(find.text('₹2400'), findsNWidgets(2)); // Item price & header total budget
      expect(find.text('1 Items'), findsOneWidget);
      expect(find.text('1 Pending'), findsOneWidget);
      expect(find.text('0 Bought'), findsOneWidget);
    });

    testWidgets('toggles item completion with checkbox without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await LocalCacheService.saveProcurementItems([
        ProcurementItemModel(
          id: 'item_2',
          name: 'Mustard Oil 15L Tin',
          qty: '5 टिन / केन (Tin)',
          category: 'Grocery & Staples',
          estimatedPrice: 1850,
          isCompleted: false,
        ),
      ]);

      procCtrl = ProcurementController();

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Check initially pending
      expect(find.text('1 Pending'), findsOneWidget);
      expect(find.text('0 Bought'), findsOneWidget);

      // Tap checkbox to mark as bought
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Now marked as bought
      expect(find.text('0 Pending'), findsOneWidget);
      expect(find.text('1 Bought'), findsOneWidget);
    });
  });
}
