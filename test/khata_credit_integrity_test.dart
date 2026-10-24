import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/repositories/khata_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Khata Credit & Passbook Integrity Tests', () {
    test('KhataTransactionModel correctly identifies GIVE_CREDIT and RECEIVE_PAYMENT', () {
      final creditTx = KhataTransactionModel.fromJson({
        'id': 'tx-101',
        'customer_mobile': '8051545558',
        'type': 'GIVE_CREDIT',
        'amount': 250.0,
        'balance_after': 750.0,
        'notes': 'Groceries on credit',
        'bill_number': 'BILL-001',
        'payment_mode': 'credit',
        'status': 'CONFIRMED',
        'created_at': '2026-10-18T17:55:00Z',
      });

      expect(creditTx.isCredit, isTrue);
      expect(creditTx.isPayment, isFalse);
      expect(creditTx.balanceAfter, equals(750.0));
      expect(creditTx.amount, equals(250.0));

      final paymentTx = KhataTransactionModel.fromJson({
        'id': 'tx-102',
        'customer_mobile': '8051545558',
        'type': 'RECEIVE_PAYMENT',
        'amount': 500.0,
        'balance_after': 250.0,
        'notes': 'UPI settlement',
        'payment_mode': 'upi',
        'status': 'CONFIRMED',
        'created_at': '2026-10-18T18:00:00Z',
      });

      expect(paymentTx.isCredit, isFalse);
      expect(paymentTx.isPayment, isTrue);
      expect(paymentTx.balanceAfter, equals(250.0));
      expect(paymentTx.amount, equals(500.0));
    });

    test('KhataCustomerModel bidirectional JSON preserves current_balance and balance', () {
      final backendJson = {
        'id': 'cust-uuid-1',
        'customer_name': 'Amarnath Sharma',
        'customer_mobile': '8051545558',
        'current_balance': 350.0,
        'credit_limit': 15000.0,
        'last_activity_at': '2026-10-18T17:56:00Z',
      };

      final customer = KhataCustomerModel.fromJson(backendJson);
      expect(customer.name, equals('Amarnath Sharma'));
      expect(customer.mobile, equals('8051545558'));
      expect(customer.balance, equals(350.0));
      expect(customer.hasPendingUdhar, isTrue);

      final serialized = customer.toJson();
      expect(serialized['current_balance'], equals(350.0));
      expect(serialized['balance'], equals(350.0));
      expect(serialized['customer_name'], equals('Amarnath Sharma'));
      expect(serialized['customer_mobile'], equals('8051545558'));

      final rehydrated = KhataCustomerModel.fromJson(serialized);
      expect(rehydrated.balance, equals(350.0));
      expect(rehydrated.name, equals('Amarnath Sharma'));
    });

    test('KhataSummaryModel correctly deserializes GoBackend total_outstanding_amount', () {
      final summaryJson = {
        'total_outstanding_amount': 45000.0,
        'total_customers': 12,
        'total_transactions_count': 54,
      };

      final summary = KhataSummaryModel.fromJson(summaryJson);
      expect(summary.totalReceivables, equals(45000.0));
      expect(summary.totalDebtors, equals(12));
    });

    test('Khata Aging buckets correctly map from GoBackend schema', () {
      final agingJson = {
        'bucket_0_to_30': 20000.0,
        'bucket_31_to_60': 15000.0,
        'bucket_60_plus': 10000.0,
      };

      final aging = KhataAgingModel.fromJson(agingJson);
      expect(aging.currentDays0To30, equals(20000.0));
      expect(aging.days31To60, equals(15000.0));
      expect(aging.days61Plus, equals(10000.0));
      expect(aging.total, equals(45000.0));
    });

    test('KhataRepository phone normalization cleans +91, 0, and non-digits', () {
      expect(KhataRepository.normalizePhone('+91 80515 45558'), equals('8051545558'));
      expect(KhataRepository.normalizePhone('08051545558'), equals('8051545558'));
      expect(KhataRepository.normalizePhone('918051545558'), equals('8051545558'));
      expect(KhataRepository.normalizePhone('8051545558'), equals('8051545558'));
    });

    test('Passbook transaction filtering correctly splits Credit and Payment', () {
      final txs = [
        KhataTransactionModel(
          id: '1',
          customerMobile: '8051545558',
          amount: 200,
          balanceAfter: 200,
          type: 'GIVE_CREDIT',
          createdAt: DateTime.now(),
        ),
        KhataTransactionModel(
          id: '2',
          customerMobile: '8051545558',
          amount: 50,
          balanceAfter: 150,
          type: 'RECEIVE_PAYMENT',
          createdAt: DateTime.now(),
        ),
        KhataTransactionModel(
          id: '3',
          customerMobile: '8051545558',
          amount: 100,
          balanceAfter: 250,
          type: 'CREDIT',
          createdAt: DateTime.now(),
        ),
      ];

      final credits = txs.where((t) => t.isCredit).toList();
      final payments = txs.where((t) => t.isPayment).toList();

      expect(credits.length, equals(2));
      expect(payments.length, equals(1));
      expect(credits.first.balanceAfter, equals(200));
      expect(payments.first.balanceAfter, equals(150));
    });

    test('KhataRepository getStatementPdfUrl returns valid authenticated URL', () async {
      final repo = KhataRepository();
      final res = await repo.getStatementPdfUrl('8051545558');
      expect(res.success, isTrue);
      expect(res.data, contains('/shops/me/khata/8051545558/statement.pdf'));
    });
  });
}
