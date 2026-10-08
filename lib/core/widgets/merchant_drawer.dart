import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import 'app_ui_components.dart';
import 'language_selector_dialog.dart';

class MerchantDrawer extends StatelessWidget {
  final Function(String shopSlug, String shopName)? onShowQr;

  const MerchantDrawer({
    super.key,
    this.onShowQr,
  });

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(20),
        child: LanguageSelectorCard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final langController = context.watch<LanguageController>();
    final user = authController.currentUser;
    final shop = authController.currentShop;

    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Merchant Owner';
    final userEmailPhone = (user?.email.isNotEmpty == true)
        ? user!.email
        : ((user?.phone.isNotEmpty == true) ? user!.phone : 'merchant@shopsilo.in');
    final shopName = shop?.name ?? 'ShopSilo Store';
    final shopCategory = shop?.category ?? 'General Retail';
    final shopSlug = shop?.slug ?? 'store';
    final isOpen = shop?.isOpen ?? true;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Top User Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmailPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            AppBadge(
                              label: shopCategory,
                              type: AppBadgeType.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOpen ? AppColors.success : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOpen ? context.tr('dash_status_open') : context.tr('dash_status_closed'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isOpen ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: isOpen,
                                activeThumbColor: AppColors.success,
                                onChanged: (val) {
                                  authController.toggleShopStatus(val);
                                },
                              ),
                            ),
                          ],
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
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
                      icon: Icons.inventory_2_rounded,
                      title: context.tr('nav_inventory'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant/inventory');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.menu_book_rounded,
                      title: context.tr('nav_khata'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant/khata');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.receipt_long_rounded,
                      title: context.tr('nav_expenses'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant/expenses');
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 16),
                    ),
                    _DrawerTile(
                      icon: Icons.qr_code_2_rounded,
                      title: context.tr('dash_dialog_qr_title'),
                      onTap: () {
                        Navigator.pop(context);
                        if (onShowQr != null) {
                          onShowQr!(shopSlug, shopName);
                        }
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.language_rounded,
                      title: '${context.tr('settings_language_title')} (${langController.currentLanguage == AppLanguage.hindi ? 'हिन्दी' : 'EN'})',
                      onTap: () {
                        Navigator.pop(context);
                        _showLanguageBottomSheet(context);
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.settings_outlined,
                      title: context.tr('nav_settings'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/merchant/profile');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Logout Button at Bottom
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: AppColors.surfaceSubtle,
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
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }
}
