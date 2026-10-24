import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../services/offline_sync_service.dart';
import '../storage/token_storage.dart';
import 'app_ui_components.dart';
import 'offline_sync_sheet.dart';

class MerchantDrawer extends StatelessWidget {
  final Function(String shopSlug, String shopName)? onShowQr;

  const MerchantDrawer({
    super.key,
    this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final shop = authController.currentShop;

    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Merchant Owner';
    final userEmailPhone = (user?.email.isNotEmpty == true)
        ? user!.email
        : ((user?.phone.isNotEmpty == true) ? user!.phone : 'merchant@shopsilo.in');
    final hasShop = shop != null && shop.id.toString().isNotEmpty;
    final shopName = hasShop && shop.name != 'ShopSilo Store'
        ? shop.name
        : (context.isHindi ? 'दुकान सेटअप करें' : 'Setup Store');

    return Drawer(
      backgroundColor: context.colorSurface,
      child: SafeArea(
        child: Column(
          children: [
            // Top User Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colorSurfaceSubtle,
                border: Border(
                  bottom: BorderSide(color: context.colorBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl ?? shop?.logoUrl,
                    name: userName,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$shopName • $userEmailPhone',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Important Functions Section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        context.tr('dash_section_actions'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.colorTextMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _DrawerTile(
                      icon: Icons.dashboard_rounded,
                      title: context.tr('nav_home'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.point_of_sale_rounded,
                      title: context.tr('nav_billing'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant/pos');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.history_toggle_off_rounded,
                      title: context.tr('today_sales_title'),
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveLastRoute('/merchant/today-sales');
                        context.go('/merchant/today-sales');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.inventory_2_rounded,
                      title: context.tr('nav_inventory'),
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(2);
                        TokenStorage.saveLastRoute('/merchant/inventory');
                        context.go('/merchant/inventory');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.menu_book_rounded,
                      title: context.tr('nav_khata'),
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(3);
                        TokenStorage.saveLastRoute('/merchant/khata');
                        context.go('/merchant/khata');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.receipt_long_rounded,
                      title: context.tr('nav_expenses'),
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(4);
                        TokenStorage.saveLastRoute('/merchant/expenses');
                        context.go('/merchant/expenses');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.local_offer_rounded,
                      title: 'Offers & Promotions',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveLastRoute('/merchant/offers');
                        context.go('/merchant/offers');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.insights_rounded,
                      title: 'Munafa & Analytics',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveLastRoute('/merchant/analytics');
                        context.go('/merchant/analytics');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.assignment_rounded,
                      title: 'Mandi Procurement List',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveLastRoute('/merchant/procurement');
                        context.go('/merchant/procurement');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.shopping_bag_rounded,
                      title: 'Customer Pickup Orders',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveLastRoute('/merchant/reservations');
                        context.go('/merchant/reservations');
                      },
                    ),
                    StreamBuilder<int>(
                      stream: OfflineSyncService.instance.pendingCountStream,
                      initialData: OfflineSyncService.instance.pendingCount,
                      builder: (ctx, snapshot) {
                        final pending = snapshot.data ?? 0;
                        return _DrawerTile(
                          icon: pending > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                          title: context.isHindi ? 'ऑफ़लाइन क्लाउड सिंक' : 'Offline Cloud Sync',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pending > 0 ? AppColors.warning : AppColors.success,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pending > 0 ? '$pending' : '✓',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            OfflineSyncSheet.show(context);
                          },
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 16, color: context.colorBorder),
                    ),
                    _DrawerTile(
                      icon: Icons.settings_outlined,
                      title: context.tr('nav_settings'),
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(5);
                        TokenStorage.saveLastRoute('/merchant/profile');
                        context.go('/merchant/profile');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Logout Button at Bottom
            Divider(height: 1, color: context.colorBorder),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: context.colorSurfaceSubtle,
                leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                title: Text(
                  context.tr('btn_logout'),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await authController.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colorTextPrimary,
          ),
        ),
        trailing: trailing,
        dense: true,
        visualDensity: VisualDensity.compact,
        onTap: onTap,
      ),
    );
  }
}
