import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/features/dashboard/controllers/dashboard_controller.dart';
import 'package:flutter_project_structure/features/dashboard/models/shop_model.dart';
import 'package:flutter_project_structure/features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter_project_structure/features/reservations/controllers/reservation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardScreen Clean & Simple UI Tests', () {
    late AuthController authCtrl;
    late DashboardController dashCtrl;
    late ReservationController resCtrl;
    late LanguageController langCtrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();

      authCtrl = AuthController();
      authCtrl.setShopForTesting(
        ShopModel(
          id: 'shop-1',
          name: 'ShopSilo Supermarket',
          slug: 'shopsilo-supermarket',
          category: 'Grocery',
          isOpen: true,
          phone: '9876543210',
          address: 'Main Market, Road 4',
        ),
      );

      dashCtrl = DashboardController();
      resCtrl = ReservationController();
      langCtrl = LanguageController();
    });

    testWidgets(
      'renders Store Identity Card, QR button, and Price Checker cleanly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));

        await tester.pumpWidget(
          ProviderScope(
            child: provider.MultiProvider(
              providers: [
                provider.ChangeNotifierProvider<AuthController>.value(
                  value: authCtrl,
                ),
                provider.ChangeNotifierProvider<DashboardController>.value(
                  value: dashCtrl,
                ),
                provider.ChangeNotifierProvider<ReservationController>.value(
                  value: resCtrl,
                ),
                provider.ChangeNotifierProvider<LanguageController>.value(
                  value: langCtrl,
                ),
              ],
              child: const MaterialApp(home: DashboardScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Store name
        expect(find.text('ShopSilo Supermarket'), findsWidgets);

        // Verified badge icon
        expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

        // Live online status
        expect(find.textContaining('Live Online'), findsOneWidget);

        // Price checker tool
        expect(
          find.textContaining('Instant Price & Stock Checker'),
          findsOneWidget,
        );

        // QR Code button
        expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
      },
    );

    testWidgets('fits mobile, tablet, and desktop viewports without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      await tester.pumpWidget(
        ProviderScope(
          child: provider.MultiProvider(
            providers: [
              provider.ChangeNotifierProvider<AuthController>.value(
                value: authCtrl,
              ),
              provider.ChangeNotifierProvider<DashboardController>.value(
                value: dashCtrl,
              ),
              provider.ChangeNotifierProvider<ReservationController>.value(
                value: resCtrl,
              ),
              provider.ChangeNotifierProvider<LanguageController>.value(
                value: langCtrl,
              ),
            ],
            child: const MaterialApp(home: DashboardScreen()),
          ),
        ),
      );

      for (final size in const [
        Size(320, 640),
        Size(768, 900),
        Size(1200, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Viewport: $size');
      }
    });
  });
}
