import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import 'merchant_drawer.dart';
import 'shopsilo_logo.dart';

class MerchantShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;

  const MerchantShell({
    super.key,
    required this.child,
    required this.currentIndex,
    this.appBar,
    this.drawer,
  });

  void _onNavigate(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go('/merchant');
        break;
      case 1:
        context.go('/merchant/pos');
        break;
      case 2:
        context.go('/merchant/inventory');
        break;
      case 3:
        context.go('/merchant/khata');
        break;
      case 4:
        context.go('/merchant/expenses');
        break;
      case 5:
        context.go('/merchant/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;
    final effectiveDrawer = drawer ?? const MerchantDrawer();

    if (isDesktop) {
      // Desktop / Web Wide Layout with Side NavigationRail
      return Scaffold(
        appBar: appBar,
        drawer: effectiveDrawer,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex.clamp(0, 5),
              onDestinationSelected: (idx) => _onNavigate(context, idx),
              extended: screenWidth >= 1150,
              minExtendedWidth: 220,
              backgroundColor: context.colorSurface,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ShopSiloLogo(
                  size: 36,
                  showText: screenWidth >= 1150,
                  subtitle: screenWidth >= 1150 ? 'Partner OS' : null,
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_home')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.point_of_sale_outlined),
                  selectedIcon: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_billing')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_inventory')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_khata')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_expenses')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded, color: AppColors.primary),
                  label: Text(context.tr('nav_settings')),
                ),
              ],
            ),
            VerticalDivider(thickness: 1, width: 1, color: context.colorBorder),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile / Compact Layout with Telegram-Style Floating Rounded NavigationBar
    return Scaffold(
      appBar: appBar,
      drawer: effectiveDrawer,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: context.colorBorder.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  height: 64,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: context.colorPrimaryLight,
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: AppColors.primary, size: 20);
                    }
                    return IconThemeData(color: context.colorTextSecondary, size: 20);
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      );
                    }
                    return TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: context.colorTextSecondary,
                    );
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex.clamp(0, 3),
                onDestinationSelected: (idx) => _onNavigate(context, idx),
                elevation: 0,
                backgroundColor: Colors.transparent,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard_rounded),
                    label: context.tr('nav_home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.point_of_sale_outlined),
                    selectedIcon: const Icon(Icons.point_of_sale_rounded),
                    label: context.tr('nav_billing'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.inventory_2_outlined),
                    selectedIcon: const Icon(Icons.inventory_2_rounded),
                    label: context.tr('nav_inventory'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book_rounded),
                    label: context.tr('nav_khata'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
