import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/services/smart_khata_reminder_service.dart';
import 'package:flutter_project_structure/features/khata/widgets/smart_payment_reminder_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartKhataReminderService Unit & Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
    });

    test('generateUpiPayUri builds standard UPI payment URI with formatted amount and encoded name', () {
      final uri = SmartKhataReminderService.generateUpiPayUri(
        upiId: 'merchant@okaxis',
        payeeName: 'ShopSilo Supermarket',
        amount: 1450.5,
      );

      expect(uri, startsWith('upi://pay?pa=merchant@okaxis'));
      expect(uri, contains('am=1450.50'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('pn=ShopSilo%20Supermarket'));
    });

    test('formatReminderMessage generates courteous pure Hindi statement with transactions and UPI', () {
      final customer = KhataCustomerModel(
        id: '1',
        name: 'रमेश कुमार',
        mobile: '9876543210',
        balance: 1450.0,
        promiseDate: DateTime(2026, 10, 25),
        overdueDays: 4,
      );

      final recentTxs = [
        KhataTransactionModel(
          id: 'tx-1',
          customerMobile: '9876543210',
          amount: 500.0,
          balanceAfter: 1450.0,
          type: 'GIVE_CREDIT',
          billNumber: '108',
          createdAt: DateTime(2026, 10, 18),
        ),
        KhataTransactionModel(
          id: 'tx-2',
          customerMobile: '9876543210',
          amount: 200.0,
          balanceAfter: 950.0,
          type: 'RECEIVE_PAYMENT',
          notes: 'UPI payment',
          createdAt: DateTime(2026, 10, 15),
        ),
      ];

      final messageHi = SmartKhataReminderService.formatReminderMessage(
        customer: customer,
        shopName: 'गुप्ता किराना स्टोर',
        shopUpiId: 'gupta@upi',
        recentTransactions: recentTxs,
        includeRecentHistory: true,
        includeUpiLink: true,
        isHindi: true,
      );

      expect(messageHi, contains('नमस्ते रमेश कुमार जी,'));
      expect(messageHi, contains('गुप्ता किराना स्टोर'));
      expect(messageHi, contains('कुल बकाया राशि: ₹1450'));
      expect(messageHi, contains('भुगतान वादा तारीख: 25/10/2026'));
      expect(messageHi, contains('विलंबित अवधि: 4 दिन'));
      expect(messageHi, contains('हालिया लेन-देन विवरण'));
      expect(messageHi, contains('उधार लिया (-) ₹500 (#108)'));
      expect(messageHi, contains('जमा किया (+) ₹200 (UPI payment)'));
      expect(messageHi, contains('upi://pay?pa=gupta@upi'));
      expect(messageHi, contains('UPI ID: gupta@upi'));
    });

    test('formatReminderMessage generates courteous pure English statement with transactions and UPI', () {
      final customer = KhataCustomerModel(
        id: '2',
        name: 'Rahul Sharma',
        mobile: '9876543211',
        balance: 750.0,
        promiseDate: DateTime(2026, 10, 28),
      );

      final recentTxs = [
        KhataTransactionModel(
          id: 'tx-3',
          customerMobile: '9876543211',
          amount: 750.0,
          balanceAfter: 750.0,
          type: 'GIVE_CREDIT',
          billNumber: '402',
          createdAt: DateTime(2026, 10, 17),
        ),
      ];

      final messageEn = SmartKhataReminderService.formatReminderMessage(
        customer: customer,
        shopName: 'City Mart',
        shopUpiId: 'citymart@icici',
        recentTransactions: recentTxs,
        includeRecentHistory: true,
        includeUpiLink: true,
        isHindi: false,
      );

      expect(messageEn, contains('Dear Rahul Sharma,'));
      expect(messageEn, contains('City Mart'));
      expect(messageEn, contains('Total Pending Dues: ₹750'));
      expect(messageEn, contains('Promised Payment Date: 28/10/2026'));
      expect(messageEn, contains('Recent Account Activity'));
      expect(messageEn, contains('Credit Given (-) ₹750 (#402)'));
      expect(messageEn, contains('upi://pay?pa=citymart@icici'));
      expect(messageEn, contains('UPI ID: citymart@icici'));
    });

    test('formatReminderMessage handles fully settled customer cleanly', () {
      final settledCustomer = KhataCustomerModel(
        id: '3',
        name: 'Anil Kumar',
        mobile: '9876543212',
        balance: 0.0,
      );

      final msg = SmartKhataReminderService.formatReminderMessage(
        customer: settledCustomer,
        shopName: 'Metro General Store',
        isHindi: false,
      );

      expect(msg, contains('Dear Anil Kumar,'));
      expect(msg, contains('zero pending dues'));
    });

    testWidgets('showSmartPaymentReminderSheet renders cleanly with live preview, toggles and zero overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final customer = KhataCustomerModel(
        id: 'cust-1',
        name: 'Vikram Singh',
        mobile: '9876500000',
        balance: 1200.0,
        promiseDate: DateTime(2026, 10, 30),
      );

      final txs = [
        KhataTransactionModel(
          id: 't-1',
          customerMobile: '9876500000',
          amount: 1200.0,
          balanceAfter: 1200.0,
          type: 'GIVE_CREDIT',
          createdAt: DateTime(2026, 10, 16),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showSmartPaymentReminderSheet(
                    context,
                    customer,
                    transactions: txs,
                  ),
                  child: const Text('Open Reminder'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open bottom sheet
      await tester.tap(find.text('Open Reminder'));
      await tester.pumpAndSettle();

      // Verify Header & Customer Info
      expect(find.text('Smart Payment Reminder'), findsOneWidget);
      expect(find.text('Vikram Singh (9876500000)'), findsOneWidget);
      expect(find.text('₹1200'), findsOneWidget);

      // Verify Actions
      expect(find.text('Send on WhatsApp'), findsOneWidget);
      expect(find.text('Copy Statement'), findsOneWidget);

      // Verify Live Preview Field
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, contains('Vikram Singh'));
      expect(textField.controller?.text, contains('Total Pending Dues: ₹1200'));
      expect(textField.controller?.text, contains('Credit Given (-) ₹1200'));

      // Intercept Clipboard platform calls
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      // Tap Copy Statement button
      await tester.tap(find.widgetWithText(OutlinedButton, 'Copy Statement'));
      await tester.pump();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('Vikram Singh'));
      expect(copiedText, contains('Total Pending Dues: ₹1200'));

      langCtrl.dispose();
    });
  });
}
