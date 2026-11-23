import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/network/network_status_service.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();
    await LocalCacheService.clearCache();
  });

  group('Industrial Offline Caching & Statement Tests', () {
    test('Khata customer passbook statements persist and retrieve in 0ms', () async {
      const phone = '9876543210';
      final sampleTx = KhataTransactionModel(
        id: 'tx_101',
        customerMobile: phone,
        amount: 250.0,
        type: 'credit',
        notes: 'Grocery items',
        createdAt: DateTime.now(),
      );

      // Initially empty
      expect(LocalCacheService.getCustomerStatement(phone), isEmpty);

      // Save statement
      await LocalCacheService.saveCustomerStatement(phone, [sampleTx]);

      // Retrieve instantly from memory/cache
      final cached = LocalCacheService.getCustomerStatement(phone);
      expect(cached.length, 1);
      expect(cached.first.id, 'tx_101');
      expect(cached.first.amount, 250.0);

      // Append new transaction
      final paymentTx = KhataTransactionModel(
        id: 'tx_102',
        customerMobile: phone,
        amount: 250.0,
        type: 'payment',
        notes: 'UPI Payment',
        createdAt: DateTime.now(),
      );
      await LocalCacheService.appendCustomerTransaction(phone, paymentTx);

      final updated = LocalCacheService.getCustomerStatement(phone);
      expect(updated.length, 2);
      expect(updated.first.id, 'tx_102'); // Prepend order
    });

    test('NetworkStatusService detects offline and online transitions reactively', () {
      final service = NetworkStatusService();
      service.markOnline();
      expect(service.isOnline, isTrue);

      bool notified = false;
      service.addListener(() => notified = true);

      // Trigger offline
      service.markOffline(reason: 'connectionTimeout');
      expect(service.isOnline, isFalse);
      expect(service.lastOfflineAt, isNotNull);
      expect(notified, isTrue);

      // Trigger online
      notified = false;
      service.markOnline();
      expect(service.isOnline, isTrue);
      expect(service.lastOfflineAt, isNull);
      expect(notified, isTrue);
    });
  });
}
