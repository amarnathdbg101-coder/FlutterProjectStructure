import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../storage/token_storage.dart';
import 'merchant_drawer.dart';
import 'shopsilo_logo.dart';

/// Professional Production Shell for ShopSilo Merchant OS.
/// Features:
/// 1. Unified Desktop & Mobile Navigation (Rail & Floating Bar)
/// 2. Enterprise Back Button Flow:
///    - On non-Home tabs (POS, Inventory, Khata, Expenses, Settings): System Back switches to Home tab (0).
///    - On Home tab: Double-tap within 2s to exit (prevents accidental app closure).
///    - On Secondary/Detail pages (when showBottomNav: false or currentIndex < 0): Smoothly pops back to previous screen.
class MerchantShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final bool showBottomNav;
  final Widget? floatingActionButton;

  // Track timestamp for double-back-to-exit on Home tab
  static DateTime? _lastBackPressTime;

  const MerchantShell({
    super.key,
    required this.child,
    required this.currentIndex,
    this.appBar,
    this.drawer,
    this.showBottomNav = true,
    this.floatingActionButton,
  });

  void _onNavigate(BuildContext context, int index) {
    if (index == currentIndex) return;
    TokenStorage.saveActiveTabIndex(index);
    switch (index) {
      case 0:
        TokenStorage.saveLastRoute('/merchant');
        context.go('/merchant');
        break;
      case 1:
        TokenStorage.saveLastRoute('/merchant/pos');
        context.go('/merchant/pos');
        break;
      case 2:
        TokenStorage.saveLastRoute('/merchant/inventory');
        context.go('/merchant/inventory');
        break;
      case 3:
        TokenStorage.saveLastRoute('/merchant/khata');
        context.go('/merchant/khata');
        break;
      case 4:
        TokenStorage.saveLastRoute('/merchant/expenses');
        context.go('/merchant/expenses');
        break;
      case 5:
        TokenStorage.saveLastRoute('/merchant/profile');
        context.go('/merchant/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;
    final effectiveDrawer = drawer ?? const MerchantDrawer();
    final isRootTab = showBottomNav && currentIndex >= 0;

    Widget scaffoldContent;

    if (isDesktop) {
      if (!showBottomNav || currentIndex < 0) {
        // Desktop full-width detail view without side rail
        scaffoldContent = Scaffold(
          appBar: appBar,
          drawer: effectiveDrawer,
          body: child,
          floatingActionButton: floatingActionButton,
        );
      } else {
        // Desktop / Web Wide Layout with Side NavigationRail
        scaffoldContent = Scaffold(
          appBar: appBar,
          drawer: effectiveDrawer,
          floatingActionButton: floatingActionButton,
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
    } else {
      // Mobile / Compact Layout with Floating Rounded NavigationBar
      scaffoldContent = Scaffold(
        appBar: appBar,
        drawer: effectiveDrawer,
        body: child,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: (showBottomNav && currentIndex >= 0)
            ? _buildMobileBottomNav(context)
            : null,
      );
    }

    // ------------------------------------------------------------------------
    // Enterprise PopScope Back Button Handling
    // ------------------------------------------------------------------------
    if (isRootTab) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;

          // 1. If currently on a sub-tab (POS, Inventory, Khata, Expenses, Profile), return to Home tab (0)
          if (currentIndex > 0) {
            _onNavigate(context, 0);
            return;
          }

          // 2. If on Home tab, require double-back within 2 seconds to exit app
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.isHindi
                      ? 'ऐप से बाहर जाने के लिए दोबारा बैक दबाएं'
                      : 'Press back again to exit',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        },
        child: scaffoldContent,
      );
    }

    // For secondary/detail screens (showBottomNav: false or currentIndex < 0):
    // Allow standard system pop to return to the calling screen
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: scaffoldContent,
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    return SafeArea(
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
              selectedIndex: currentIndex == 5 ? 4 : (currentIndex.clamp(0, 4)),
              onDestinationSelected: (idx) {
                final targetIdx = idx == 4 ? 5 : idx;
                _onNavigate(context, targetIdx);
              },
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
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: context.tr('nav_settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
