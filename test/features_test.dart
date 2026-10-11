import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/theme/app_theme.dart';
import 'package:flutter_project_structure/core/utils/date_time_utils.dart';
import 'package:flutter_project_structure/core/localization/app_translations.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

import 'package:flutter_project_structure/features/khata/repositories/khata_repository.dart';
import 'package:flutter_project_structure/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('1. Localization & Language System Tests', () {
    test('Translations returns valid English and Hindi strings for critical keys', () {
      expect(AppTranslations.get('login_title', AppLanguage.english), isNotEmpty);
      expect(AppTranslations.get('login_title', AppLanguage.hindi), isNotEmpty);
      expect(AppTranslations.get('khata_add_btn', AppLanguage.english), 'Record Entry');
      expect(AppTranslations.get('khata_add_btn', AppLanguage.hindi), 'प्रविष्टि दर्ज करें');
      expect(AppTranslations.get('pos_title', AppLanguage.english), 'POS Counter Billing');
      expect(AppTranslations.get('inv_title', AppLanguage.english), 'Active Products');
    });

    test('Validation messages are properly localized', () {
      expect(AppTranslations.get('inv_val_name', AppLanguage.english), 'Please enter product name');
      expect(AppTranslations.get('inv_val_name', AppLanguage.hindi), 'कृपया उत्पाद का नाम दर्ज करें');
      expect(AppTranslations.get('pos_val_price', AppLanguage.english), 'Please enter a valid price');
      expect(AppTranslations.get('exp_val_amount', AppLanguage.english), 'Please enter a valid expense amount');
    });
  });

  group('2. Khata (Credit) Model & Calculation Tests', () {
    test('KhataCustomerModel equality and hashCode are consistent', () {
      final customer1 = KhataCustomerModel(
        id: 'cust_123',
        name: 'Ramesh Kumar',
        mobile: '9876543210',
        balance: 1500.0,
      );

      final customer2 = KhataCustomerModel(
        id: 'cust_123',
        name: 'Ramesh Kumar',
        mobile: '9876543210',
        balance: 1500.0,
      );

      expect(customer1, equals(customer2));
      expect(customer1.hashCode, equals(customer2.hashCode));
      expect(customer1.hasPendingUdhar, isTrue);
      expect(customer1.isSettled, isFalse);
    });

    test('KhataCustomerModel credit utilization calculation is bounded 0-100%', () {
      final customer = KhataCustomerModel(
        id: 'cust_1',
        name: 'Suresh',
        mobile: '9876543211',
        balance: 5000.0,
        creditLimit: 10000.0,
      );

      expect(customer.creditUtilizationPercent, equals(50.0));

      final overLimitCustomer = KhataCustomerModel(
        id: 'cust_2',
        name: 'Mahesh',
        mobile: '9876543212',
        balance: 15000.0,
        creditLimit: 10000.0,
      );

      expect(overLimitCustomer.creditUtilizationPercent, equals(100.0));
    });
  });

  group('3. POS (Billing) Calculations & Cart Lifecycle Tests', () {
    test('Adding and removing products calculates correct subtotal and grandTotal', () {
      final pos = PosController();
      final p1 = ProductModel(id: '1', name: 'Tata Tea 500g', price: 250.0, stock: 10, category: 'Grocery');
      final p2 = ProductModel(id: '2', name: 'Aashirvaad Atta 5kg', price: 320.0, stock: 5, category: 'Grocery');

      pos.addToCart(p1, quantity: 2); // 250 * 2 = 500
      pos.addToCart(p2, quantity: 1); // 320 * 1 = 320

      expect(pos.cart.length, 2);
      expect(pos.totalItemCount, 3);
      expect(pos.subtotal, 820.0);
      expect(pos.grandTotal, 820.0);

      // Apply discount
      pos.setDiscount(70.0);
      expect(pos.grandTotal, 750.0);

      // Cash tendered & change calculation
      pos.setPaymentMethod('cash');
      pos.setCashTendered(1000.0);
      expect(pos.changeDue, 250.0);

      // Decrement item
      pos.decrementQuantity(pos.cart.first);
      expect(pos.totalItemCount, 2);
      expect(pos.subtotal, 570.0);

      // Clear cart
      pos.clearCart();
      expect(pos.cart.isEmpty, isTrue);
      expect(pos.grandTotal, 0.0);
      expect(pos.discount, 0.0);
    });

    test('Custom unlisted item can be added dynamically', () {
      final pos = PosController();
      pos.addCustomItem(name: 'Carry Bag Large', price: 15.0, quantity: 2);

      expect(pos.cart.length, 1);
      expect(pos.subtotal, 30.0);
      expect(pos.grandTotal, 30.0);
      expect(pos.cart.first.product.name, 'Carry Bag Large');
    });
  });

  group('4. Product Catalog Integrity Tests', () {
    test('ProductModel JSON serialization and deserialization integrity', () {
      final json = {
        'id': 'prod_99',
        'name': 'Fortune Sunflower Oil 1L',
        'price': 145.0,
        'cost_price': 120.0,
        'compare_price': 165.0,
        'stock': 24,
        'unit': 'litre',
        'category': 'Cooking Oils',
        'is_active': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, 'prod_99');
      expect(product.name, 'Fortune Sunflower Oil 1L');
      expect(product.price, 145.0);
      expect(product.costPrice, 120.0);
      expect(product.comparePrice, 165.0);
      expect(product.stock, 24);
      expect(product.unit, 'litre');

      final serialized = product.toJson();
      expect(serialized['name'], 'Fortune Sunflower Oil 1L');
      expect(serialized['price'], 145.0);
    });
  });

  group('5. Today\'s Sales (24-Hour) Integrity Tests', () {
    test('Translations returns valid English and Hindi strings for today sales keys', () {
      expect(AppTranslations.get('today_sales_title', AppLanguage.english), isNotEmpty);
      expect(AppTranslations.get('today_sales_title', AppLanguage.hindi), isNotEmpty);
      expect(AppTranslations.get('today_sales_total_rev', AppLanguage.english), 'Total Revenue');
      expect(AppTranslations.get('today_sales_total_rev', AppLanguage.hindi), 'कुल बिक्री');
    });

    test('SaleModel JSON serialization and deserialization integrity', () {
      final saleJson = {
        'bill_number': '1005',
        'customer_phone': '9876543210',
        'items': [
          {
            'product_id': 'p1',
            'name': 'Aashirvaad Atta 5kg',
            'quantity': 2,
            'custom_price': 250.0,
          }
        ],
        'subtotal': 500.0,
        'discount_amount': 20.0,
        'total_amount': 480.0,
        'payment_method': 'cash',
        'created_at': DateTime.now().toIso8601String(),
      };

      final sale = SaleModel.fromJson(saleJson);
      expect(sale.billNumber, '1005');
      expect(sale.totalAmount, 480.0);
      expect(sale.items.length, 1);
      expect(sale.items.first.product.name, 'Aashirvaad Atta 5kg');
      expect(sale.items.first.quantity, 2);
    });
  });

  group('6. Khata Phone Normalization Tests', () {
    test('normalizePhone cleans +91, 0, and non-digits to 10 digits', () {
      expect(KhataRepository.normalizePhone('+919876543210'), '9876543210');
      expect(KhataRepository.normalizePhone('09876543210'), '9876543210');
      expect(KhataRepository.normalizePhone('98765-43210'), '9876543210');
      expect(KhataRepository.normalizePhone('9876543210'), '9876543210');
      expect(KhataRepository.normalizePhone('12345'), '12345');
    });
  });

  group('7. Route & Screen State Persistence Tests', () {
    test('TokenStorage correctly saves and retrieves active screen routes', () async {
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.init();

      await TokenStorage.saveLastRoute('/merchant/pos');
      expect(TokenStorage.getLastRoute(), '/merchant/pos');

      await TokenStorage.saveActiveTabIndex(1);
      expect(TokenStorage.getActiveTabIndex(), 1);

      await TokenStorage.saveLastRoute('/merchant/inventory');
      expect(TokenStorage.getLastRoute(), '/merchant/inventory');

      // Ephemeral auth/splash routes are safely ignored
      await TokenStorage.saveLastRoute('/login');
      expect(TokenStorage.getLastRoute(), '/merchant/inventory');

      await TokenStorage.clearSession();
      expect(TokenStorage.getLastRoute(), isNull);
      expect(TokenStorage.getActiveTabIndex(), 0);
    });
  });

  group('8. App Theme & Button Layout Integrity Tests', () {
    testWidgets('ElevatedButton inside Row layouts with bounded width and zero assertions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: Row(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Test Button'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Test Button'), findsOneWidget);
    });
  });

  group('9. Date & Time Engine Integrity Tests', () {
    test('AppDateTimeUtils converts UTC timestamps to local device time', () {
      final local = AppDateTimeUtils.parseToLocal('2026-10-11T04:30:00Z');
      expect(local.isUtc, isFalse);
      expect(AppDateTimeUtils.formatTime(local), isNotEmpty);
      expect(AppDateTimeUtils.formatDateTime(local), isNotEmpty);
    });

    test('AppDateTimeUtils handles timestamps without Z as UTC correctly', () {
      final local = AppDateTimeUtils.parseToLocal('2026-10-11 04:30:00');
      expect(local.isUtc, isFalse);
    });

    test('AppDateTimeUtils computes remaining hold time correctly', () {
      final future = DateTime.now().add(const Duration(minutes: 45));
      expect(AppDateTimeUtils.formatTimeRemaining(future), contains('mins left'));

      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(AppDateTimeUtils.formatTimeRemaining(past), 'Expired');
    });
  });
}

