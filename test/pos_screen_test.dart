import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/screens/pos_screen.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PosScreen renders clean minimalist billing terminal with zero overflow in English and Hindi', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    final testProducts = [
      ProductModel(
        id: 'pos-1',
        name: 'Tata Salt Vacuum Evaporated 1kg',
        price: 28.0,
        stock: 50,
        unit: 'pkt',
        category: 'Grocery',
      ),
      ProductModel(
        id: 'pos-2',
        name: 'Amul Taaza Milk 500ml',
        price: 27.0,
        stock: 30,
        unit: 'pouch',
        category: 'Dairy',
      ),
    ];
    await LocalCacheService.saveProducts(testProducts);

    final langCtrl = LanguageController();
    final authCtrl = AuthController();
    final posCtrl = PosController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ChangeNotifierProvider<AuthController>.value(value: authCtrl),
          ChangeNotifierProvider<PosController>.value(value: posCtrl),
        ],
        child: const MaterialApp(
          home: PosScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verify Empty State Terminal is Clean & Minimalist
    expect(find.text('POS Billing Counter'), findsOneWidget);
    expect(find.text('POS Billing Counter Ready'), findsOneWidget);
    expect(find.text('+ Add Loose Charge'), findsOneWidget);

    // 2. Add an item to cart and verify _PosCartItemTile renders cleanly
    posCtrl.addToCart(testProducts[0]);
    await tester.pumpAndSettle();

    expect(find.text('Tata Salt Vacuum Evaporated 1kg'), findsOneWidget);
    expect(find.text('₹28 / pkt'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // quantity
    expect(find.text('₹28'), findsWidgets); // line total & grand total

    // 3. Test 0ms Stepper Increment (without SnackBar queue lag)
    final plusBtn = find.byIcon(Icons.add_rounded);
    expect(plusBtn, findsOneWidget);
    await tester.tap(plusBtn);
    await tester.pumpAndSettle();

    expect(posCtrl.cart.first.quantity, 2);
    expect(find.text('2'), findsOneWidget);
    expect(posCtrl.grandTotal, 56.0);

    // 4. Test Mobile Bottom Checkout Bar
    expect(find.text('Checkout Bill'), findsOneWidget);
    expect(find.text('2 Items in Bill'), findsOneWidget);

    // 5. Switch to Hindi and verify pure localization
    await langCtrl.setLanguage(AppLanguage.hindi);
    await tester.pumpAndSettle();

    expect(find.text('पीओएस बिलिंग काउंटर'), findsOneWidget);
    expect(find.text('2 वस्तुएं बिल में'), findsOneWidget);
    expect(find.text('बिल चेकआउट'), findsOneWidget);
    expect(find.text('वस्तु का नाम'), findsOneWidget);
    expect(find.text('मात्रा'), findsOneWidget);
    expect(find.text('मूल्य (₹)'), findsOneWidget);

    // 6. Test Large Billing Amount with FittedBox to ensure zero overflow
    posCtrl.addCustomItem(name: 'Bulk Rice Wholesale', price: 150000.0, quantity: 1);
    await tester.pumpAndSettle();

    expect(posCtrl.grandTotal, 150056.0);
    // Zero overflow assertions checked by flutter_test automatically

    posCtrl.dispose();
    authCtrl.dispose();
    langCtrl.dispose();
  });

  test('PosController auto-switches active token on QR scan and supports quick unlisted barcode onboarding', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    final posCtrl = PosController();

    // 1. Initial active token is T-01
    expect(posCtrl.currentActiveToken, 'T-01');

    // 2. Scan Floor Token QR code SHOP-TOKEN:T-07
    final switched = await posCtrl.scanAndAddToCart('SHOP-TOKEN:T-07');
    expect(switched, isTrue);
    expect(posCtrl.currentActiveToken, 'T-07');
    expect(posCtrl.lastScannedActionMessage, 'TOKEN:T-07');

    // 3. Quick register brand-new unlisted product on floor
    final registered = await posCtrl.quickRegisterBarcodeAndAddToCart(
      barcode: '8901030383838',
      name: 'Unlisted Floor Biscuit 100g',
      price: 25.0,
      mrp: 30.0,
    );

    expect(registered, isTrue);
    expect(posCtrl.cart.length, 1);
    expect(posCtrl.cart.first.product.name, 'Unlisted Floor Biscuit 100g');
    expect(posCtrl.cart.first.product.barcode, '8901030383838');
    expect(posCtrl.grandTotal, 25.0);

    posCtrl.dispose();
  });
}
