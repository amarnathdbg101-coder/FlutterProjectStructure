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
            // Top User & Store Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.colorTextPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$userName • $userEmailPhone',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Categorized Navigation Sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. OPERATIONS & SALES
                    _DrawerSectionHeader(
                      title: context.isHindi ? 'दैनिक व्यापार व बिक्री' : 'Operations & Sales',
                    ),
                    _DrawerTile(
                      icon: Icons.dashboard_rounded,
                      title: context.isHindi ? 'डैशबोर्ड' : 'Dashboard Overview',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(0);
                        context.go('/merchant');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.point_of_sale_rounded,
                      title: context.isHindi ? 'पीओएस बिलिंग काउंटर' : 'POS Billing Counter',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(1);
                        context.go('/merchant/pos');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.receipt_long_rounded,
                      title: context.isHindi ? 'आज की बिक्री रजिस्टर' : 'Today\'s Sales Register',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/today-sales');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.shopping_bag_rounded,
                      title: context.isHindi ? 'काउंटर पिकअप ऑर्डर' : 'Store Pickup Orders',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/reservations');
                      },
                    ),

                    _DrawerDivider(color: context.colorBorder),

                    // 2. INVENTORY & CATALOG
                    _DrawerSectionHeader(
                      title: context.isHindi ? 'स्टॉक व इन्वेंट्री' : 'Inventory & Stock',
                    ),
                    _DrawerTile(
                      icon: Icons.inventory_2_rounded,
                      title: context.isHindi ? 'सभी उत्पाद व इन्वेंट्री' : 'Product Inventory',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(2);
                        context.go('/merchant/inventory');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.price_check_rounded,
                      title: context.isHindi ? 'भाव व स्टॉक जांच' : 'Price & Stock Lookup',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/price-checker');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.warning_amber_rounded,
                      title: context.isHindi ? 'कम स्टॉक अलर्ट्स' : 'Low Stock Alerts',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/low-stock');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.print_rounded,
                      title: context.isHindi ? 'बारकोड प्रिंट स्टूडियो' : 'Barcode Print Studio',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/barcode-studio');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.local_shipping_rounded,
                      title: context.isHindi ? 'खरीद व सप्लायर ऑर्डर' : 'Purchase & Procurement',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/procurement');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.hourglass_bottom_rounded,
                      title: context.isHindi ? 'बैच व एक्सपायरी ट्रैकर' : 'Batch & Expiry Tracker',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/batch-expiry');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.assignment_return_rounded,
                      title: context.isHindi ? 'डैमेज व रिटर्न क्लेम' : 'Damage & Return Claims',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/damage-claims');
                      },
                    ),

                    _DrawerDivider(color: context.colorBorder),

                    // 3. FINANCE & ACCOUNTS
                    _DrawerSectionHeader(
                      title: context.isHindi ? 'खाता व हिसाब-किताब' : 'Finance & Accounts',
                    ),
                    _DrawerTile(
                      icon: Icons.menu_book_rounded,
                      title: context.isHindi ? 'ग्राहक खाता (उधार बही)' : 'Customer Credit Khata',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(3);
                        context.go('/merchant/khata');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: context.isHindi ? 'दुकान खर्च प्रबंधन' : 'Expense Management',
                      onTap: () {
                        Navigator.pop(context);
                        TokenStorage.saveActiveTabIndex(4);
                        context.go('/merchant/expenses');
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.insights_rounded,
                      title: context.isHindi ? 'व्यापार रिपोर्ट व एनालिटिक्स' : 'Business Reports & Analytics',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/analytics');
                      },
                    ),

                    _DrawerDivider(color: context.colorBorder),

                    // 4. MARKETING & PROMOTIONS
                    _DrawerSectionHeader(
                      title: context.isHindi ? 'ऑफ़र्स व प्रोमोशन' : 'Offers & Promotions',
                    ),
                    _DrawerTile(
                      icon: Icons.local_offer_rounded,
                      title: context.isHindi ? 'ऑफ़र्स व डिस्काउंट' : 'Discounts & Promotions',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/merchant/offers');
                      },
                    ),

                    _DrawerDivider(color: context.colorBorder),

                    // 5. SYSTEM & SETTINGS
                    _DrawerSectionHeader(
                      title: context.isHindi ? 'सिस्टम व सेटिंग्स' : 'System & Settings',
                    ),
                    StreamBuilder<int>(
                      stream: OfflineSyncService.instance.pendingCountStream,
                      initialData: OfflineSyncService.instance.pendingCount,
                      builder: (ctx, snapshot) {
                        final pending = snapshot.data ?? 0;
                        return _DrawerTile(
                          icon: pending > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
                          title: context.isHindi ? 'क्लाउड डेटा सिंक' : 'Offline Cloud Sync',
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
                                fontSize: 10.5,
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
                    _DrawerTile(
                      icon: Icons.storefront_rounded,
                      title: context.isHindi ? 'दुकान प्रोफ़ाइल व सेटिंग्स' : 'Store Profile & Settings',
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

class _DrawerSectionHeader extends StatelessWidget {
  final String title;

  const _DrawerSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: context.colorTextMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  final Color color;

  const _DrawerDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Divider(height: 1, thickness: 0.8, color: color),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.colorTextPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
