import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/repositories/khata_repository.dart';
import 'package:flutter_project_structure/features/khata/controllers/khata_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Khata Transaction Edit & Soft-Delete Comprehensive Tests', () {
    test('KhataTransactionModel correctly parses audit fields for updated transaction', () {
      final json = {
        'id': 'tx-edit-001',
        'customer_mobile': '9876543210',
        'type': 'GIVE_CREDIT',
        'amount': 450.0,
        'original_amount': 500.0,
        'balance_after': 1450.0,
        'notes': 'Milk and snacks - discounted',
        'bill_number': 'INV-8812',
        'payment_mode': 'credit',
        'status': 'CONFIRMED',
        'is_deleted': false,
        'edit_reason': 'Corrected ₹50 calculation error',
        'modified_by': 'shop_owner',
        'updated_at': '2026-11-09T18:30:00Z',
        'created_at': '2026-11-09T12:00:00Z',
      };

      final tx = KhataTransactionModel.fromJson(json);

      expect(tx.id, equals('tx-edit-001'));
      expect(tx.amount, equals(450.0));
      expect(tx.originalAmount, equals(500.0));
      expect(tx.editReason, equals('Corrected ₹50 calculation error'));
      expect(tx.isDeleted, isFalse);
      expect(tx.isCancelled, isFalse);
      expect(tx.updatedAt, isNotNull);

      final serialized = tx.toJson();
      expect(serialized['original_amount'], equals(500.0));
      expect(serialized['edit_reason'], equals('Corrected ₹50 calculation error'));
    });

    test('KhataTransactionModel correctly identifies cancelled / soft-deleted transaction', () {
      final json = {
        'id': 'tx-del-002',
        'customer_mobile': '9876543210',
        'type': 'RECEIVE_PAYMENT',
        'amount': 200.0,
        'balance_after': 1250.0,
        'notes': 'UPI payment failed at bank',
        'status': 'CANCELLED',
        'is_deleted': true,
        'deleted_at': '2026-11-09T19:00:00Z',
        'deleted_by': 'manager',
        'delete_reason': 'UPI transaction bounced/chargeback',
        'created_at': '2026-11-09T12:30:00Z',
      };

      final tx = KhataTransactionModel.fromJson(json);

      expect(tx.id, equals('tx-del-002'));
      expect(tx.isDeleted, isTrue);
      expect(tx.status, equals('CANCELLED'));
      expect(tx.isCancelled, isTrue);
      expect(tx.deleteReason, equals('UPI transaction bounced/chargeback'));
      expect(tx.deletedAt, isNotNull);

      final serialized = tx.toJson();
      expect(serialized['is_deleted'], isTrue);
      expect(serialized['delete_reason'], equals('UPI transaction bounced/chargeback'));
    });

    test('KhataTransactionModel handles null/default values safely without assertions', () {
      final minimalJson = {
        'id': 109,
        'amount': 150,
        'type': 'credit',
        'created_at': '2026-11-09T10:00:00Z',
      };

      final tx = KhataTransactionModel.fromJson(minimalJson);

      expect(tx.id, equals('109'));
      expect(tx.amount, equals(150.0));
      expect(tx.originalAmount, isNull);
      expect(tx.isDeleted, isFalse);
      expect(tx.isCancelled, isFalse);
      expect(tx.deleteReason, isEmpty);
      expect(tx.editReason, isEmpty);
      expect(tx.updatedAt, isNull);
      expect(tx.deletedAt, isNull);
    });

    test('KhataRepository update and delete methods reject empty mandatory reason', () async {
      final repo = KhataRepository();

      // Test repository update
      final updateRes = await repo.updateKhataTransaction(
        khataId: 'khata-1',
        txId: 'tx-1',
        amount: 250.0,
        reason: '   ',
      );
      expect(updateRes.success, isFalse);
      expect(updateRes.message, contains('Reason for modification is required'));

      // Test repository delete
      final deleteRes = await repo.deleteKhataTransaction(
        'khata-1',
        'tx-1',
        reason: '',
      );
      expect(deleteRes.success, isFalse);
      expect(deleteRes.message, contains('Reason for deletion is required'));
    });

    test('KhataController validates edit transaction payload before network call', () async {
      final controller = KhataController();

      // Amount <= 0 should fail
      final okZero = await controller.updateTransaction(
        khataId: 'khata-1',
        txId: 'tx-1',
        customerMobile: '9876543210',
        amount: 0.0,
        reason: 'Valid correction reason',
      );
      expect(okZero, isFalse);
      expect(controller.errorMessage, contains('valid amount'));

      // Reason < 3 characters should fail
      final okShortReason = await controller.updateTransaction(
        khataId: 'khata-1',
        txId: 'tx-1',
        customerMobile: '9876543210',
        amount: 500.0,
        reason: 'ok',
      );
      expect(okShortReason, isFalse);
      expect(controller.errorMessage, contains('Audit reason must be at least 3 characters'));

      // Delete with reason < 3 characters should fail
      final okDeleteShort = await controller.deleteTransaction(
        'khata-1',
        'tx-1',
        '9876543210',
        reason: 'no',
      );
      expect(okDeleteShort, isFalse);
      expect(controller.errorMessage, contains('Audit reason must be at least 3 characters'));
    });
  });
}
