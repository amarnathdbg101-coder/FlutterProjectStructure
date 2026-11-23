import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/khata/controllers/khata_controller.dart';
import 'package:flutter_project_structure/features/khata/controllers/micro_plan_controller.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/screens/khata_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Khata Screen Modern UI/UX & Fast Action Tests', () {
    testWidgets('Hero Debt Card & Customer Passbook Cards render clean executive layout without overflow', (tester) async {
      tester.view.physicalSize = const Size(380, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      final testCustomers = [
        KhataCustomerModel(
          id: 'k-1',
          name: 'Vikas Sharma',
          mobile: '9876501234',
          balance: 850.0,
          creditLimit: 5000.0,
          overdueDays: 3,
          lastTransactionAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        KhataCustomerModel(
          id: 'k-2',
          name: 'Pooja Verma',
          mobile: '9123456789',
          balance: 0.0,
          creditLimit: 2000.0,
          lastTransactionAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      await LocalCacheService.saveKhataCustomers(testCustomers);

      final langCtrl = LanguageController();
      final khataCtrl = KhataController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<KhataController>.value(value: khataCtrl),
          ],
          child: const MaterialApp(
            home: KhataScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Hero Card
      expect(find.text('₹850'), findsWidgets); // Market debt & customer balance
      expect(find.text('+ Give Credit'), findsWidgets);
      expect(find.text('- Receive Cash'), findsWidgets);
      expect(find.textContaining('Overdue'), findsWidgets);

      // 2. Verify Customer Card Details (Name, Mobile, Relative Timestamp)
      expect(find.text('Vikas Sharma'), findsOneWidget);
      expect(find.text('Pooja Verma'), findsOneWidget);
      expect(find.textContaining('Today'), findsOneWidget);
      expect(find.textContaining('Yesterday'), findsOneWidget);

      // 3. Verify Clean Action Buttons (WhatsApp reminder for dues, Give Credit, Receive Payment)
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('+ Credit'), findsWidgets);
      expect(find.text('+ Payment'), findsWidgets);

      // 4. Test 1-Tap Quick Full Settlement in Add Transaction Modal
      final settleBtn = find.text('+ Payment').first;
      await tester.tap(settleBtn);
      await tester.pumpAndSettle();

      // Verify Modal opens with Full Settle chip for ₹850
      final fullSettleChip = find.text('Full Settle (₹850)');
      expect(fullSettleChip, findsOneWidget);

      // Tap full settle chip -> auto-populates amount field
      await tester.tap(fullSettleChip);
      await tester.pumpAndSettle();

      final amountField = find.widgetWithText(TextField, 'Amount (₹)');
      final textField = tester.widget<TextField>(amountField);
      expect(textField.controller?.text, '850');

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping Customer opens traditional CustomerStatementScreen with Sticky Bottom Bar and AppBar', (tester) async {
      tester.view.physicalSize = const Size(380, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      final testCustomers = [
        KhataCustomerModel(
          id: 'k-1',
          name: 'Vikas Sharma',
          mobile: '9876501234',
          balance: 850.0,
          creditLimit: 5000.0,
          overdueDays: 3,
          lastTransactionAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
      await LocalCacheService.saveKhataCustomers(testCustomers);

      final langCtrl = LanguageController();
      final khataCtrl = KhataController();
      final microCtrl = MicroPlanController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<KhataController>.value(value: khataCtrl),
            ChangeNotifierProvider<MicroPlanController>.value(value: microCtrl),
          ],
          child: const MaterialApp(
            home: KhataScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap on Customer Card to navigate to traditional CustomerStatementScreen
      await tester.tap(find.text('Vikas Sharma'));
      await tester.pumpAndSettle();

      // 1. Verify AppBar with Back Button, 1-Tap PDF and WhatsApp icons
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);

      // 2. Verify Unified Financial Summary Card on full page
      expect(find.text('Net Pending Dues'), findsOneWidget);
      expect(find.text('₹850'), findsWidgets);
      expect(find.textContaining('Credit Limit: ₹5000'), findsOneWidget);

      // 3. Verify Sticky Bottom Action Bar is visible
      expect(find.text('+ Give Credit'), findsWidgets);
      expect(find.text('- Receive Cash'), findsWidgets);

      // 4. Tap Sticky Receive Payment Button -> Navigates to Transaction Modal
      await tester.tap(find.text('- Receive Cash').last);
      await tester.pumpAndSettle();

      expect(find.text('Full Settle (₹850)'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 5. Test Back Button pops back to KhataScreen
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Total Market Dues'), findsOneWidget);

      // Drain error timer from mock network in test
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
