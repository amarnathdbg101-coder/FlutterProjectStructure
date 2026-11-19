import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS 10-Day Retention & Time-Sorted Sold Products Tests', () {
    late PosController pos;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.clearCache();
      pos = PosController();
    });

    tearDown(() {
      pos.dispose();
    });

    test('10-day retention keeps recent sales and auto-purges sales older than 10 days', () async {
      final now = DateTime.now();

      final saleToday = SaleModel(
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
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final sale5DaysAgo = SaleModel(
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
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final sale12DaysAgo = SaleModel(
        billNumber: '1003',
        customerPhone: '9876543212',
        items: [
          PosCartItem(
            product: ProductModel(id: 'p3', name: 'Expired Item', price: 50.0, stock: 10, category: 'Grocery'),
            quantity: 1,
            customPrice: 50.0,
          ),
        ],
        subtotal: 50.0,
        discountAmount: 0.0,
        totalAmount: 50.0,
        paymentMethod: 'cash',
        createdAt: now.subtract(const Duration(days: 12)),
      );

      // Save sales
      await LocalCacheService.saveCompletedSale(saleToday);
      await LocalCacheService.saveCompletedSale(sale5DaysAgo);
      await LocalCacheService.saveCompletedSale(sale12DaysAgo);

      // Query 10-day sales
      final retainedSales = LocalCacheService.get10DaySales();
      expect(retainedSales.length, 2);
      expect(retainedSales.map((s) => s.billNumber), containsAll(['1001', '1002']));
      expect(retainedSales.map((s) => s.billNumber), isNot(contains('1003')));

      // Verify sorting newest first
      expect(retainedSales.first.billNumber, '1001');
      expect(retainedSales.last.billNumber, '1002');
    });

    test('getTimeSortedSoldItems returns each individual product sold, strictly sorted newest first', () async {
      final now = DateTime.now();

      final sale1 = SaleModel(
        billNumber: 'BILL-01',
        customerPhone: '9811111111',
        items: [
          PosCartItem(
            product: ProductModel(id: 'p1', name: 'Product Alpha', price: 100.0, stock: 10, category: 'General'),
            quantity: 3,
            customPrice: 100.0,
          ),
        ],
        subtotal: 300.0,
        discountAmount: 0.0,
        totalAmount: 300.0,
        paymentMethod: 'cash',
        createdAt: now.subtract(const Duration(hours: 5)),
      );

      final sale2 = SaleModel(
        billNumber: 'BILL-02',
        customerPhone: '9822222222',
        items: [
          PosCartItem(
            product: ProductModel(id: 'p2', name: 'Product Beta', price: 50.0, stock: 10, category: 'General'),
            quantity: 2,
            customPrice: 50.0,
          ),
          PosCartItem(
            product: ProductModel(id: 'p3', name: 'Product Gamma', price: 25.0, stock: 10, category: 'General'),
            quantity: 4,
            customPrice: 25.0,
          ),
        ],
        subtotal: 200.0,
        discountAmount: 0.0,
        totalAmount: 200.0,
        paymentMethod: 'upi',
        createdAt: now.subtract(const Duration(minutes: 30)),
      );

      await LocalCacheService.saveCompletedSale(sale1);
      await LocalCacheService.saveCompletedSale(sale2);

      final items = pos.getTimeSortedSoldItems();
      expect(items.length, 3);

      // Verify newest first: BILL-02 was 30 mins ago, BILL-01 was 5 hours ago
      expect(items[0].billNumber, 'BILL-02');
      expect(items[1].billNumber, 'BILL-02');
      expect(items[2].billNumber, 'BILL-01');

      expect(items[2].productName, 'Product Alpha');
      expect(items[2].quantity, 3);
      expect(items[2].unitPrice, 100.0);
      expect(items[2].totalPrice, 300.0);
      expect(items[2].paymentMethod, 'cash');
    });
  });
}
