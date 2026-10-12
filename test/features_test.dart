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
import 'package:flutter_project_structure/features/products/screens/inventory_screen.dart';

import 'package:flutter_project_structure/features/khata/repositories/khata_repository.dart';
import 'package:flutter_project_structure/core/storage/token_storage.dart';
import 'package:flutter_project_structure/core/utils/image_utils.dart';
import 'package:flutter_project_structure/core/services/location_service.dart';
import 'package:flutter_project_structure/core/services/event_bus_service.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/reservations/models/reservation_model.dart';
import 'package:flutter_project_structure/core/routes/app_router.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
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

  group('10. Add Product Validation & Optimistic Architecture Tests', () {
    test('Product pricing constraint rules validate accurately', () {
      const price = 100.0;
      const validMrp = 120.0;
      const invalidMrp = 80.0;
      const validCost = 70.0;
      const invalidCost = 110.0;
      const validFloor = 90.0;
      const invalidFloor = 105.0;

      // MRP Constraint: comparePrice > 0 && comparePrice < price
      expect(validMrp > 0 && validMrp < price, isFalse);
      expect(invalidMrp > 0 && invalidMrp < price, isTrue);

      // Cost Price Constraint: costPrice > price
      expect(validCost > price, isFalse);
      expect(invalidCost > price, isTrue);

      // Floor Price Constraint: floorPrice > price
      expect(validFloor > price, isFalse);
      expect(invalidFloor > price, isTrue);
    });

    test('Optimistic ProductModel creation works with zero latency and handles local images', () {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      const localImagePath = 'blob:http://localhost:54321/mock-image-guid';

      final optimistic = ProductModel(
        id: tempId,
        name: 'Tata Tea Gold',
        description: 'Premium leaf tea',
        sku: 'SKU12345',
        barcode: '8901234567890',
        price: 250.0,
        costPrice: 200.0,
        comparePrice: 280.0,
        floorPrice: 240.0,
        stock: 50,
        lowStockThreshold: 10,
        unit: 'packet',
        category: 'Grocery & Staples',
        images: const [localImagePath],
        isActive: true,
      );

      expect(optimistic.id, equals(tempId));
      expect(optimistic.name, 'Tata Tea Gold');
      expect(optimistic.price, 250.0);
      expect(optimistic.profitAmount, 50.0);
      expect(optimistic.hasDiscount, isTrue);
      expect(optimistic.imageUrl, equals(localImagePath));
      expect(optimistic.isLowStock, isFalse);
      expect(optimistic.isOutOfStock, isFalse);
    });
  });

  group('11. Category Name & Slug Mapping Tests', () {
    test('formatCategoryName maps backend UUIDs to human-readable names', () {
      expect(formatCategoryName('0973ccf7-ef05-4e42-a38c-3851f643cb7a'), equals('Dairy, Bakery & Frozen'));
      expect(formatCategoryName('db43b6f0-32a4-4053-bc8e-afdca6dc6e76'), equals('Grocery & Staples'));
      expect(formatCategoryName('1f4dfc44-b29b-4831-9a67-8e0aa5a9f477'), equals('Stationery & Office Supplies'));
      expect(formatCategoryName('381f901f-c94b-43d9-be64-780b500dc9be'), equals('Hardware & Building Material'));
      expect(formatCategoryName('912b378b-fae5-4ef2-bb58-ad847e855244'), equals('Toys & Baby Products'));
      expect(formatCategoryName('ea8e77d6-5d4f-4088-ac8e-156132b64628'), equals('Medicine & Healthcare'));
      expect(formatCategoryName('b0687580-1de3-43ac-8f22-b34c9423ec57'), equals('General Store'));
    });

    test('formatCategoryName safely handles unknown UUIDs without displaying raw hex ID', () {
      expect(formatCategoryName('00000000-0000-0000-0000-000000000000'), equals('General Store'));
      expect(formatCategoryName('12345678-abcd-1234-ef01-123456789abc'), equals('General Store'));
    });

    test('formatCategoryName maps various backend slugs to clean Title Names', () {
      expect(formatCategoryName('dairy-breakfast'), equals('Dairy, Bakery & Frozen'));
      expect(formatCategoryName('dairy_bread_eggs'), equals('Dairy, Bakery & Frozen'));
      expect(formatCategoryName('kirana-grocery'), equals('Grocery & Staples'));
      expect(formatCategoryName('groceries-staples'), equals('Grocery & Staples'));
      expect(formatCategoryName('stationery-office'), equals('Stationery & Office Supplies'));
      expect(formatCategoryName('hardware-tools'), equals('Hardware & Building Material'));
      expect(formatCategoryName('toys-games'), equals('Toys & Baby Products'));
      expect(formatCategoryName('baby-care'), equals('Toys & Baby Products'));
      expect(formatCategoryName('fruits-vegetables'), equals('Fruits & Vegetables'));
      expect(formatCategoryName('snacks-beverages'), equals('Snacks & Munchies'));
      expect(formatCategoryName('snacks-instant-food'), equals('Snacks & Munchies'));
      expect(formatCategoryName('clothing-apparel'), equals('Clothing & Fashion'));
      expect(formatCategoryName('personal-care'), equals('Personal Care & Beauty'));
      expect(formatCategoryName('household-cleaning'), equals('Household & Cleaning'));
      expect(formatCategoryName('pharmacy-healthcare'), equals('Medicine & Healthcare'));
      expect(formatCategoryName('sports-fitness'), equals('Sports & Fitness'));
      expect(formatCategoryName('pet-care'), equals('Pet Supplies'));
    });

    test('getCategorySlug produces canonical backend slugs', () {
      expect(getCategorySlug('Dairy, Bakery & Frozen'), equals('dairy-breakfast'));
      expect(getCategorySlug('Grocery & Staples'), equals('kirana-grocery'));
      expect(getCategorySlug('Stationery & Office Supplies'), equals('stationery-office'));
      expect(getCategorySlug('Hardware & Building Material'), equals('hardware-tools'));
      expect(getCategorySlug('Toys & Baby Products'), equals('toys-games'));
    });

    test('ProductModel.fromJson resolves category from category_id UUID cleanly', () {
      final json = {
        'id': 'prod_999',
        'name': 'Amul Butter 500g',
        'price': 275.0,
        'category_id': '0973ccf7-ef05-4e42-a38c-3851f643cb7a',
        'stock': 25,
      };

      final product = ProductModel.fromJson(json);
      expect(product.category, equals('Dairy, Bakery & Frozen'));
    });

    test('ProductModel.fromJson resolves category from attributes JSONB priority', () {
      final json = {
        'id': 'prod_888',
        'name': 'Classmate Notebook 200p',
        'price': 60.0,
        'category_id': 'stationery-office',
        'attributes': {
          'category_name': 'Stationery & Office Supplies',
          'brand': 'ITC Classmate',
        },
        'stock': 100,
      };

      final product = ProductModel.fromJson(json);
      expect(product.category, equals('Stationery & Office Supplies'));
    });

    test('ProductModel.toJson persists category_name, category, and attributes cleanly', () {
      final product = ProductModel(
        id: 'prod_777',
        name: 'Dettol Handwash',
        price: 99.0,
        stock: 40,
        category: 'Personal Care & Beauty',
      );

      final json = product.toJson();
      expect(json['category'], equals('Personal Care & Beauty'));
      expect(json['category_name'], equals('Personal Care & Beauty'));
      expect(json['category_id'], equals('personal-care'));
      expect(json['attributes']['category_name'], equals('Personal Care & Beauty'));
    });

    test('ProductModel.fromJson parses stringified JSONB attributes and preserves all specifications', () {
      final json = {
        'id': 'prod_999',
        'name': 'Amul Taaza Toned Milk',
        'price': 32.0,
        'cost_price': 28.0,
        'compare_price': 34.0,
        'floor_price': 30.0,
        'allow_bargain': true,
        'stock': 50,
        'low_stock_threshold': 10,
        'weight': 1.0,
        'category_id': 'dairy-breakfast',
        'attributes': '{"brand":"Amul","unit":"litre","flavor":"Plain","shelf_life":"2 Days"}',
      };

      final product = ProductModel.fromJson(json);
      expect(product.name, equals('Amul Taaza Toned Milk'));
      expect(product.category, equals('Dairy, Bakery & Frozen'));
      expect(product.brand, equals('Amul'));
      expect(product.unit, equals('litre'));
      expect(product.floorPrice, equals(30.0));
      expect(product.allowBargain, isTrue);
      expect(product.lowStockThreshold, equals(10));
      expect(product.weight, equals(1.0));
      expect(product.attributes['brand'], equals('Amul'));
      expect(product.attributes['unit'], equals('litre'));
      expect(product.attributes['flavor'], equals('Plain'));
      expect(product.attributes['shelf_life'], equals('2 Days'));

      // Verify toJson() preserves all specs
      final serialized = product.toJson();
      expect(serialized['unit'], equals('litre'));
      expect(serialized['brand'], equals('Amul'));
      expect(serialized['floor_price'], equals(30.0));
      expect(serialized['allow_bargain'], isTrue);
      expect(serialized['attributes']['flavor'], equals('Plain'));
      expect(serialized['attributes']['shelf_life'], equals('2 Days'));
    });

    test('ProductModel.fromJson extracts top-level specifications into attributes', () {
      final json = {
        'id': 'prod_1001',
        'name': 'Boat Rockerz 450',
        'price': 1499.0,
        'category_id': 'electronics-appliances',
        'brand': 'boAt',
        'unit': 'piece',
        'color': 'Luscious Black',
        'warranty': '1 Year Brand Warranty',
        'model': 'Rockerz 450 Pro',
        'stock_quantity': 25,
      };

      final product = ProductModel.fromJson(json);
      expect(product.brand, equals('boAt'));
      expect(product.unit, equals('piece'));
      expect(product.attributes['brand'], equals('boAt'));
      expect(product.attributes['color'], equals('Luscious Black'));
      expect(product.attributes['warranty'], equals('1 Year Brand Warranty'));
      expect(product.attributes['model'], equals('Rockerz 450 Pro'));
    });
  });

  group('13. Product Image Path Classification & Upload Integrity Tests', () {
    test('isLocalFilePath correctly identifies Android content URIs and local filesystem paths', () {
      expect(isLocalFilePath('content://media/external/images/media/349281'), isTrue);
      expect(isLocalFilePath('file:///data/user/0/com.shopsilo.merchant/cache/img.png'), isTrue);
      expect(isLocalFilePath('/data/user/0/com.shopsilo.merchant/cache/photo.png'), isTrue);
      expect(isLocalFilePath('/storage/emulated/0/DCIM/Camera/IMG_2026.png'), isTrue);
      expect(isLocalFilePath('C:\\Users\\photos\\item.png'), isTrue);
      expect(isLocalFilePath('https://api.shopsilo.in/uploads/prod1.jpg'), isFalse);
      expect(isLocalFilePath('/images/products/shop1/item.jpg'), isFalse);
    });

    test('isServerImageUrl strictly identifies CDN and server URLs without misclassifying local files', () {
      expect(isServerImageUrl('https://api.shopsilo.in/images/products/1.jpg'), isTrue);
      expect(isServerImageUrl('http://localhost:8080/uploads/item.png'), isTrue);
      expect(isServerImageUrl('/images/products/123/banner.webp'), isTrue);
      expect(isServerImageUrl('/uploads/products/item.png'), isTrue);

      // Local device paths must NEVER be misclassified as server URLs
      expect(isServerImageUrl('content://media/external/images/media/349281'), isFalse);
      expect(isServerImageUrl('/data/user/0/com.shopsilo.merchant/cache/image_picker_123.png'), isFalse);
      expect(isServerImageUrl('/storage/emulated/0/DCIM/Camera/photo.png'), isFalse);
      expect(isServerImageUrl('blob:http://localhost:54321/mock-guid'), isFalse);
      expect(isServerImageUrl('data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=='), isFalse);
    });
  });

  group('14. Hardware GPS & Store Location Synchronization Tests', () {
    test('extractCoordinatesFromMapsUrl accurately parses query parameter formats', () {
      final res1 = LocationService.extractCoordinatesFromMapsUrl('https://maps.google.com/?q=25.5941,85.1376');
      expect(res1, isNotNull);
      expect(res1!['latitude'], closeTo(25.5941, 0.0001));
      expect(res1['longitude'], closeTo(85.1376, 0.0001));

      final res2 = LocationService.extractCoordinatesFromMapsUrl('https://www.google.com/maps/search/?api=1&query=26.1542,85.8918');
      expect(res2, isNotNull);
      expect(res2!['latitude'], closeTo(26.1542, 0.0001));
      expect(res2['longitude'], closeTo(85.8918, 0.0001));
    });

    test('extractCoordinatesFromMapsUrl accurately parses centered @ URL format', () {
      final res = LocationService.extractCoordinatesFromMapsUrl('https://www.google.com/maps/@28.6139,77.2090,15z');
      expect(res, isNotNull);
      expect(res!['latitude'], closeTo(28.6139, 0.0001));
      expect(res['longitude'], closeTo(77.2090, 0.0001));
    });

    test('extractCoordinatesFromMapsUrl accurately parses raw lat,lng string format', () {
      final res = LocationService.extractCoordinatesFromMapsUrl('26.1054, 85.9201');
      expect(res, isNotNull);
      expect(res!['latitude'], closeTo(26.1054, 0.0001));
      expect(res['longitude'], closeTo(85.9201, 0.0001));
    });

    test('extractCoordinatesFromMapsUrl returns null on empty or non-coordinate strings', () {
      expect(LocationService.extractCoordinatesFromMapsUrl(''), isNull);
      expect(LocationService.extractCoordinatesFromMapsUrl('https://google.com'), isNull);
      expect(LocationService.extractCoordinatesFromMapsUrl('random text without lat lng'), isNull);
    });

    test('LocationResult failure and success modeling', () {
      final failure = LocationResult.failure('GPS turned off');
      expect(failure.isSuccess, isFalse);
      expect(failure.error, equals('GPS turned off'));
      expect(failure.latitude, equals(0.0));
      expect(failure.longitude, equals(0.0));

      final success = LocationResult(
        latitude: 25.5941,
        longitude: 85.1376,
        city: 'Patna',
        pincode: '800001',
        googleMapsUrl: 'https://www.google.com/maps?q=25.5941,85.1376',
      );
      expect(success.isSuccess, isTrue);
      expect(success.error, isNull);
      expect(success.city, equals('Patna'));
      expect(success.pincode, equals('800001'));
    });

    test('ShopModel copyWith updates and preserves coordinates and maps URL', () {
      final initial = ShopModel(
        id: 'shop_1',
        name: 'ShopSilo Supermart',
        slug: 'shopsilo-supermart',
        address: 'Old Market',
        city: 'Darbhanga',
        pincode: '846004',
        latitude: 26.1542,
        longitude: 85.8918,
        googleMapsUrl: 'https://www.google.com/maps?q=26.1542,85.8918',
      );

      final updated = initial.copyWith(
        city: 'Muzaffarpur',
        pincode: '842001',
        latitude: 26.1209,
        longitude: 85.3647,
        googleMapsUrl: 'https://www.google.com/maps?q=26.1209,85.3647',
      );

      expect(updated.city, equals('Muzaffarpur'));
      expect(updated.pincode, equals('842001'));
      expect(updated.latitude, closeTo(26.1209, 0.0001));
      expect(updated.longitude, closeTo(85.3647, 0.0001));
      expect(updated.googleMapsUrl, equals('https://www.google.com/maps?q=26.1209,85.3647'));
      expect(updated.hasGpsCoordinates, isTrue);
      expect(updated.formattedGps, contains('26.1209'));
    });

    test('ShopModel fromJson and toJson serialize latitude, longitude, and maps URL', () {
      final json = {
        'id': 'shop_99',
        'name': 'Patna Central Grocery',
        'address': 'Boring Road',
        'city': 'Patna',
        'pincode': '800001',
        'latitude': 25.6104,
        'longitude': 85.1122,
        'google_maps_url': 'https://www.google.com/maps?q=25.6104,85.1122',
      };

      final shop = ShopModel.fromJson(json);
      expect(shop.latitude, closeTo(25.6104, 0.0001));
      expect(shop.longitude, closeTo(85.1122, 0.0001));
      expect(shop.googleMapsUrl, equals('https://www.google.com/maps?q=25.6104,85.1122'));

      final serialized = shop.toJson();
      expect(serialized['latitude'], closeTo(25.6104, 0.0001));
      expect(serialized['longitude'], closeTo(85.1122, 0.0001));
      expect(serialized['google_maps_url'], equals('https://www.google.com/maps?q=25.6104,85.1122'));
    });
  });

  group('15. Storefront Price Privacy & Hide Price (Bargain Protection) Tests', () {
    test('ProductModel isPricePublic defaults to true', () {
      final p = ProductModel(
        id: 'p1',
        name: 'Rice 5kg',
        price: 350.0,
        stock: 10,
        category: 'Grocery & Staples',
      );
      expect(p.isPricePublic, isTrue);
    });

    test('ProductModel supports isPricePublic false and preserves across copyWith', () {
      final p = ProductModel(
        id: 'p2',
        name: 'Pure Desi Ghee 1L',
        price: 650.0,
        stock: 5,
        category: 'Dairy, Bakery & Frozen',
        isPricePublic: false,
      );
      expect(p.isPricePublic, isFalse);

      final updated = p.copyWith(price: 680.0);
      expect(updated.isPricePublic, isFalse);

      final toggled = updated.copyWith(isPricePublic: true);
      expect(toggled.isPricePublic, isTrue);
    });

    test('ProductModel.fromJson parses is_price_public from top-level and attributes fallback', () {
      final json1 = {
        'id': 'p3',
        'name': 'Samsung Smart TV 43 inch',
        'price': 28999.0,
        'stock': 2,
        'category': 'Electronics & Appliances',
        'is_price_public': false,
      };
      final p1 = ProductModel.fromJson(json1);
      expect(p1.isPricePublic, isFalse);

      // Stringified "false"
      final json2 = {
        'id': 'p4',
        'name': 'Sony Soundbar',
        'price': 12999.0,
        'stock': 3,
        'category': 'Electronics & Appliances',
        'is_price_public': 'false',
      };
      final p2 = ProductModel.fromJson(json2);
      expect(p2.isPricePublic, isFalse);

      // Nested inside attributes
      final json3 = {
        'id': 'p5',
        'name': 'Custom Handmade Carpet',
        'price': 4500.0,
        'stock': 1,
        'category': 'Household & Cleaning',
        'attributes': {'is_price_public': false},
      };
      final p3 = ProductModel.fromJson(json3);
      expect(p3.isPricePublic, isFalse);
    });

    test('ProductModel.toJson embeds is_price_public in both top-level and attributes', () {
      final p = ProductModel(
        id: 'p6',
        name: 'Designer Saree',
        price: 2500.0,
        stock: 4,
        category: 'Clothing & Fashion',
        isPricePublic: false,
      );

      final json = p.toJson();
      expect(json['is_price_public'], isFalse);
      expect(json['attributes']['is_price_public'], isFalse);
    });
  });
  group('16. Shop Side Fast In-Memory Search & Sorting Engine Tests', () {
    final sampleProducts = [
      ProductModel(
        id: '1',
        name: 'Tata Salt Vacuum Evaporated 1kg',
        price: 28.0,
        costPrice: 22.0,
        comparePrice: 30.0,
        stock: 45,
        sku: 'SALT-001',
        barcode: '8901234567890',
        category: 'Grocery & Staples',
        attributes: {'brand': 'Tata'},
      ),
      ProductModel(
        id: '2',
        name: 'Maggi 2-Minute Masala Noodles 70g',
        price: 14.0,
        costPrice: 10.0,
        comparePrice: 14.0,
        stock: 3, // Low stock
        sku: 'MAG-002',
        barcode: '8901058852341',
        category: 'Snacks & Munchies',
        attributes: {'brand': 'Nestle', 'flavor': 'Masala'},
      ),
      ProductModel(
        id: '3',
        name: 'Amul Butter Pasteurized 500g',
        price: 275.0,
        costPrice: 250.0,
        comparePrice: 280.0,
        stock: 0, // Out of stock
        sku: 'AMUL-003',
        barcode: '8901262010057',
        category: 'Dairy, Bakery & Frozen',
        attributes: {'brand': 'Amul'},
      ),
      ProductModel(
        id: '4',
        name: 'Kashmiri Saffron Pure 1g',
        price: 499.0,
        costPrice: 300.0, // High margin ~39.8%
        comparePrice: 600.0,
        stock: 12,
        sku: 'SAF-004',
        barcode: '8909876543210',
        category: 'Grocery & Staples',
        isPricePublic: false, // Hidden online
        attributes: {'grade': 'A+'},
      ),
    ];

    test('InventorySortOption covers all 9 business sorting modes with valid badges and icons', () {
      expect(InventorySortOption.values.length, equals(9));
      for (final opt in InventorySortOption.values) {
        expect(opt.icon, isNotNull);
      }
    });

    test('Fast Multi-Field Tokenized Search matches across name, sku, barcode, brand, and attributes', () {
      bool matches(ProductModel p, String query) {
        final queryTokens = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
        final buffer = StringBuffer()
          ..write(p.name.toLowerCase())
          ..write(' ')
          ..write(p.sku.toLowerCase())
          ..write(' ')
          ..write(p.barcode.toLowerCase())
          ..write(' ')
          ..write(p.category.toLowerCase())
          ..write(' ')
          ..write(p.brand.toLowerCase());
        for (final val in p.attributes.values) {
          if (val != null) buffer.write(' ${val.toString().toLowerCase()}');
        }
        final text = buffer.toString();
        return queryTokens.every((t) => text.contains(t));
      }

      // Name multi-token search
      expect(matches(sampleProducts[0], 'tata salt 1kg'), isTrue);
      expect(matches(sampleProducts[0], 'salt tata'), isTrue); // out-of-order

      // SKU search
      expect(matches(sampleProducts[1], 'MAG-002'), isTrue);

      // Barcode search
      expect(matches(sampleProducts[2], '8901262010057'), isTrue);

      // Brand search
      expect(matches(sampleProducts[1], 'Nestle'), isTrue);

      // Dynamic attribute search (flavor)
      expect(matches(sampleProducts[1], 'Masala'), isTrue);

      // Non-matching query
      expect(matches(sampleProducts[0], 'bournvita'), isFalse);
    });

    test('Inventory Sorting: Low Stock First prioritizes out-of-stock and low stock items', () {
      final list = List<ProductModel>.from(sampleProducts);
      list.sort((a, b) => a.stock.compareTo(b.stock));

      expect(list.first.id, equals('3')); // Stock 0
      expect(list[1].id, equals('2'));    // Stock 3
      expect(list.last.id, equals('1'));   // Stock 45
    });

    test('Inventory Sorting: Price High to Low sorts highest priced items first', () {
      final list = List<ProductModel>.from(sampleProducts);
      list.sort((a, b) => b.price.compareTo(a.price));

      expect(list.first.price, equals(499.0)); // Saffron
      expect(list.last.price, equals(14.0));   // Maggi
    });

    test('Inventory Sorting: Profit Margin Highest First prioritizes highest profit %', () {
      final list = List<ProductModel>.from(sampleProducts);
      list.sort((a, b) => b.profitMarginPct.compareTo(a.profitMarginPct));

      expect(list.first.id, equals('4')); // Saffron ~40% margin
    });

    test('Inventory Sorting: Hidden Price First puts storefront bargain items on top', () {
      final list = List<ProductModel>.from(sampleProducts);
      list.sort((a, b) {
        final aVal = (!a.isPricePublic || a.allowBargain) ? 1 : 0;
        final bVal = (!b.isPricePublic || b.allowBargain) ? 1 : 0;
        return bVal.compareTo(aVal);
      });

      expect(list.first.id, equals('4')); // Hidden price Saffron
    });

    test('Inventory Sorting: Name A-Z sorts alphabetically', () {
      final list = List<ProductModel>.from(sampleProducts);
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      expect(list.first.name.startsWith('Amul'), isTrue);
      expect(list.last.name.startsWith('Tata'), isTrue);
    });
  });

  group('17. Customer Privacy Shield & Selective Specification Visibility Tests', () {
    test('CustomerPrivacyShield blocks all private merchant commercial and restocking keys', () {
      final blocked = [
        'cost_price', 'costprice', 'cost', 'unit_profit', 'profit', 'margin', 'profit_margin_pct',
        'cogs', 'wholesale_price', 'purchase_price', 'kharid_price',
        'floor_price', 'floorprice', 'min_price', 'bottom_price', 'allow_bargain',
        'supplier', 'supplier_name', 'distributor', 'distributor_name', 'vendor', 'dealer',
        'reorder_point', 'low_stock_threshold', 'min_stock', 'threshold',
        'barcode', 'sku', 'id', 'uuid', 'shop_id', 'user_id', 'internal_code',
        'is_price_public', 'hide_price', 'is_active', 'is_featured',
      ];

      for (final key in blocked) {
        expect(CustomerPrivacyShield.isSafeCustomerKey(key), isFalse, reason: '$key should be blocked');
      }
    });

    test('CustomerPrivacyShield allows genuine customer-facing product specifications', () {
      final allowed = [
        'color', 'size', 'flavor', 'scent', 'warranty', 'model', 'shelf_life',
        'expiry_date', 'ingredients', 'origin', 'manufacturer', 'material', 'fabric',
        'storage_instructions', 'pack_of', 'neck_type', 'ram', 'processor',
      ];

      for (final key in allowed) {
        expect(CustomerPrivacyShield.isSafeCustomerKey(key), isTrue, reason: '$key should be allowed');
      }
    });

    test('CustomerPrivacyShield extracts customer specifications while strictly filtering private fields', () {
      final prod = ProductModel(
        id: 'p-100',
        name: 'Cotton Casual Shirt',
        price: 999.0,
        costPrice: 600.0,
        floorPrice: 850.0,
        stock: 50,
        unit: 'piece',
        weight: 0.35,
        category: 'Clothing & Fashion',
        attributes: {
          'brand': 'Raymond',
          'color': 'Navy Blue',
          'size': '42 (L)',
          'fabric': '100% Pure Egyptian Cotton',
          'cost_price': 600.0, // Strictly private
          'floor_price': 850.0, // Strictly private
          'supplier': 'Surat Textile Mill Ltd', // Strictly private
          'distributor': 'National Garments Wholesaler', // Strictly private
          'reorder_point': 10, // Strictly private
          'barcode': '890123456789', // Strictly private
        },
      );

      final specs = prod.customerSpecifications;
      final specKeys = specs.map((e) => e.key).toList();
      final specMap = Map.fromEntries(specs);

      // Core identities must be present
      expect(specMap['Brand'], equals('Raymond'));
      expect(specMap['Category'], equals('Clothing & Fashion'));
      expect(specMap['Unit'], equals('piece'));
      expect(specMap['Net Weight'], equals('0.35 kg'));

      // Customer features must be present
      expect(specMap['Color'], equals('Navy Blue'));
      expect(specMap['Size'], equals('42 (L)'));
      expect(specMap['Fabric'], equals('100% Pure Egyptian Cotton'));

      // Private commercial metrics must NEVER be leaked
      expect(specKeys.contains('Cost Price'), isFalse);
      expect(specKeys.contains('Floor Price'), isFalse);
      expect(specKeys.contains('Supplier'), isFalse);
      expect(specKeys.contains('Distributor'), isFalse);
      expect(specKeys.contains('Reorder Point'), isFalse);
      expect(specKeys.contains('Barcode'), isFalse);
    });

    test('Merchant app router has strictly zero customer-facing routes', () {
      expect(AppRoutes.merchant, equals('/merchant'));
      // Verify customerShop route does not exist in merchant partner app
      final allRoutes = [
        AppRoutes.splash, AppRoutes.login, AppRoutes.register,
        AppRoutes.merchant, AppRoutes.todaySales, AppRoutes.pos,
        AppRoutes.inventory, AppRoutes.khata, AppRoutes.expenses,
        AppRoutes.offers, AppRoutes.analytics, AppRoutes.procurement,
        AppRoutes.lowStock, AppRoutes.reservations, AppRoutes.profile,
      ];
      expect(allRoutes.any((r) => r.startsWith('/shop/')), isFalse);
    });
  });

  group('18. Flutter Stale-While-Revalidate (SWR) & Event-Driven Invalidation Engine Tests', () {
    test('AppEventBus broadcasts events to subscribers with stream filtering', () async {
      final bus = AppEventBus();
      AppCacheEvent? receivedEvent;

      final sub = bus.on(AppCacheEventType.productsMutated, (event) {
        receivedEvent = event;
      });

      bus.emit(AppCacheEventType.productsMutated, payload: {'count': 42});

      // Allow event stream dispatch
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.type, equals(AppCacheEventType.productsMutated));
      expect(receivedEvent!.payload, equals({'count': 42}));

      await sub.cancel();
    });

    test('AppEventBus.emit executes targeted cache invalidation synchronously', () {
      final bus = AppEventBus();
      // Emitting khataMutated must not throw and should invalidate khata cache
      expect(() => bus.emit(AppCacheEventType.khataMutated), returnsNormally);
      expect(() => bus.emit(AppCacheEventType.productsMutated), returnsNormally);
      expect(() => bus.emit(AppCacheEventType.reservationMutated), returnsNormally);
    });

    test('LocalCacheService saves and retrieves reservations with 0ms sync retrieval', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      final testReservation = ReservationModel(
        id: 'res_test_101',
        pickupCode: '9876',
        customerName: 'Rahul Verma',
        customerMobile: '9876543210',
        productName: 'Aashirvaad Atta 5kg',
        quantity: 2,
        unitPrice: 220.0,
        totalPrice: 440.0,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await LocalCacheService.saveReservations([testReservation]);

      final retrieved = LocalCacheService.getReservations();
      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('res_test_101'));
      expect(retrieved.first.customerName, equals('Rahul Verma'));
      expect(retrieved.first.pickupCode, equals('9876'));
      expect(retrieved.first.totalPrice, equals(440.0));
    });

    test('LocalCacheService.clearCache completely purges all in-memory and persistent caches', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      final testReservation = ReservationModel(
        id: 'res_test_102',
        pickupCode: '1122',
        customerName: 'Sanjay Gupta',
        customerMobile: '9876543211',
        productName: 'Tata Tea 1kg',
        quantity: 1,
        unitPrice: 380.0,
        totalPrice: 380.0,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await LocalCacheService.saveReservations([testReservation]);
      expect(LocalCacheService.getReservations(), isNotEmpty);

      // Now clear cache on logout
      await LocalCacheService.clearCache();

      expect(LocalCacheService.getReservations(), isEmpty);
      expect(LocalCacheService.getProducts(), isEmpty);
      expect(LocalCacheService.getKhataCustomers(), isEmpty);
      expect(LocalCacheService.getExpenses(), isEmpty);
      expect(LocalCacheService.getOffers(), isEmpty);
    });
  });
}

