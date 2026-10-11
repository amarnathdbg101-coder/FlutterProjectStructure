import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_drawer.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../../core/services/data_sync_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../models/shop_model.dart';
import '../../reservations/controllers/reservation_controller.dart';

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

    final shopName = shop?.name ?? 'ShopSilo Store';

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
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppColors.primary),
            tooltip: 'Store QR Code',
            onPressed: () => showStoreQrDialog(context, shop),
          ),
          const SizedBox(width: 4),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Clean Read-Only Shop Showcase Card with 3s Auto-Swapping Carousel
                if (shop != null) ...[
                  _ShopShowcaseCard(shop: shop, authController: authController),
                  const SizedBox(height: 20),
                ],

                // Real-Time Counter Pickup Orders Waiting Banner
                if (resController.activeCount > 0) ...[
                  AppSummaryBanner(
                    title: 'Active Counter Pickup Orders',
                    amount: '${resController.activeCount} Pending',
                    subtitle: 'Customer arrived or awaiting pickup at your counter',
                    icon: Icons.shopping_bag_rounded,
                    actionLabel: 'View & Pack',
                    onAction: () => context.go('/merchant/reservations'),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. KPI Financial & Operational Grid ("Today's Business Summary")
                AppSectionHeader(title: context.tr('dash_section_summary')),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900 ? 4 : (width > 500 ? 2 : 2);
                    final aspectRatio = width < 380 ? 1.25 : (width > 900 ? 1.5 : 1.38);

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
                          onTap: () => context.go('/merchant/today-sales'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_udhar'),
                          value: '₹${stats.totalUdhar.toStringAsFixed(0)}',
                          subtitle: '${stats.udharCustomersCount} ${context.tr('dash_kpi_debtors')}',
                          icon: Icons.menu_book_rounded,
                          onTap: () => context.go('/merchant/khata'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_catalog'),
                          value: '${stats.catalogCount}',
                          subtitle: context.tr('dash_kpi_catalog'),
                          icon: Icons.inventory_2_rounded,
                          onTap: () => context.go('/merchant/inventory'),
                        ),
                        AppStatCard(
                          title: context.tr('dash_kpi_low_stock'),
                          value: '${stats.lowStockCount}',
                          subtitle: context.tr('dash_kpi_reorder_needed'),
                          icon: Icons.warning_amber_rounded,
                          isAlert: stats.lowStockCount > 0,
                          onTap: () => context.go('/merchant/inventory'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 3. QUICK OPERATIONS ACTIONS GRID
                AppSectionHeader(title: context.tr('dash_section_actions')),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.3,
                      children: [
                        _QuickOperationTile(
                          icon: Icons.point_of_sale_rounded,
                          title: 'POS Billing',
                          subtitle: 'Fast Counter',
                          iconColor: AppColors.primary,
                          onTap: () => context.go('/merchant/pos'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.inventory_2_rounded,
                          title: 'Active Products',
                          subtitle: 'Catalog & Stock',
                          iconColor: const Color(0xFF2563EB),
                          onTap: () => context.go('/merchant/inventory'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.menu_book_rounded,
                          title: 'Khata Passbook',
                          subtitle: 'Customer Udhar',
                          iconColor: AppColors.warning,
                          onTap: () => context.go('/merchant/khata'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.analytics_rounded,
                          title: 'Munafa Analytics',
                          subtitle: 'Net Profit Report',
                          iconColor: AppColors.success,
                          onTap: () => context.go('/merchant/analytics'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Shop Expenses',
                          subtitle: 'Roz Ke Kharche',
                          iconColor: const Color(0xFF9333EA),
                          onTap: () => context.go('/merchant/expenses'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.agriculture_rounded,
                          title: 'Mandi Sourcing',
                          subtitle: 'Wholesale List',
                          iconColor: const Color(0xFF059669),
                          onTap: () => context.go('/merchant/procurement'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.local_offer_rounded,
                          title: 'Store Deals',
                          subtitle: 'Offers & Coupons',
                          iconColor: const Color(0xFFEA580C),
                          onTap: () => context.go('/merchant/offers'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.shopping_bag_rounded,
                          title: 'Pickup Orders',
                          subtitle: 'Customer Reservations',
                          iconColor: const Color(0xFFD97706),
                          onTap: () => context.go('/merchant/reservations'),
                        ),
                        _QuickOperationTile(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Store UPI QR',
                          subtitle: 'Counter Standee',
                          iconColor: const Color(0xFF0284C7),
                          onTap: () => showStoreQrDialog(context, shop),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickOperationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickOperationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: context.colorTextMuted),
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

/// Read-Only Clean Shop Showcase Card with 3s Auto-Swapping Image Carousel
class _ShopShowcaseCard extends StatefulWidget {
  final ShopModel shop;
  final AuthController authController;

  const _ShopShowcaseCard({required this.shop, required this.authController});

  @override
  State<_ShopShowcaseCard> createState() => _ShopShowcaseCardState();
}

class _ShopShowcaseCardState extends State<_ShopShowcaseCard> {
  Timer? _timer;
  int _currentPage = 0;
  List<String> _cachedImages = [];

  @override
  void initState() {
    super.initState();
    _cachedImages = _computeImages();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _ShopShowcaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedImages = _computeImages();
  }

  List<String> _computeImages() {
    final list = <String>[];
    if (widget.shop.banners.isNotEmpty) {
      for (final b in widget.shop.banners) {
        final formatted = formatImageUrl(b);
        if (formatted.isNotEmpty && !list.contains(formatted)) {
          list.add(formatted);
        }
      }
    }
    if (widget.shop.logoUrl != null && widget.shop.logoUrl!.isNotEmpty) {
      final formattedLogo = formatImageUrl(widget.shop.logoUrl);
      if (formattedLogo.isNotEmpty && !list.contains(formattedLogo)) {
        list.add(formattedLogo);
      }
    }
    // High-quality store showcase fallback images for 3s auto loop
    if (list.isEmpty) {
      list.add('https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=500&q=80');
      list.add('https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=500&q=80');
      list.add('https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=500&q=80');
    }
    return list;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_cachedImages.length > 1 && mounted) {
        setState(() {
          _currentPage = (_currentPage + 1) % _cachedImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageList = _cachedImages;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Auto Swapping Image Box (3s loop)
          Container(
            width: 104,
            height: 94,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: context.colorSurfaceSubtle,
              border: Border.all(color: context.colorBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: SizedBox.expand(
                      key: ValueKey<int>(_currentPage),
                      child: Image.network(
                        imageList[_currentPage.clamp(0, imageList.length - 1)],
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          color: context.colorPrimaryLight,
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (imageList.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageList.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == i ? 12 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? Colors.white : Colors.white60,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Read-Only Important Shop Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.shop.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.colorTextPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),

                // Category & Status Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    AppBadge(
                      label: widget.shop.category,
                      type: AppBadgeType.primary,
                    ),
                    InkWell(
                      onTap: () async {
                        final newStatus = !widget.shop.isOpen;
                        final ok = await widget.authController.updateShop({'is_open': newStatus});
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newStatus ? 'Store status: OPEN Online' : 'Store status: CLOSED Offline'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AppBadge(
                        label: widget.shop.isOpen
                            ? context.tr('profile_status_open')
                            : context.tr('profile_status_closed'),
                        type: widget.shop.isOpen
                            ? AppBadgeType.success
                            : AppBadgeType.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Address
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13.5,
                      color: context.colorTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.shop.fullAddress,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colorTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Timings
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13.5,
                      color: context.colorTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.shop.formattedTimings,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorTextMuted,
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
