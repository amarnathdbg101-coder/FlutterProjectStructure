import 'package:go_router/go_router.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/customer_shop_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/profile_screen.dart';
import '../../features/expenses/screens/expense_screen.dart';
import '../../features/khata/screens/khata_screen.dart';
import '../../features/offers/screens/offers_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/screens/today_sales_screen.dart';
import '../../features/procurement/screens/procurement_list_screen.dart';
import '../../features/products/screens/inventory_screen.dart';

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
  static const String profile = '/merchant/profile';
  static const String customerShop = '/shop/:slug';
}

final GoRouter appRouter = GoRouter(
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
    GoRoute(
      path: AppRoutes.merchant,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.todaySales,
      builder: (context, state) => const TodaySalesScreen(),
    ),
    GoRoute(
      path: AppRoutes.pos,
      builder: (context, state) => const PosScreen(),
    ),
    GoRoute(
      path: AppRoutes.inventory,
      builder: (context, state) => const InventoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.khata,
      builder: (context, state) => const KhataScreen(),
    ),
    GoRoute(
      path: AppRoutes.expenses,
      builder: (context, state) => const ExpenseScreen(),
    ),
    GoRoute(
      path: AppRoutes.offers,
      builder: (context, state) => const OffersScreen(),
    ),
    GoRoute(
      path: AppRoutes.analytics,
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: AppRoutes.procurement,
      builder: (context, state) => const ProcurementListScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.customerShop,
      builder: (context, state) => CustomerShopScreen(
        slug: state.pathParameters['slug'] ?? '',
      ),
    ),
  ],
);
