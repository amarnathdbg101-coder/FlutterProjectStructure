import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/copilot/controllers/copilot_controller.dart';
import 'package:flutter_project_structure/features/copilot/models/copilot_model.dart';
import 'package:flutter_project_structure/features/copilot/widgets/morning_action_brief_widget.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();
    await LocalCacheService.clearCache();
  });

  group('Copilot Models & Logic Tests', () {
    test('DailyPrescriptionModel accurately deserializes and serializes', () {
      final json = {
        'id': 'rx_101',
        'shop_id': 'shop_99',
        'urgency_tier': 'URGENT_CASH',
        'category': 'DEAD_STOCK',
        'headline': '4 Dead Stock Kurtis Blocking ₹3,200',
        'explanation': 'Launch clearance combo to recover liquid cash.',
        'financial_impact_inr': 3200.0,
        'executable_action_type': 'CLEAR_STOCK',
        'action_payload': {'suggested_off': '25%'},
        'is_executed': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final model = DailyPrescriptionModel.fromJson(json);
      expect(model.id, 'rx_101');
      expect(model.urgencyTier, 'URGENT_CASH');
      expect(model.financialImpactINR, 3200.0);
      expect(model.isExecuted, false);

      final updated = model.copyWith(isExecuted: true);
      expect(updated.isExecuted, true);
    });

    test('BargainEvaluationModel accurately handles negotiation verdict', () {
      final json = {
        'product_id': 'prod_45',
        'product_name': 'Anti-Aging Night Gel',
        'original_price': 1400.0,
        'customer_offered_price': 900.0,
        'cost_price': 850.0,
        'hard_floor_price': 952.0,
        'is_acceptable': false,
        'suggested_counter_offer': 975.0,
        'net_profit_inr': 125.0,
        'inventory_age_days': 84,
        'abc_tier': 'C',
        'xyz_tier': 'Z',
        'customer_rfm': 'REGULAR',
        'sales_script': 'Bhaiya ₹975 me final kijiye.',
        'warning_message': 'Offer below safe floor price',
      };

      final eval = BargainEvaluationModel.fromJson(json);
      expect(eval.isAcceptable, false);
      expect(eval.suggestedCounterOffer, 975.0);
      expect(eval.warningMessage, 'Offer below safe floor price');
    });

    test('SubstituteRecommendationModel parses attribute matches correctly', () {
      final json = {
        'product_id': 'sub_88',
        'product_name': 'Mustard Yellow Festive Kurti',
        'category_name': 'Clothing',
        'current_stock': 5,
        'mrp': 899.0,
        'offer_price': 799.0,
        'shop_profit_margin': 42.5,
        'match_score': 0.95,
        'is_exact_match': false,
        'matched_attributes': ['yellow', 'haldi', 'pure_cotton'],
        'sales_pitch_script': 'Haldi me chamak aayegi aur pure cotton blend hai.',
      };

      final sub = SubstituteRecommendationModel.fromJson(json);
      expect(sub.isExactMatch, false);
      expect(sub.shopProfitMargin, 42.5);
      expect(sub.matchedAttributes.length, 3);
      expect(sub.salesPitchScript, contains('Haldi'));
    });
  });

  group('MorningActionBriefWidget Widget Test', () {
    testWidgets('Renders Morning 3-Action Brief cards without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyPrescriptions = [
        DailyPrescriptionModel(
          id: 'rx_1',
          shopId: 'shop_1',
          urgencyTier: 'URGENT_CASH',
          category: 'DEAD_STOCK',
          headline: '3 Dead Stock Items Blocking ₹4,500 Cash',
          explanation: 'Launch 1-tap clearance combo to recover liquid cash.',
          financialImpactINR: 4500.0,
          executableActionType: 'CLEAR_STOCK',
          actionPayload: const {},
          createdAt: DateTime.now(),
        ),
        DailyPrescriptionModel(
          id: 'rx_2',
          shopId: 'shop_1',
          urgencyTier: 'STOCKOUT_CRITICAL',
          category: 'REORDER',
          headline: 'Stockout Alert: Tata Salt Running Out',
          explanation: 'Reorder 2 cartons from Wholesaler Ramesh.',
          financialImpactINR: 8000.0,
          executableActionType: 'SEND_PO',
          actionPayload: const {},
          createdAt: DateTime.now(),
        ),
      ];

      await LocalCacheService.saveDailyPrescriptions(dummyPrescriptions);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageController()),
            ChangeNotifierProvider(create: (_) => CopilotController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MorningActionBriefWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Store Co-Pilot'), findsOneWidget);
      expect(find.textContaining('3 Dead Stock Items'), findsOneWidget);
      expect(find.text('Stockout Alert: Tata Salt Running Out'), findsOneWidget);
      expect(find.text('Apply Now'), findsNWidgets(2));
    });
  });
}
