import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/products/controllers/product_controller.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/screens/inventory_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('InventoryScreen renders clean product cards with zero overflow and fast search filtering', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    final List<ProductModel> testProducts = [
      ProductModel(
        id: 'p-1',
        name: 'Basmati Rice Premium 5kg',
        price: 450.0,
        comparePrice: 500.0,
        stock: 25,
        unit: 'kg',
        category: 'Grocery & Staples',
        attributes: {'brand': 'Daawat'},
        sku: 'RICE-001',
        barcode: '8901234567890',
        images: const [],
      ),
      ProductModel(
        id: 'p-2',
        name: 'Mustard Oil Pure 1L',
        price: 160.0,
        comparePrice: 160.0,
        stock: 2, // low stock
        lowStockThreshold: 5,
        unit: 'L',
        category: 'Oils & Ghee',
        attributes: {'brand': 'Fortune'},
        sku: 'OIL-002',
        barcode: '8909876543210',
        images: const [],
      ),
      ProductModel(
        id: 'p-3',
        name: 'Organic Honey 500g',
        price: 220.0,
        comparePrice: 250.0,
        stock: 0, // out of stock
        unit: 'jar',
        category: 'General Store',
        attributes: {'brand': 'Dabur'},
        sku: 'HONEY-003',
        barcode: '8905556667770',
        images: const [],
      ),
    ];

    await LocalCacheService.saveProducts(testProducts);

    final languageCtrl = LanguageController();
    final prodCtrl = ProductController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
          ChangeNotifierProvider<ProductController>.value(value: prodCtrl),
        ],
        child: const MaterialApp(
          home: InventoryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify all products are visible in catalog
    expect(find.text('Basmati Rice Premium 5kg'), findsOneWidget);
    expect(find.text('Mustard Oil Pure 1L'), findsOneWidget);
    expect(find.text('Organic Honey 500g'), findsOneWidget);

    // Verify price
    expect(find.text('₹450'), findsOneWidget);

    // Test Fast in-memory search
    final searchInput = find.byType(TextField).first;
    await tester.enterText(searchInput, 'Rice');
    await tester.pumpAndSettle();

    expect(find.text('Basmati Rice Premium 5kg'), findsOneWidget);
    expect(find.text('Mustard Oil Pure 1L'), findsNothing);
    expect(find.text('Organic Honey 500g'), findsNothing);

    // Clear search
    await tester.enterText(searchInput, '');
    await tester.pumpAndSettle();

    expect(find.text('Basmati Rice Premium 5kg'), findsOneWidget);
    expect(find.text('Mustard Oil Pure 1L'), findsOneWidget);
  });
}
