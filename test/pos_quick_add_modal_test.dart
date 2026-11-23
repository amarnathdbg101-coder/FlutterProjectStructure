import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/widgets/pos_quick_add_modal.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PosQuickAddModal & Active Cart Margin Engine Tests', () {
    late PosController posCtrl;
    late LanguageController langCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCartDraft();
      posCtrl = PosController();
      langCtrl = LanguageController();
    });

    testWidgets('PosQuickAddModal renders cleanly with speech mic and auto SKU', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<PosController>.value(value: posCtrl),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => PosQuickAddModal.show(
                    context: ctx,
                    pos: posCtrl,
                    initialQuery: 'Maggi Masala 70g',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the Quick Add modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify clean header and fields
      expect(find.text('⚡ Quick Product Registration'), findsOneWidget);
      expect(find.text('Maggi Masala 70g'), findsOneWidget);
      expect(find.text('Auto SKU'), findsOneWidget);

      // Verify speech mic icon is present inside product name field
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Enter selling price 14 and cost price 10
      final sellingPriceField = find.widgetWithText(TextField, 'Selling Price (₹) *');
      final costPriceField = find.widgetWithText(TextField, 'Cost Price (₹)');

      await tester.enterText(sellingPriceField, '14');
      await tester.enterText(costPriceField, '10');
      await tester.pumpAndSettle();

      // Verify live profit margin preview: +₹4.0 (29% margin)
      expect(find.textContaining('Est. Gross Margin: +₹4.0 (29%)'), findsOneWidget);

      // Tap '⚡ Add to Bill & Save (0ms)'
      final addBtn = find.text('⚡ Add to Bill & Save (0ms)');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Modal closed and product was added to active cart
      expect(find.text('⚡ Quick Product Registration'), findsNothing);
      expect(posCtrl.cart.length, 1);
      expect(posCtrl.cart.first.product.name, 'Maggi Masala 70g');
      expect(posCtrl.cart.first.product.price, 14.0);
      expect(posCtrl.cart.first.product.costPrice, 10.0);
      expect(posCtrl.grandTotal, 14.0);
    });

    test('PosController calculates accurate gross profit, margin % and discount loss warning', () {
      final p1 = ProductModel(
        id: 'p-1',
        name: 'Product A',
        price: 100.0,
        costPrice: 70.0,
        stock: 10,
        unit: 'pcs',
        category: 'General',
      );
      final p2 = ProductModel(
        id: 'p-2',
        name: 'Product B',
        price: 50.0,
        costPrice: 30.0,
        stock: 10,
        unit: 'pcs',
        category: 'General',
      );

      posCtrl.addToCart(p1);
      posCtrl.addToCart(p2);

      // Selling total = 100 + 50 = 150
      // Cost total = 70 + 30 = 100
      // Gross Profit = 150 - 100 = 50
      // Margin Pct = (50 / 150) * 100 = 33.33%
      expect(posCtrl.cartCostTotal, 100.0);
      expect(posCtrl.cartGrossProfit, 50.0);
      expect(posCtrl.cartProfitMarginPct.toStringAsFixed(1), '33.3');
      expect(posCtrl.isDiscountLossWarning, isFalse);

      // Cashier applies discount of ₹30 (still within profit of 50)
      posCtrl.setDiscount(30.0);
      expect(posCtrl.grandTotal, 120.0);
      expect(posCtrl.isDiscountLossWarning, isFalse);

      // Cashier applies discount of ₹55 (exceeds gross profit of 50 -> Loss warning!)
      posCtrl.setDiscount(55.0);
      expect(posCtrl.grandTotal, 95.0);
      expect(posCtrl.isDiscountLossWarning, isTrue);
    });
  });
}
