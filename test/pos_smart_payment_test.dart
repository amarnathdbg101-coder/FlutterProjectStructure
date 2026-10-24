import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/screens/pos_screen.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Smart Payment & Change Calculator Tests', () {
    late PosController pos;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
      pos = PosController();
    });

    tearDown(() {
      pos.dispose();
    });

    test('getSmartCashSuggestions generates exact and realistic Indian note denominations', () {
      // 1. Bill Total ₹365 (Dove Shampoo + Rice etc.)
      pos.addToCart(ProductModel(id: '1', name: 'Item', price: 365.0, stock: 10, category: 'General'));
      expect(pos.grandTotal, 365.0);

      final suggestions365 = pos.getSmartCashSuggestions();
      expect(suggestions365, contains(365.0)); // Exact
      expect(suggestions365, contains(400.0)); // Round 50/100
      expect(suggestions365, contains(500.0)); // 500 note
      expect(suggestions365, contains(1000.0)); // 1000 note combo
      expect(suggestions365.length, lessThanOrEqualTo(5));

      // 2. Bill Total ₹72
      pos.clearCart(syncWithBackend: false);
      pos.addToCart(ProductModel(id: '2', name: 'Soap', price: 72.0, stock: 10, category: 'Personal'));
      expect(pos.grandTotal, 72.0);

      final suggestions72 = pos.getSmartCashSuggestions();
      expect(suggestions72, contains(72.0)); // Exact
      expect(suggestions72, contains(100.0)); // 100 note
      expect(suggestions72, contains(200.0)); // 200 note
      expect(suggestions72, contains(500.0)); // 500 note

      // 3. Bill Total ₹1240
      pos.clearCart(syncWithBackend: false);
      pos.addToCart(ProductModel(id: '3', name: 'Ghee', price: 1240.0, stock: 10, category: 'Grocery'));
      expect(pos.grandTotal, 1240.0);

      final suggestions1240 = pos.getSmartCashSuggestions();
      expect(suggestions1240, contains(1240.0)); // Exact
      expect(suggestions1240, contains(1300.0)); // Round 100
      expect(suggestions1240, contains(1500.0)); // Round 500 step
      expect(suggestions1240, contains(2000.0)); // Round 500 / 2000 step
    });

    test('changeDue calculates exact return amount when customer gives more cash', () {
      pos.addToCart(ProductModel(id: '1', name: 'Item', price: 340.0, stock: 10, category: 'General'));
      pos.setPaymentMethod('cash');

      // Customer gives ₹500 note
      pos.setCashTendered(500.0);
      expect(pos.changeDue, 160.0);
      expect(pos.cashShortage, 0.0);

      // Customer gives exact ₹340
      pos.setCashTendered(340.0);
      expect(pos.changeDue, 0.0);
      expect(pos.cashShortage, 0.0);
    });

    test('cashShortage calculates exact remaining due when customer gives less cash', () {
      pos.addToCart(ProductModel(id: '1', name: 'Item', price: 340.0, stock: 10, category: 'General'));
      pos.setPaymentMethod('cash');

      // Customer gives ₹200 cash for ₹340 bill
      pos.setCashTendered(200.0);
      expect(pos.changeDue, 0.0);
      expect(pos.cashShortage, 140.0);
    });

    test('Split payment mode computes Cash and UPI balances correctly', () {
      pos.addToCart(ProductModel(id: '1', name: 'Item', price: 500.0, stock: 10, category: 'General'));
      pos.setPaymentMethod('split');

      // Customer pays ₹200 cash, remaining should be ₹300 UPI
      pos.setSplitCashAmount(200.0);
      expect(pos.splitCashAmount, 200.0);
      expect(pos.splitUpiAmount, 300.0);

      // Customer pays ₹450 cash, remaining should be ₹50 UPI
      pos.setSplitCashAmount(450.0);
      expect(pos.splitUpiAmount, 50.0);
    });

    test('PosSplitPayment serialization and deserialization', () {
      const split = PosSplitPayment(cashAmount: 200.0, onlineAmount: 140.0, khataAmount: 0.0);
      final json = split.toJson();
      expect(json['cash_amount'], 200.0);
      expect(json['online_amount'], 140.0);
      expect(json['khata_amount'], 0.0);

      final fromJson = PosSplitPayment.fromJson(json);
      expect(fromJson.cashAmount, 200.0);
      expect(fromJson.onlineAmount, 140.0);
      expect(fromJson.khataAmount, 0.0);
    });

    testWidgets('PosScreen desktop/wide checkout renders Split and Cash change return cards without error', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final langCtrl = LanguageController();
      final authCtrl = AuthController();

      pos.addToCart(ProductModel(id: '1', name: 'Dove Shampoo', price: 175.0, stock: 20, category: 'Personal Care'));
      pos.setPaymentMethod('cash');
      pos.setCashTendered(500.0);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
            ChangeNotifierProvider<AuthController>.value(value: authCtrl),
            ChangeNotifierProvider<PosController>.value(value: pos),
          ],
          child: const MaterialApp(
            home: PosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Payment Mode Chips exist
      expect(find.text('💵 Cash'), findsOneWidget);
      expect(find.text('📱 UPI QR'), findsOneWidget);
      expect(find.text('⚡ Split (Cash+UPI)'), findsOneWidget);
      expect(find.text('📖 Khata Udhar'), findsOneWidget);

      // 2. Verify Return Change Card is displayed
      expect(find.text('🟢 Return to Customer (Change):'), findsOneWidget);
      expect(find.text('₹325'), findsOneWidget); // 500 - 175 = 325

      // 3. Switch to Split Payment
      pos.setPaymentMethod('split');
      await tester.pumpAndSettle();

      expect(find.text('⚡ Split Settlement (Cash + UPI):'), findsOneWidget);
      expect(find.text('1. Cash Portion:'), findsOneWidget);
      expect(find.text('2. UPI Portion:'), findsOneWidget);

      langCtrl.dispose();
      authCtrl.dispose();
    });
  });
}
