import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/expenses/controllers/expense_controller.dart';
import 'package:flutter_project_structure/features/expenses/models/expense_model.dart';
import 'package:flutter_project_structure/features/expenses/screens/expense_screen.dart';
import 'package:flutter_project_structure/features/expenses/services/smart_expense_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartExpenseService Unit Tests', () {
    test('calculateDailyProfit correctly computes profitable net profit and margin', () {
      final summary = SmartExpenseService.calculateDailyProfit(
        todaySales: 5000.0,
        todayExpenses: 1200.0,
      );

      expect(summary.todaySales, 5000.0);
      expect(summary.todayExpenses, 1200.0);
      expect(summary.netProfit, 3800.0);
      expect(summary.netProfitMarginPct, closeTo(76.0, 0.01));
      expect(summary.isProfitable, isTrue);
      expect(summary.isLoss, isFalse);
    });

    test('calculateDailyProfit correctly computes net loss when expenses exceed sales', () {
      final summary = SmartExpenseService.calculateDailyProfit(
        todaySales: 1000.0,
        todayExpenses: 2500.0,
      );

      expect(summary.todaySales, 1000.0);
      expect(summary.todayExpenses, 2500.0);
      expect(summary.netProfit, -1500.0);
      expect(summary.netProfitMarginPct, closeTo(-150.0, 0.01));
      expect(summary.isProfitable, isFalse);
      expect(summary.isLoss, isTrue);
    });

    test('calculateDailyProfit handles break-even scenario', () {
      final summary = SmartExpenseService.calculateDailyProfit(
        todaySales: 2000.0,
        todayExpenses: 2000.0,
      );

      expect(summary.netProfit, 0.0);
      expect(summary.netProfitMarginPct, 0.0);
      expect(summary.isProfitable, isFalse);
      expect(summary.isLoss, isFalse);
    });

    test('calculateDailyProfit handles zero sales gracefully without divide-by-zero', () {
      final summary = SmartExpenseService.calculateDailyProfit(
        todaySales: 0.0,
        todayExpenses: 350.0,
      );

      expect(summary.netProfit, -350.0);
      expect(summary.netProfitMarginPct, 0.0);
      expect(summary.isLoss, isTrue);
    });

    test('formatDailyExpenseSummary generates executive statements in English and Hindi', () {
      final expenses = [
        ExpenseModel(
          id: '1',
          category: 'chai_nashta',
          amount: 50.0,
          notes: 'Evening tea for staff',
          paymentMethod: 'cash',
          expenseDate: DateTime.now(),
        ),
        ExpenseModel(
          id: '2',
          category: 'transport',
          amount: 150.0,
          notes: 'Auto freight for warehouse boxes',
          paymentMethod: 'cash',
          expenseDate: DateTime.now(),
        ),
      ];

      // English verification
      final enSummary = SmartExpenseService.formatDailyExpenseSummary(
        shopName: 'Gupta General Store',
        todaySales: 6000.0,
        todayExpenses: 200.0,
        todayExpensesList: expenses,
        isHindi: false,
      );

      expect(enSummary.contains('DAILY EXPENSE & NET PROFIT STATEMENT'), isTrue);
      expect(enSummary.contains('Gupta General Store'), isTrue);
      expect(enSummary.contains('Total Sales Today: *₹6000*'), isTrue);
      expect(enSummary.contains('Total Expenses Today: *₹200*'), isTrue);
      expect(enSummary.contains('Net In-Hand Balance: *₹5800*'), isTrue);
      expect(enSummary.contains('Evening tea for staff'), isTrue);
      expect(enSummary.contains('Auto freight for warehouse boxes'), isTrue);

      // Hindi verification (Pure Hindi, no Hinglish)
      final hiSummary = SmartExpenseService.formatDailyExpenseSummary(
        shopName: 'गुप्ता किराना स्टोर',
        todaySales: 6000.0,
        todayExpenses: 200.0,
        todayExpensesList: expenses,
        isHindi: true,
      );

      expect(hiSummary.contains('दैनिक खर्च एवं लाभ विवरण'), isTrue);
      expect(hiSummary.contains('गुप्ता किराना स्टोर'), isTrue);
      expect(hiSummary.contains('आज की कुल बिक्री: *₹6000*'), isTrue);
      expect(hiSummary.contains('आज के कुल खर्चे: *₹200*'), isTrue);
      expect(hiSummary.contains('शुद्ध नकद बचत (Net In-Hand): *₹5800*'), isTrue);
    });

    test('quickAmountPresets contains standard retail cash note denominations', () {
      expect(SmartExpenseService.quickAmountPresets, equals([20, 50, 100, 200, 500, 1000, 2000]));
    });

    test('categories do not include any vegetable icons or labels', () {
      for (final cat in SmartExpenseService.categories) {
        final key = (cat['key'] as String).toLowerCase();
        final notes = (cat['defaultNotes'] as String).toLowerCase();
        expect(key.contains('vegetable'), isFalse);
        expect(key.contains('sabzi'), isFalse);
        expect(notes.contains('vegetable'), isFalse);
        expect(notes.contains('sabzi'), isFalse);
      }
    });
  });

  group('ExpenseScreen Widget Tests & Responsiveness', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      await LocalCacheService.clearCache();

      // Seed cached expenses
      final sampleExpenses = [
        ExpenseModel(
          id: 'exp_1',
          category: 'chai_nashta',
          amount: 30.0,
          notes: 'Morning tea',
          paymentMethod: 'cash',
          expenseDate: DateTime.now(),
        ),
        ExpenseModel(
          id: 'exp_2',
          category: 'transport',
          amount: 120.0,
          notes: 'Delivery fare',
          paymentMethod: 'cash',
          expenseDate: DateTime.now(),
        ),
      ];
      await LocalCacheService.saveExpenses(sampleExpenses);
    });

    Widget createTestApp() {
      final languageCtrl = LanguageController();
      final expCtrl = ExpenseController();
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
          ChangeNotifierProvider<ExpenseController>.value(value: expCtrl),
        ],
        child: const MaterialApp(
          home: ExpenseScreen(),
        ),
      );
    }

    testWidgets('renders KPI cards and expense list with zero overflow on mobile (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify KPI stat cards are present
      expect(find.text('₹150'), findsWidgets); // Today's expenses = 30 + 120 = 150
      expect(find.byType(ExpenseScreen), findsOneWidget);

      // Verify category filter chips
      expect(find.text('All'), findsOneWidget);

      // Verify existing items in the list
      expect(find.text('Morning tea'), findsOneWidget);
      expect(find.text('Delivery fare'), findsOneWidget);
      expect(find.text('₹30'), findsOneWidget);
      expect(find.text('₹120'), findsOneWidget);
    });

    testWidgets('add expense dialog opens with 1-tap quick amount chips and sets value', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap FAB "+ Add Expense"
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet opened
      expect(find.text('Record New Expense'), findsOneWidget);

      // Verify quick amount chips are rendered
      expect(find.text('₹20'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);

      // Tap the ₹100 chip
      await tester.tap(find.text('₹100'));
      await tester.pumpAndSettle();

      // Verify the amount textfield now has '100'
      final amountField = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '100',
      );
      expect(amountField, findsOneWidget);

      // Tap the ₹500 chip
      await tester.tap(find.text('₹500'));
      await tester.pumpAndSettle();

      // Verify the amount textfield now has '500'
      final updatedAmountField = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '500',
      );
      expect(updatedAmountField, findsOneWidget);
    });

    testWidgets('renders properly with zero overflow on Desktop viewport (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
