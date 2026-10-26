import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/profile_screen.dart';
import '../../features/expenses/screens/expense_screen.dart';
import '../../features/khata/screens/khata_screen.dart';
import '../../features/offers/screens/offers_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/screens/today_sales_screen.dart';
import '../../features/procurement/screens/procurement_list_screen.dart';
import '../../features/products/screens/barcode_sheet_studio_screen.dart';
import '../../features/products/screens/inventory_screen.dart';
import '../../features/products/screens/low_stock_alerts_screen.dart';
import '../../features/reservations/screens/reservations_list_screen.dart';
import '../storage/token_storage.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String merchant = '/merchant';
  static const String todaySales = '/merchant/today-sales';
  static const String pos = '/merchant/pos';
  static const String inventory = '/merchant/inventory';
  static const String khata = '/merchant/khata';
  static const String expenses = '/merchant/expenses';
  static const String offers = '/merchant/offers';
  static const String analytics = '/merchant/analytics';
  static const String procurement = '/merchant/procurement';
  static const String lowStock = '/merchant/low-stock';
  static const String reservations = '/merchant/reservations';
  static const String barcodeStudio = '/merchant/barcode-studio';
  static const String profile = '/merchant/profile';
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),

    // Stateful IndexedStack Shell for the 6 Core Merchant Screens (Preserves tab state in memory!)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        TokenStorage.saveLastRoute(state.matchedLocation);
        return navigationShell;
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.merchant,
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.pos,
              builder: (context, state) => const PosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.inventory,
              builder: (context, state) => const InventoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.khata,
              builder: (context, state) => const KhataScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.expenses,
              builder: (context, state) => const ExpenseScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Secondary & feature routes with route preservation
    GoRoute(
      path: AppRoutes.todaySales,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.todaySales);
        return const TodaySalesScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.offers,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.offers);
        return const OffersScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.analytics,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.analytics);
        return const AnalyticsScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.procurement,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.procurement);
        return const ProcurementListScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.lowStock,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.lowStock);
        return const LowStockAlertsScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.reservations,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.reservations);
        return const ReservationsListScreen();
      },
    ),
    GoRoute(
      path: AppRoutes.barcodeStudio,
      builder: (context, state) {
        TokenStorage.saveLastRoute(AppRoutes.barcodeStudio);
        return const BarcodeSheetStudioScreen();
      },
    ),
  ],
);
