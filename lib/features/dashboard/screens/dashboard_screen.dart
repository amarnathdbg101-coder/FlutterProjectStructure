import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/merchant_drawer.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../../core/services/data_sync_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../models/shop_model.dart';
import '../../reservations/controllers/reservation_controller.dart';
import '../widgets/dashboard_price_checker_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataSyncService().runBackgroundSync(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authController = context.watch<AuthController>();
    final dashController = context.watch<DashboardController>();
    final resController = context.watch<ReservationController>();
    final shop = authController.currentShop;
    final stats = dashController.stats;

    final shopName = shop?.name ?? (context.isHindi ? 'मेरी दुकान' : 'My Store');

    return MerchantShell(
      currentIndex: 0,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: context.colorBorder,
            height: 1.0,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: ctx.colorTextPrimary, size: 24),
            tooltip: ctx.tr('dash_section_actions'),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          shopName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      drawer: MerchantDrawer(
        onShowQr: (slug, name) => showStoreQrDialog(context, shop),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await authController.fetchShopDetails();
          await dashController.fetchDashboardData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Store Identity & Status Card
                if (shop != null && shop.id.toString().isNotEmpty) ...[
                  _StoreIdentityCard(shop: shop, authController: authController),
                  const SizedBox(height: 18),
                ] else ...[
                  _IncompleteStoreCard(),
                  const SizedBox(height: 18),
                ],

                // 2. Real-Time Counter Pickup Orders Waiting Alert (if any pending)
                if (resController.activeCount > 0) ...[
                  AppSummaryBanner(
                    title: context.isHindi ? 'सक्रिय काउंटर पिकअप ऑर्डर्स' : 'Active Counter Pickup Orders',
                    amount: '${resController.activeCount} ${context.isHindi ? 'लंबित' : 'Pending'}',
                    subtitle: context.isHindi
                        ? 'ग्राहक काउंटर पर सामान लेने के लिए प्रतीक्षारत हैं'
                        : 'Customer awaiting pickup at your counter',
                    icon: Icons.shopping_bag_rounded,
                    actionLabel: context.isHindi ? 'देखें एवं पैक करें' : 'View & Pack',
                    onAction: () => context.go('/merchant/reservations'),
                  ),
                  const SizedBox(height: 18),
                ],

                // 2.5 Quick Counter Tool: Instant Barcode & Search Price Checker
                const DashboardPriceCheckerCard(),
                const SizedBox(height: 18),

                // 3. Business Summary Metrics (KPI Cards)
                AppSectionHeader(title: context.tr('dash_section_summary')),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900 ? 4 : (width > 500 ? 2 : 2);
                    final aspectRatio = width < 380 ? 1.25 : (width < 600 ? 1.38 : (width > 900 ? 1.60 : 1.45));

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: aspectRatio,
                      children: [
                        AppStatCard(
                          title: context.tr('dash_kpi_sales'),
                          value: '₹${stats.todaySales.toStringAsFixed(0)}',
                          subtitle: '${stats.salesCount} ${context.tr('dash_kpi_bills')}',
                          icon: Icons.currency_rupee_rounded,
                          iconColor: AppColors.success,
                          iconBgColor: context.colorSuccessLight,
                          onTap: () => context.go('/merchant/today-sales'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_udhar'),
                          value: '₹${stats.totalUdhar.toStringAsFixed(0)}',
                          subtitle: '${stats.udharCustomersCount} ${context.tr('dash_kpi_debtors')}',
                          icon: Icons.menu_book_rounded,
                          iconColor: AppColors.primary,
                          iconBgColor: context.colorPrimaryLight,
                          onTap: () => context.go('/merchant/khata'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_catalog'),
                          value: '${stats.catalogCount}',
                          subtitle: context.isHindi ? 'सक्रिय उत्पाद' : 'Active Products',
                          icon: Icons.inventory_2_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          onTap: () => context.go('/merchant/inventory'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_low_stock'),
                          value: '${stats.lowStockCount}',
                          subtitle: context.isHindi ? 'पुनर्प्राप्ति आवश्यक' : 'Reorder Needed',
                          icon: Icons.warning_amber_rounded,
                          iconColor: AppColors.warning,
                          iconBgColor: context.colorWarningLight,
                          isAlert: stats.lowStockCount > 0,
                          onTap: () => context.go('/merchant/low-stock'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),

                // 4. Primary Daily Quick Actions (Unified AppActionTile)
                AppSectionHeader(title: context.tr('dash_section_actions')),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 2);
                    final tileAspectRatio = width < 380 ? 2.15 : (width < 600 ? 2.35 : 2.6);

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: tileAspectRatio,
                      children: [
                        AppActionTile(
                          icon: Icons.point_of_sale_rounded,
                          title: context.tr('dash_action_pos'),
                          subtitle: context.tr('dash_action_pos_sub'),
                          onTap: () => context.go('/merchant/pos'),
                        ),
                        AppActionTile(
                          icon: Icons.inventory_2_rounded,
                          title: context.tr('dash_kpi_catalog'),
                          subtitle: context.tr('dash_action_product_sub'),
                          onTap: () => context.go('/merchant/inventory'),
                        ),
                        AppActionTile(
                          icon: Icons.menu_book_rounded,
                          title: context.tr('dash_khata_title'),
                          subtitle: context.tr('dash_action_khata_sub'),
                          onTap: () => context.go('/merchant/khata'),
                        ),
                        AppActionTile(
                          icon: Icons.receipt_long_rounded,
                          title: context.tr('dash_expenses_title'),
                          subtitle: context.tr('dash_action_expense_sub'),
                          onTap: () => context.go('/merchant/expenses'),
                        ),
                        AppActionTile(
                          icon: Icons.shopping_bag_rounded,
                          title: context.tr('dash_pickup_title'),
                          subtitle: context.isHindi ? 'काउंटर पिकअप ऑर्डर' : 'Counter Pickup Orders',
                          onTap: () => context.go('/merchant/reservations'),
                        ),
                        AppActionTile(
                          icon: Icons.analytics_rounded,
                          title: context.tr('dash_profit_title'),
                          subtitle: context.tr('dash_profit_sub'),
                          onTap: () => context.go('/merchant/analytics'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 5. Secondary Utility Links (Procurement & Deals)
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActionTile(
                        icon: Icons.store_mall_directory_rounded,
                        title: context.tr('dash_mandi_title'),
                        subtitle: context.tr('dash_mandi_sub'),
                        onTap: () => context.go('/merchant/procurement'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryActionTile(
                        icon: Icons.local_offer_rounded,
                        title: context.tr('dash_deals_title'),
                        subtitle: context.tr('dash_deals_sub'),
                        onTap: () => context.go('/merchant/offers'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek, modern, and uncluttered Store Identity Card
class _StoreIdentityCard extends StatelessWidget {
  final ShopModel shop;
  final AuthController authController;

  const _StoreIdentityCard({required this.shop, required this.authController});

  @override
  Widget build(BuildContext context) {
    final logoUrl = shop.logoUrl != null && shop.logoUrl!.isNotEmpty
        ? formatImageUrl(shop.logoUrl)
        : (shop.banners.isNotEmpty ? formatImageUrl(shop.banners.first) : null);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Store Logo / Avatar
          AppProductImage(
            imageUrl: logoUrl,
            width: 58,
            height: 58,
            borderRadius: BorderRadius.circular(12),
            fallbackIcon: Icons.storefront_rounded,
            fallbackIconSize: 28,
          ),
          const SizedBox(width: 12),

          // Store Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: context.colorTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Category & Online/Offline Status Toggle
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (shop.category.isNotEmpty)
                      AppBadge(
                        label: shop.category,
                        type: AppBadgeType.neutral,
                      ),
                    InkWell(
                      onTap: () async {
                        final newStatus = !shop.isOpen;
                        final ok = await authController.updateShop({'is_open': newStatus});
                        if (ok && context.mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            newStatus
                                ? (context.isHindi ? 'दुकान ऑनलाइन खुली है' : 'Store is OPEN Online')
                                : (context.isHindi ? 'दुकान ऑफ़लाइन बंद है' : 'Store is CLOSED Offline'),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AppBadge(
                        label: shop.isOpen
                            ? context.tr('profile_status_open')
                            : context.tr('profile_status_closed'),
                        type: shop.isOpen ? AppBadgeType.success : AppBadgeType.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Address
                if (shop.fullAddress.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.colorTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shop.fullAddress,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colorTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Secondary Action Tile for Procurement & Deals
class _SecondaryActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.colorSurfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.colorTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colorTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt card when store profile is not yet created
class _IncompleteStoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: context.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isHindi ? 'दुकान प्रोफाइल अभी अधूरी है' : 'Store Setup Incomplete',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.colorTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.isHindi
                          ? 'बिलिंग और उत्पाद जोड़ने के लिए अपनी दुकान प्रोफाइल बनाएं'
                          : 'Setup your store profile to enable billing, catalog and online presence',
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text(
                context.isHindi ? 'दुकान प्रोफाइल बनाएं' : 'Create Store Profile',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () => context.go('/merchant/profile'),
            ),
          ),
        ],
      ),
    );
  }
}
