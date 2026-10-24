import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/services/offline_sync_service.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/widgets/offline_sync_sheet.dart';
import 'package:flutter_project_structure/core/widgets/store_switcher_dialog.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncService Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();
      await OfflineSyncService.instance.clearQueue();
    });

    test('enqueue creates item with unique idempotencyKey and persists in LocalCacheService', () async {
      final syncService = OfflineSyncService.instance;

      expect(syncService.pendingCount, 0);

      final item = await syncService.enqueue(
        action: SyncActionType.posSale,
        endpoint: '/shops/me/pos/sale',
        payload: {'bill_number': 'OFF-101', 'total': 450.0},
        title: 'POS Bill #OFF-101',
        amount: 450.0,
        autoProcess: false,
      );

      expect(item.id.isNotEmpty, isTrue);
      expect(item.idempotencyKey.isNotEmpty, isTrue);
      expect(item.status, SyncStatus.pending);
      expect(item.amount, 450.0);
      expect(syncService.pendingCount, 1);

      // Verify persistence in LocalCacheService
      final cachedQueue = LocalCacheService.getSyncQueue();
      expect(cachedQueue.length, 1);
      expect(cachedQueue.first['title'], 'POS Bill #OFF-101');
    });

    test('SyncQueueItem serialization and deserialization integrity', () {
      final item = SyncQueueItem(
        id: 'sync_test_1',
        action: SyncActionType.expenseCreate,
        endpoint: '/shops/me/expenses',
        method: 'POST',
        payload: {'amount': 50.0, 'category': 'chai_nashta'},
        createdAt: DateTime(2026, 10, 19, 10, 30),
        idempotencyKey: 'idemp_unique_123',
        status: SyncStatus.pending,
        title: 'Expense: CHAI_NASHTA (₹50)',
        amount: 50.0,
      );

      final json = item.toJson();
      final revived = SyncQueueItem.fromJson(json);

      expect(revived.id, item.id);
      expect(revived.action, SyncActionType.expenseCreate);
      expect(revived.endpoint, item.endpoint);
      expect(revived.method, 'POST');
      expect(revived.payload['amount'], 50.0);
      expect(revived.idempotencyKey, item.idempotencyKey);
      expect(revived.title, item.title);
      expect(revived.amount, 50.0);
    });

    test('removeCompleted removes only completed items', () async {
      final syncService = OfflineSyncService.instance;

      final item1 = await syncService.enqueue(
        action: SyncActionType.posSale,
        endpoint: '/shops/me/pos/sale',
        payload: {'id': '1'},
        title: 'Bill 1',
        autoProcess: false,
      );

      final item2 = await syncService.enqueue(
        action: SyncActionType.expenseCreate,
        endpoint: '/shops/me/expenses',
        payload: {'id': '2'},
        title: 'Expense 2',
        autoProcess: false,
      );

      expect(syncService.pendingCount, 2);

      // Simulate item1 completed
      final completedItem = item1.copyWith(status: SyncStatus.completed);
      final list = [completedItem.toJson(), item2.toJson()];
      await LocalCacheService.saveSyncQueue(list);

      // Re-hydrate
      syncService.reloadFromCache();
      await syncService.removeCompleted();
      expect(syncService.pendingCount, 1);
      expect(syncService.queue.first.title, 'Expense 2');
    });
  });

  group('AuthController Multi-Store Branch Switcher Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();
    });

    test('switchShop switches active currentShop and updates cache', () async {
      final authCtrl = AuthController();
      final shopA = ShopModel(id: 'shop_1', name: 'Main Bazaar Store', slug: 'main-bazaar', phone: '9876543210', category: 'General Store');
      final shopB = ShopModel(id: 'shop_2', name: 'Station Road Godown', slug: 'station-road', phone: '9876543211', category: 'Wholesale Depot');

      authCtrl.setManagedShopsForTesting([shopA, shopB]);
      expect(authCtrl.currentShop?.id, 'shop_1');

      final switched = await authCtrl.switchShop('shop_2');
      expect(switched, isTrue);
      expect(authCtrl.currentShop?.id, 'shop_2');
      expect(authCtrl.currentShop?.name, 'Station Road Godown');
    });

    test('registerBranchStore creates new branch and automatically selects it', () async {
      final authCtrl = AuthController();
      final shopA = ShopModel(id: 'shop_1', name: 'Main Bazaar Store', slug: 'main-bazaar', phone: '9876543210', category: 'General Store');
      authCtrl.setManagedShopsForTesting([shopA]);

      final created = await authCtrl.registerBranchStore(
        name: 'New Market Branch',
        address: 'Shop 14, New Market',
        category: 'Dairy & Bakery',
      );

      expect(created, isTrue);
      expect(authCtrl.managedShops.length, 2);
      expect(authCtrl.currentShop?.name, 'New Market Branch');
      expect(authCtrl.currentShop?.category, 'Dairy & Bakery');
    });
  });

  group('StoreSwitcherDialog and OfflineSyncSheet Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();
      await OfflineSyncService.instance.clearQueue();
    });

    Widget createTestApp(AuthController authCtrl) {
      final langCtrl = LanguageController();
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => StoreSwitcherDialog.show(context),
                    child: const Text('Open Store Switcher'),
                  ),
                  ElevatedButton(
                    onPressed: () => OfflineSyncSheet.show(context),
                    child: const Text('Open Sync Queue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('StoreSwitcherDialog renders managed shops and handles branch creation with zero overflow on mobile (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authCtrl = AuthController();
      final shop1 = ShopModel(id: 's1', name: 'Gupta Kirana Store', slug: 'gupta-kirana', phone: '9876543210', category: 'General Store');
      final shop2 = ShopModel(id: 's2', name: 'Gupta Wholesale Depot', slug: 'gupta-wholesale', phone: '9876543211', category: 'Wholesale Depot');
      authCtrl.setManagedShopsForTesting([shop1, shop2]);

      await tester.pumpWidget(createTestApp(authCtrl));
      await tester.pumpAndSettle();

      // Open Store Switcher
      await tester.tap(find.text('Open Store Switcher'));
      await tester.pumpAndSettle();

      // Verify title and shops rendered
      expect(find.text('Switch Store / Branch'), findsOneWidget);
      expect(find.text('Gupta Kirana Store'), findsOneWidget);
      expect(find.text('Gupta Wholesale Depot'), findsOneWidget);
      expect(find.text('Active Store'), findsOneWidget);

      // Tap on Add New Branch button
      final addBranchBtn = find.text('Add New Branch');
      expect(addBranchBtn, findsOneWidget);
      await tester.tap(addBranchBtn);
      await tester.pumpAndSettle();

      // Verify create branch form inputs appear
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('OfflineSyncSheet renders pending transactions and sync button with zero overflow on desktop (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authCtrl = AuthController();
      // Seed pending offline items
      await OfflineSyncService.instance.enqueue(
        action: SyncActionType.posSale,
        endpoint: '/shops/me/pos/sale',
        payload: {'bill': '101'},
        title: 'POS Bill #OFF-101',
        amount: 350.0,
        autoProcess: false,
      );
      await OfflineSyncService.instance.enqueue(
        action: SyncActionType.expenseCreate,
        endpoint: '/shops/me/expenses',
        payload: {'amount': 60.0},
        title: 'Expense: CHAI_NASHTA (₹60)',
        amount: 60.0,
        autoProcess: false,
      );

      await tester.pumpWidget(createTestApp(authCtrl));
      await tester.pumpAndSettle();

      // Open Sync Queue
      await tester.tap(find.text('Open Sync Queue'));
      await tester.pumpAndSettle();

      // Verify title and pending items
      expect(find.text('Offline Cloud Sync Queue'), findsOneWidget);
      expect(find.text('POS Bill #OFF-101'), findsOneWidget);
      expect(find.text('Expense: CHAI_NASHTA (₹60)'), findsOneWidget);
      expect(find.text('₹350'), findsOneWidget);
      expect(find.text('₹60'), findsOneWidget);

      // Verify Sync Now button
      expect(find.text('Sync Now'), findsOneWidget);
    });
  });
}
