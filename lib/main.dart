import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/localization/language_controller.dart';
import 'core/routes/app_router.dart';
import 'core/services/audio_haptic_service.dart';
import 'core/services/counter_websocket_service.dart';
import 'core/storage/local_cache_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/offline_status_banner.dart';
import 'features/analytics/controllers/analytics_controller.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/dashboard/controllers/dashboard_controller.dart';
import 'features/expenses/controllers/expense_controller.dart';
import 'features/khata/controllers/khata_controller.dart';
import 'features/khata/controllers/micro_plan_controller.dart';
import 'features/offers/controllers/offer_controller.dart';
import 'features/pos/controllers/cash_drawer_controller.dart';
import 'features/pos/controllers/hotkey_controller.dart';
import 'features/pos/controllers/pos_controller.dart';
import 'features/procurement/controllers/procurement_controller.dart';
import 'features/products/controllers/batch_expiry_controller.dart';
import 'features/products/controllers/category_controller.dart';
import 'features/products/controllers/product_controller.dart';
import 'features/reservations/controllers/reservation_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();
  await LocalCacheService.init();

  // Global Flutter framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log details to developer console for debugging without interrupting merchant screen navigation
    FlutterError.presentError(details);
  };

  // Global asynchronous platform and Dart exception handling
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ShopSilo Platform Error] $error');
    // Suppress background async error toasts so users are not spammed with network retry warnings
    return true;
  };

  if (TokenStorage.hasToken()) {
    CounterWebSocketService.instance.connect();
  }

  CounterWebSocketService.instance.onNewReservationNotification = (payload) {
    // 1. Play tactile haptic pulse and physical audible alert
    AppAudioHapticFeedback.orderAlert();

    final pickupCode = payload['pickup_code']?.toString() ?? '4812';
    final customerName = payload['customer_name']?.toString() ?? 'Customer';
    final productName = payload['product_name']?.toString() ?? 'Pickup Item';
    final qty = payload['quantity']?.toString() ?? '1';

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 10),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 New Pickup Order (#$pickupCode)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  Text(
                    '$customerName • $productName (Qty: $qty)',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: AppColors.primary,
          onPressed: () {
            appRouter.go('/merchant/reservations');
          },
        ),
      ),
    );
  };

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LanguageController()),
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => DashboardController()),
          ChangeNotifierProvider(create: (_) => PosController()),
          ChangeNotifierProvider(create: (_) => CashDrawerController()),
          ChangeNotifierProvider(create: (_) => HotkeyController()),
          ChangeNotifierProvider(create: (_) => BatchExpiryController()),
          ChangeNotifierProvider(create: (_) => ProductController()),
          ChangeNotifierProvider(create: (_) => CategoryController()),
          ChangeNotifierProvider(create: (_) => KhataController()),
          ChangeNotifierProvider(create: (_) => MicroPlanController()),
          ChangeNotifierProvider(create: (_) => ExpenseController()),
          ChangeNotifierProvider(create: (_) => OfferController()),
          ChangeNotifierProvider(create: (_) => AnalyticsController()),
          ChangeNotifierProvider(create: (_) => ProcurementController()),
          ChangeNotifierProvider(create: (_) => ReservationController()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeMode themeMode = ThemeMode.system;
    try {
      themeMode = Provider.of<ThemeController>(context, listen: true).themeMode;
    } catch (_) {
      themeMode = ThemeMode.system;
    }

    // Rebuild app automatically when user switches language
    try {
      Provider.of<LanguageController>(context, listen: true);
    } catch (_) {}

    return MaterialApp.router(
      title: 'ShopSilo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      scrollBehavior: AppScrollBehavior(),
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: OfflineStatusOverlay(child: child),
        );
      },
    );
  }
}
