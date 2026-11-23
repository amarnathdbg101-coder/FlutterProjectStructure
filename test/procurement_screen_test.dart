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
      expect(
        find.descendant(of: find.byType(FloatingActionButton), matching: find.text('Add Sourcing Item')),
        findsOneWidget,
      );

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
      expect(find.text('₹2400'), findsOneWidget); // Item unit rate
      expect(find.text('₹24000'), findsOneWidget); // Header total budget (10 bags * ₹2400)
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

    testWidgets('instant search filters items and shows dealer actions and color dot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await LocalCacheService.saveProcurementItems([
        ProcurementItemModel(
          id: 'item_textile',
          name: 'Cotton Petticoat - Sugapankhi',
          qty: '24 पीस (Pcs)',
          category: 'Clothing & Fashion',
          estimatedPrice: 3600,
          dealerName: 'Gupta Wholesalers',
          dealerPhone: '9876543210',
          notes: 'Shade: Sugapankhi (सुगापंखी)',
        ),
        ProcurementItemModel(
          id: 'item_grocery',
          name: 'Tata Salt 1kg Pouch',
          qty: '1 कार्टन (Carton)',
          category: 'Grocery & Staples',
          estimatedPrice: 650,
        ),
      ]);

      procCtrl = ProcurementController();

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify both items rendered
      expect(find.text('Cotton Petticoat - Sugapankhi'), findsOneWidget);
      expect(find.text('Tata Salt 1kg Pouch'), findsOneWidget);

      // Verify dealer actions & supplier badge present for item with phone
      expect(find.text('Gupta Wholesalers'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // Verify search field exists
      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);

      // Search for 'petticoat'
      await tester.enterText(searchFieldFinder, 'petticoat');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Petticoat should remain, Tata Salt filtered out
      expect(find.text('Cotton Petticoat - Sugapankhi'), findsOneWidget);
      expect(find.text('Tata Salt 1kg Pouch'), findsNothing);

      // Search for nonexistent item
      await tester.enterText(searchFieldFinder, 'Maggi Noodles');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No matching items'), findsOneWidget);
    });

    testWidgets('displays interactive supplier badge and opens quick supplier change sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await LocalCacheService.saveProcurementItems([
        ProcurementItemModel(
          id: 'item_supplier_demo',
          name: 'Fortune Basmati Rice',
          qty: '5 बोरी (Bags)',
          category: 'Grocery & Staples',
          estimatedPrice: 3200,
          dealerName: 'Shyam Traders',
          dealerPhone: '9876500000',
        ),
      ]);

      procCtrl = ProcurementController();

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify supplier badge is rendered
      expect(find.text('Shyam Traders'), findsOneWidget);

      // Tap supplier badge to open quick change sheet
      await tester.tap(find.text('Shyam Traders'));
      await tester.pumpAndSettle();

      // Verify quick supplier change sheet appears
      expect(find.text('Change Supplier & Best Rate'), findsOneWidget);
      expect(find.text('Fortune Basmati Rice'), findsNWidgets(2)); // Card & sheet header
      expect(find.byType(ElevatedButton), findsOneWidget); // Submit button
    });

    test('ProcurementItemModel accurately calculates line total budget = qty * rate', () {
      final item1 = ProcurementItemModel(
        id: 'p1',
        name: 'Mustard Oil Tin',
        qty: '10 Tin',
        estimatedPrice: 1500,
      );
      expect(item1.numericQty, 10.0);
      expect(item1.estimatedPrice, 1500.0);
      expect(item1.itemEstimatedCost, 15000.0); // 10 * 1500 = 15000, NOT 1500!

      final item2 = ProcurementItemModel(
        id: 'p2',
        name: 'Sugar Bag',
        qty: '25.5 kg',
        estimatedPrice: 40,
      );
      expect(item2.numericQty, 25.5);
      expect(item2.itemEstimatedCost, 1020.0); // 25.5 * 40 = 1020
    });
  });
}
