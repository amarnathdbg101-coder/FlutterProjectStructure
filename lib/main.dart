import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/localization/language_controller.dart';
import 'core/routes/app_router.dart';
import 'core/storage/local_cache_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/analytics/controllers/analytics_controller.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/dashboard/controllers/dashboard_controller.dart';
import 'features/expenses/controllers/expense_controller.dart';
import 'features/khata/controllers/khata_controller.dart';
import 'features/offers/controllers/offer_controller.dart';
import 'features/pos/controllers/pos_controller.dart';
import 'features/procurement/controllers/procurement_controller.dart';
import 'features/products/controllers/product_controller.dart';
import 'features/reservations/controllers/reservation_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();
  await LocalCacheService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LanguageController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => PosController()),
        ChangeNotifierProvider(create: (_) => ProductController()),
        ChangeNotifierProvider(create: (_) => KhataController()),
        ChangeNotifierProvider(create: (_) => ExpenseController()),
        ChangeNotifierProvider(create: (_) => OfferController()),
        ChangeNotifierProvider(create: (_) => AnalyticsController()),
        ChangeNotifierProvider(create: (_) => ProcurementController()),
        ChangeNotifierProvider(create: (_) => ReservationController()),
      ],
      child: const MyApp(),
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
          child: child,
        );
      },
    );
  }
}
