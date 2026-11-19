import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/pos/models/pos_features_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();
  });

  group('ShopSilo Advanced Features Suite Tests', () {
    test('1. HotkeyItem model parses JSON accurately', () {
      final hotkey = HotkeyItem.fromJson({
        'id': 'hk-1',
        'shop_id': 'shop-1',
        'product_id': 'prod-milk-1',
        'label': 'Amul Milk 500ml',
        'color_code': '#3B82F6',
        'position': 1,
        'quick_quantity': 2.0,
        'product_name': 'Amul Taaza Milk 500ml',
        'selling_price': 27.0,
        'stock_quantity': 45.0,
      });

      expect(hotkey.id, 'hk-1');
      expect(hotkey.label, 'Amul Milk 500ml');
      expect(hotkey.quickQuantity, 2.0);
      expect(hotkey.sellingPrice, 27.0);
    });

    test('2. CashDrawerSession tracks opening float, safe drops, and discrepancy', () {
      final session = CashDrawerSession.fromJson({
        'id': 'sess-1',
        'shop_id': 'shop-1',
        'opened_by': 'user-1',
        'opened_by_name': 'Ramesh Cashier',
        'opening_cash': 2000.0,
        'closing_cash': 14500.0,
        'expected_cash': 14500.0,
        'discrepancy': 0.0,
        'safe_drop_total': 5000.0,
        'petty_cash_expenses': 120.0,
        'status': 'OPEN',
        'current_cash_in_drawer': 9380.0,
        'requires_safe_drop': false,
      });

      expect(session.isOpen, isTrue);
      expect(session.openedByName, 'Ramesh Cashier');
      expect(session.openingCash, 2000.0);
      expect(session.currentCashInDrawer, 9380.0);
      expect(session.discrepancy, 0.0);
    });

    test('3. ScanAndGoSession parses verified 6-digit customer baskets', () {
      final session = ScanAndGoSession.fromJson({
        'id': 'sng-session-99',
        'shop_id': 'shop-1',
        'customer_phone': '9876543210',
        'verification_code': '482910',
        'status': 'VERIFIED',
        'total_amount': 250.0,
        'total_items': 2,
        'items': [
          {
            'id': 'item-1',
            'product_id': 'prod-101',
            'product_name': 'Fortune Oil 1L',
            'barcode': '890123456789',
            'quantity': 1.0,
            'unit_price': 150.0,
            'subtotal': 150.0,
          },
          {
            'id': 'item-2',
            'product_id': 'prod-102',
            'product_name': 'Aashirvaad Atta 2kg',
            'barcode': '890987654321',
            'quantity': 1.0,
            'unit_price': 100.0,
            'subtotal': 100.0,
          },
        ],
      });

      expect(session.verificationCode, '482910');
      expect(session.items.length, 2);
      expect(session.totalAmount, 250.0);
      expect(session.items.first.productName, 'Fortune Oil 1L');
    });

    test('4. DamageClaim & ReturnLookupItem models manage company claims and no-bill returns', () {
      final claim = DamageClaim.fromJson({
        'id': 'claim-1',
        'shop_id': 'shop-1',
        'distributor_name': 'Nestle India Distribution',
        'product_id': 'prod-maggi-1',
        'product_name': 'Maggi Noodles 70g (Carton)',
        'batch_number': 'LOT-NESTLE-2026',
        'quantity': 24.0,
        'unit_cost': 12.0,
        'claim_amount': 288.0,
        'reason': 'DAMAGED_IN_TRANSIT',
        'status': 'PENDING',
      });

      expect(claim.claimAmount, 288.0);
      expect(claim.status, 'PENDING');
      expect(claim.distributorName, 'Nestle India Distribution');

      final returnItem = ReturnLookupItem.fromJson({
        'sale_id': 'sale-101',
        'bill_number': 'BILL-88392',
        'sale_date': '2026-11-01T10:00:00Z',
        'customer_phone': '9876543210',
        'product_id': 'prod-shirt-1',
        'product_name': 'Cotton Casual Shirt L',
        'barcode': '89077665544',
        'quantity_sold': 1.0,
        'unit_price': 799.0,
        'discount': 50.0,
        'net_price': 749.0,
        'is_returnable': true,
      });

      expect(returnItem.billNumber, 'BILL-88392');
      expect(returnItem.netPrice, 749.0);
      expect(returnItem.isReturnable, isTrue);
    });

    test('5. ProductBatch & MarkdownScanResult manage 30-day expiry radar', () {
      final batch = ProductBatch.fromJson({
        'id': 'batch-1',
        'shop_id': 'shop-1',
        'product_id': 'prod-bread-1',
        'product_name': 'Harvest Gold Brown Bread 400g',
        'batch_number': 'LOT-HG-44',
        'expiry_date': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
        'initial_quantity': 20.0,
        'current_quantity': 8.0,
        'purchase_cost': 32.0,
        'mrp': 50.0,
        'markdown_discount': 20.0,
        'days_to_expiry': 4,
        'status': 'CRITICAL',
      });

      expect(batch.daysToExpiry, 4);
      expect(batch.markdownDiscount, 20.0);
      expect(batch.status, 'CRITICAL');

      final scanResult = MarkdownScanResult.fromJson({
        'batches_scanned': 15,
        'markdowns_applied': 3,
        'total_potential_loss_saved': 450.0,
        'updated_batches': ['LOT-HG-44', 'LOT-DAIRY-99'],
      });

      expect(scanResult.markdownsApplied, 3);
      expect(scanResult.totalPotentialLossSaved, 450.0);
    });

    test('6. KhataMicroPlan computes payment streak and progress percentage', () {
      final plan = KhataMicroPlan.fromJson({
        'id': 'plan-1',
        'shop_id': 'shop-1',
        'customer_phone': '9876543210',
        'customer_name': 'Vikram Singh',
        'total_debt': 3000.0,
        'daily_amount': 100.0,
        'collected_amount': 1200.0,
        'remaining_amount': 1800.0,
        'target_days': 30,
        'days_completed': 12,
        'current_streak': 12,
        'status': 'ACTIVE',
      });

      expect(plan.progressPercentage, closeTo(0.40, 0.01));
      expect(plan.currentStreak, 12);
      expect(plan.isCompleted, isFalse);
    });
  });
}
