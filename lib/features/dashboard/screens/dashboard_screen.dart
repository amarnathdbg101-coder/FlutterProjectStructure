import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/widgets/merchant_drawer.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../../core/services/data_sync_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../repositories/dashboard_repository.dart';
import '../models/shop_model.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../pos/models/pos_model.dart';
import '../../reservations/controllers/reservation_controller.dart';
import '../widgets/dashboard_price_checker_card.dart';
import '../../app_update/widgets/app_update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DataSyncService().runBackgroundSync(context);
      AppUpdateDialog.showIfAvailable(context);
    });
  }

  void _openBarcodeScanner(BuildContext context) {
    MobileBarcodeScannerDialog.show(
      context,
      title: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
      subtitle: context.isHindi
          ? 'रेट व स्टॉक तुरंत देखने के लिए स्कैन करें'
          : 'Scan barcode to check live rate & stock',
      autoCloseOnSuccess: true,
      onBarcodeScanned: (barcode) async {
        final clean = barcode.trim();
        if (clean.isNotEmpty) {
          context.push(
            '/merchant/price-checker?barcode=${Uri.encodeComponent(clean)}',
          );
        }
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authController = context.read<AuthController>();
    final shop = context.select<AuthController, ShopModel?>(
      (controller) => controller.currentShop,
    );
    final stats = context.select<DashboardController, DashboardStats>(
      (controller) => controller.stats,
    );
    final activePickupCount = context.select<ReservationController, int>(
      (controller) => controller.activeCount,
    );
    final serverSales = context.select<PosController?, List<SaleModel>?>(
      (controller) => controller?.serverSales,
    );

    final recentSales = (serverSales != null && serverSales.isNotEmpty)
        ? serverSales
        : LocalCacheService.get24HourSales();

    return MerchantShell(
      currentIndex: 0,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: context.colorBorder, height: 1.0),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: ctx.colorTextPrimary,
              size: 24,
            ),
            tooltip: ctx.tr('dash_section_actions'),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          context.tr('nav_home'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
            ),
            tooltip: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan barcode',
            onPressed: () => _openBarcodeScanner(context),
          ),
        ],
      ),
      drawer: MerchantDrawer(
        onShowQr: (slug, name) => showStoreQrDialog(context, shop),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          final refreshTasks = <Future<void>>[
            authController.fetchShopDetails(),
            context.read<DashboardController>().fetchDashboardData(),
          ];
          final posController = context.read<PosController?>();
          if (posController != null) {
            refreshTasks.add(posController.fetchBackendSales());
          }
          await Future.wait(refreshTasks);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store identity and business status.
                if (shop != null && shop.id.toString().isNotEmpty) ...[
                  _StoreIdentityCard(
                    shop: shop,
                    authController: authController,
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  _IncompleteStoreCard(),
                  const SizedBox(height: 14),
                ],

                if (activePickupCount > 0) ...[
                  AppSummaryBanner(
                    title: context.isHindi
                        ? 'सक्रिय काउंटर पिकअप ऑर्डर्स'
                        : 'Active Counter Pickup Orders',
                    amount:
                        '$activePickupCount ${context.isHindi ? 'लंबित' : 'Pending'}',
                    subtitle: context.isHindi
                        ? 'ग्राहक काउंटर पर सामान लेने के लिए प्रतीक्षारत हैं'
                        : 'Customer awaiting pickup at your counter',
                    icon: Icons.shopping_bag_rounded,
                    actionLabel: context.isHindi
                        ? 'देखें एवं पैक करें'
                        : 'View & Pack',
                    onAction: () => context.push('/merchant/reservations'),
                  ),
                  const SizedBox(height: 14),
                ],

                _TodaySalesHeroCard(stats: stats),
                const SizedBox(height: 14),

                _CoreOperationsGrid(stats: stats),
                const SizedBox(height: 16),

                const DashboardPriceCheckerCard(),
                const SizedBox(height: 12),
                _CounterUtilitiesStrip(activePickupCount: activePickupCount),
                const SizedBox(height: 20),

                _RecentSalesStream(recentSales: recentSales),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm, high-contrast Hero Card displaying today's total sales and bills.
class _TodaySalesHeroCard extends StatelessWidget {
  final DashboardStats stats;

  const _TodaySalesHeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;

    return InkWell(
      onTap: () => context.push('/merchant/today-sales'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colorBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.currency_rupee_rounded, size: 16, color: AppColors.success),
                ),
                const SizedBox(width: 8),
                Text(
                  isHindi ? 'आज की कुल कमाई' : "Today's Gross Sales",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colorTextMuted,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isHindi ? 'विस्तृत रिपोर्ट' : 'P&L Report',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${stats.todaySales.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${stats.salesCount} ${isHindi ? "बिल कटे • आज का गल्ला" : "bills recorded today"}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The 4 Core Counter Operations (Mummy-Papa Mode: POS, Khata, Stock, Expenses)
class _CoreOperationsGrid extends StatelessWidget {
  final DashboardStats stats;

  const _CoreOperationsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 480 ? 2 : 4;
        final aspectRatio = width < 480 ? 1.45 : 1.7;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            // 1. BILLING COUNTER (POS)
            _buildGiantTile(
              context,
              title: isHindi ? 'बिलिंग काउंटर' : 'Billing (POS)',
              subtitle: isHindi ? '⚡ नया बिल बनाएं' : '⚡ Start new sale',
              icon: Icons.point_of_sale_rounded,
              tileColor: const Color(0xFF16A34A),
              badge: isHindi ? 'नया' : 'NEW',
              onTap: () => context.go('/merchant/pos'),
            ),

            // 2. KHATA REGISTER
            _buildGiantTile(
              context,
              title: isHindi ? 'खाता बही' : 'Khata Ledger',
              subtitle: '₹${stats.totalUdhar.toStringAsFixed(0)} ${isHindi ? "बाज़ार बाकी" : "dues"}',
              icon: Icons.menu_book_rounded,
              tileColor: const Color(0xFFD97706),
              onTap: () => context.go('/merchant/khata'),
            ),

            // 3. INVENTORY & STOCK
            _buildGiantTile(
              context,
              title: isHindi ? 'दुकान का सामान' : 'Stock & Samaan',
              subtitle: stats.lowStockCount > 0
                  ? '⚠️ ${stats.lowStockCount} ${isHindi ? "कम स्टॉक" : "low"}'
                  : '${stats.catalogCount} ${isHindi ? "सामान" : "items"}',
              icon: Icons.inventory_2_rounded,
              tileColor: const Color(0xFF2563EB),
              onTap: () => context.go('/merchant/inventory'),
            ),

            // 4. EXPENSES
            _buildGiantTile(
              context,
              title: isHindi ? 'दुकान खर्चा' : 'Expenses',
              subtitle: isHindi ? 'दैनिक दुकान खर्च' : 'Daily shop spends',
              icon: Icons.receipt_long_rounded,
              tileColor: const Color(0xFF7C3AED),
              onTap: () => context.go('/merchant/expenses'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGiantTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tileColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tileColor.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: tileColor.withValues(alpha: context.isDark ? 0.15 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: tileColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 20, color: tileColor),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.colorTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Counter Utilities Strip (Mandi, Deals, Counter Pickup)
class _CounterUtilitiesStrip extends StatelessWidget {
  final int activePickupCount;

  const _CounterUtilitiesStrip({required this.activePickupCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Mandi Procurement
        Expanded(
          child: _CompactUtilityPill(
            icon: Icons.store_mall_directory_rounded,
            label: context.isHindi ? 'मंडी खरीदारी' : 'Mandi B2B',
            onTap: () => context.push('/merchant/procurement'),
          ),
        ),
        const SizedBox(width: 8),

        // Offers & Discounts
        Expanded(
          child: _CompactUtilityPill(
            icon: Icons.local_offer_rounded,
            label: context.isHindi ? 'ऑफर्स व कूपन' : 'Store Offers',
            onTap: () => context.push('/merchant/offers'),
          ),
        ),
        const SizedBox(width: 8),

        // Counter Pickup Orders
        Expanded(
          child: _CompactUtilityPill(
            icon: Icons.shopping_bag_rounded,
            label: context.isHindi ? 'पिकअप ऑर्डर' : 'Pickups',
            badgeCount: activePickupCount > 0 ? activePickupCount : null,
            onTap: () => context.push('/merchant/reservations'),
          ),
        ),
      ],
    );
  }
}

class _CompactUtilityPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  const _CompactUtilityPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorSurfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colorBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: context.colorTextSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live Stream of Recent Sales Receipts (Shopify POS / Square style ledger)
class _RecentSalesStream extends StatelessWidget {
  final List<SaleModel> recentSales;

  const _RecentSalesStream({required this.recentSales});

  @override
  Widget build(BuildContext context) {
    final displaySales = recentSales.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: context.isHindi ? 'हालिया बिक्री बिल' : 'Recent Store Sales',
          trailing: InkWell(
            onTap: () => context.push('/merchant/today-sales'),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.isHindi ? 'सभी बिल देखें' : 'View All',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (displaySales.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: context.colorSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 32,
                  color: context.colorTextMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  context.isHindi
                      ? 'आज अभी तक कोई बिल नहीं बना है'
                      : 'No sales bills recorded yet today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.isHindi
                      ? 'ऊपर दिए गए "नया बिल बनाएं" बटन से तुरंत बिलिंग शुरू करें'
                      : 'Tap "Fast POS Billing" above to create your first bill',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displaySales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sale = displaySales[index];
              final isCash = sale.paymentMethod.toLowerCase() == 'cash';
              final isUpi = sale.paymentMethod.toLowerCase() == 'upi';
              final isKhata = sale.paymentMethod.toLowerCase() == 'khata';

              final paymentColor = isCash
                  ? AppColors.success
                  : (isUpi
                        ? AppColors.primary
                        : (isKhata
                              ? AppColors.warning
                              : const Color(0xFF8B5CF6)));

              final paymentLabel = isCash
                  ? (context.isHindi ? 'नकद' : 'CASH')
                  : (isUpi
                        ? 'UPI'
                        : (isKhata
                              ? (context.isHindi ? 'उधार' : 'KHATA')
                              : (context.isHindi ? 'स्प्लिट' : 'SPLIT')));

              final timeStr = AppDateTimeUtils.formatTime(sale.createdAt);

              return AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                onTap: () => context.push('/merchant/today-sales'),
                child: Row(
                  children: [
                    // Receipt Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: paymentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCash
                            ? Icons.payments_rounded
                            : (isUpi
                                  ? Icons.qr_code_rounded
                                  : Icons.receipt_rounded),
                        size: 18,
                        color: paymentColor,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bill Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sale.billNumber != null &&
                                        sale.billNumber!.isNotEmpty
                                    ? '#${sale.billNumber}'
                                    : (context.isHindi
                                          ? 'बिल #${index + 1}'
                                          : 'Bill #${index + 1}'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.colorTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: paymentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  paymentLabel,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: paymentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sale.items.length} ${context.isHindi ? 'सामान' : 'items'} • $timeStr',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: context.colorTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount
                    Text(
                      '₹${sale.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.colorTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Sleek Store Identity Card with live status pill and verified badge
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
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Store Logo / Avatar
          AppProductImage(
            imageUrl: logoUrl,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(10),
            fallbackIcon: Icons.storefront_rounded,
            fallbackIconSize: 24,
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
                    Flexible(
                      child: Text(
                        shop.name,
                        style: TextStyle(
                          fontSize: 15,
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

                // Category & online/offline status toggle.
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
                        final ok = await authController.updateShop({
                          'is_open': newStatus,
                        });
                        if (ok && context.mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            newStatus
                                ? (context.isHindi
                                      ? 'दुकान ऑनलाइन खुली है'
                                      : 'Store is OPEN Online')
                                : (context.isHindi
                                      ? 'दुकान ऑफ़लाइन बंद है'
                                      : 'Store is CLOSED Offline'),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: shop.isOpen
                              ? AppColors.success.withValues(alpha: 0.10)
                              : context.colorSurfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: shop.isOpen
                                ? AppColors.success.withValues(alpha: 0.35)
                                : context.colorBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: shop.isOpen
                                    ? AppColors.success
                                    : context.colorTextMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              shop.isOpen
                                  ? (context.isHindi
                                        ? 'ऑनलाइन खुली'
                                        : 'Live Online')
                                  : (context.isHindi
                                        ? 'ऑफ़लाइन बंद'
                                        : 'Closed'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: shop.isOpen
                                    ? AppColors.success
                                    : context.colorTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Quick Store QR Action
          Tooltip(
            message: context.isHindi ? 'दुकान QR कोड देखें' : 'View Store QR',
            child: InkWell(
              onTap: () => showStoreQrDialog(context, shop),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colorBorder),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 20,
                  color: context.colorTextPrimary,
                ),
              ),
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
        color: AppColors.primary.withValues(
          alpha: context.isDark ? 0.15 : 0.08,
        ),
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
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isHindi
                          ? 'दुकान प्रोफाइल अभी अधूरी है'
                          : 'Store Setup Incomplete',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text(
                context.isHindi
                    ? 'दुकान प्रोफाइल बनाएं'
                    : 'Create Store Profile',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => context.go('/merchant/profile'),
            ),
          ),
        ],
      ),
    );
  }
}
