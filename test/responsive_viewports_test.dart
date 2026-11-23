import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/widgets/merchant_shell.dart';
import 'package:flutter_project_structure/features/copilot/controllers/copilot_controller.dart';
import 'package:flutter_project_structure/features/copilot/models/copilot_model.dart';
import 'package:flutter_project_structure/features/copilot/widgets/morning_action_brief_widget.dart';
import 'package:flutter_project_structure/features/copilot/widgets/negotiation_advisor_dialog.dart';
import 'package:flutter_project_structure/features/copilot/widgets/substitute_finder_sheet.dart';
import 'package:flutter_project_structure/features/pos/controllers/pos_controller.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();
    await LocalCacheService.clearCache();
  });

  final testPrescriptions = [
    DailyPrescriptionModel(
      id: 'rx_fast_1',
      shopId: 'shop_1',
      urgencyTier: 'CRITICAL_STOCKOUT',
      category: 'FAST_MOVER',
      headline: 'Haldi Yellow Saree Running Out of Stock (3 Days Left)',
      explanation: 'Predicted stockout in 72h based on current sales velocity. Reorder 20 units.',
      financialImpactINR: 12000.0,
      executableActionType: 'REORDER_STOCK',
      actionPayload: {'recommended_units': 20},
      isExecuted: false,
      createdAt: DateTime.now(),
    ),
    DailyPrescriptionModel(
      id: 'rx_dead_2',
      shopId: 'shop_1',
      urgencyTier: 'URGENT_CASH',
      category: 'DEAD_STOCK',
      headline: '4 Silk Kurtis Blocking ₹4,800 Capital (62 Days Old)',
      explanation: 'Holding carrying cost: ₹72/month. Apply 15% clearance combo to liquidate.',
      financialImpactINR: 4800.0,
      executableActionType: 'CLEAR_STOCK',
      actionPayload: {'discount_pct': 15},
      isExecuted: false,
      createdAt: DateTime.now(),
    ),
  ];

  final testProduct = ProductModel(
    id: 'prod_test_1',
    name: 'Bansiwala Chand Siroski Saree - Haldi Yellow',
    price: 1199.0,
    costPrice: 750.0,
    stock: 18,
    category: 'Clothing & Fashion',
    sku: 'SKU_SAR_01',
    barcode: '8901234567890',
  );

  final testCartItem = PosCartItem(product: testProduct, quantity: 1);

  final viewports = [
    {'name': 'Ultra-Compact Mobile (320x568)', 'size': const Size(320, 568)},
    {'name': 'Standard Mobile (390x844)', 'size': const Size(390, 844)},
    {'name': 'Tablet Portrait (768x1024)', 'size': const Size(768, 1024)},
    {'name': 'Tablet Landscape (1024x768)', 'size': const Size(1024, 768)},
    {'name': 'Laptop / Desktop Web (1440x900)', 'size': const Size(1440, 900)},
    {'name': 'Full HD Desktop / Web (1920x1080)', 'size': const Size(1920, 1080)},
  ];

  for (final vp in viewports) {
    final vpName = vp['name'] as String;
    final vpSize = vp['size'] as Size;

    testWidgets('MorningActionBriefWidget renders smoothly on $vpName without overflows', (tester) async {
      tester.view.physicalSize = vpSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await LocalCacheService.saveDailyPrescriptions(testPrescriptions);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageController()),
            ChangeNotifierProvider(create: (_) => CopilotController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: MorningActionBriefWidget(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      // Verify no RenderFlex exception occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(MorningActionBriefWidget), findsOneWidget);
    });

    testWidgets('NegotiationAdvisorDialog renders adaptively on $vpName', (tester) async {
      tester.view.physicalSize = vpSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final posController = PosController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageController()),
            ChangeNotifierProvider(create: (_) => CopilotController()),
            ChangeNotifierProvider.value(value: posController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: NegotiationAdvisorDialog(
                  item: testCartItem,
                  pos: posController,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(find.byType(NegotiationAdvisorDialog), findsOneWidget);
    });

    testWidgets('SubstituteFinderSheet renders cleanly on $vpName', (tester) async {
      tester.view.physicalSize = vpSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final posController = PosController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageController()),
            ChangeNotifierProvider(create: (_) => CopilotController()),
            ChangeNotifierProvider.value(value: posController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SubstituteFinderSheet(
                pos: posController,
                initialQuery: 'Saree',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(find.byType(SubstituteFinderSheet), findsOneWidget);
    });

    testWidgets('MerchantShell adapts navigation layout on $vpName', (tester) async {
      tester.view.physicalSize = vpSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageController()),
          ],
          child: const MaterialApp(
            home: MerchantShell(
              currentIndex: 0,
              showBottomNav: true,
              child: Center(child: Text('Dashboard Content')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final isDesktop = vpSize.width >= 850;
      if (isDesktop) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.text('Dashboard Content'), findsOneWidget);
      }
    });
  }
}
