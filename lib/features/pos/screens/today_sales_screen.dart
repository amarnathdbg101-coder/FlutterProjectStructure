import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';

class TodaySalesScreen extends StatefulWidget {
  const TodaySalesScreen({super.key});

  @override
  State<TodaySalesScreen> createState() => _TodaySalesScreenState();
}

class _TodaySalesScreenState extends State<TodaySalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().fetchBackendSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final soldProducts = pos.get24HourSoldProductsSummary();
    final recentSales = pos.serverSales.isNotEmpty ? pos.serverSales : LocalCacheService.get24HourSales();
    final totalRevenue = pos.today24hRevenue;
    final totalBills = pos.today24hBillCount;

    final int totalUnitsSold = soldProducts.fold(0, (sum, item) => sum + (item['qty'] as int));

    return MerchantShell(
      currentIndex: 0,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: context.colorBorder, height: 1.0),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary, size: 22),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/merchant');
            }
          },
        ),
        title: Text(
          context.tr('today_sales_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: Text(
                context.tr('today_sales_open_pos'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.go('/merchant/pos'),
            ),
          ),
        ],
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<PosController>().fetchBackendSales();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ResponsiveContainer(
              maxWidth: 960,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Executive Summary Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('today_sales_total_rev'),
                          value: '₹${totalRevenue.toStringAsFixed(0)}',
                          subtitle: context.tr('today_sales_subtitle'),
                          icon: Icons.currency_rupee_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('today_sales_total_bills'),
                          value: '$totalBills',
                          subtitle: '$totalUnitsSold ${context.tr('today_sales_items_sold')}',
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Section Header: Sold Products List
                  AppSectionHeader(
                    title: context.tr('today_sales_products_header'),
                    trailing: AppBadge(
                      label: '${soldProducts.length} Products',
                      type: AppBadgeType.primary,
                    ),
                  ),

                  // 3. Products List or Empty State
                  if (soldProducts.isEmpty)
                    _buildEmptyState(context)
                  else
                    ...soldProducts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final name = item['name'] as String;
                      final qty = item['qty'] as int;
                      final unitPrice = (item['unit_price'] as double);
                      final total = (item['total'] as double);
                      final pct = totalRevenue > 0 ? (total / totalRevenue) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  // Rank badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: index == 0
                                          ? AppColors.primaryLight
                                          : context.colorSurfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: index == 0
                                            ? AppColors.primary.withValues(alpha: 0.3)
                                            : context.colorBorder,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '#${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: index == 0 ? AppColors.primary : context.colorTextSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Product name & details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: context.colorTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Rate: ₹${unitPrice.toStringAsFixed(0)} • Qty: $qty units',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: context.colorTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Total revenue for this product
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(pct * 100).toStringAsFixed(1)}% of sales',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.colorTextMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Visual progress bar of contribution
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct.clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: context.colorBorder.withValues(alpha: 0.4),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    index == 0 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // 4. Section: Recent Completed Bills
                  if (recentSales.isNotEmpty) ...[
                    AppSectionHeader(
                      title: context.tr('today_sales_recent_bills_header'),
                      trailing: AppBadge(
                        label: '${recentSales.length} Bills',
                        type: AppBadgeType.success,
                      ),
                    ),
                    ...(List<SaleModel>.from(recentSales)..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(30).map((sale) => _buildSaleBillTile(context, sale)),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaleBillTile(BuildContext context, SaleModel sale) {
    final timeStr = AppDateTimeUtils.formatTime(sale.createdAt);
    final isCash = sale.paymentMethod.toLowerCase() == 'cash';
    final isUpi = sale.paymentMethod.toLowerCase() == 'upi';

    Color modeColor = isCash ? AppColors.success : (isUpi ? AppColors.primary : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCash ? Icons.payments_rounded : (isUpi ? Icons.qr_code_2_rounded : Icons.menu_book_rounded),
                color: modeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bill #${sale.billNumber ?? "1001"}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: context.colorTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sale.items.length} items • ${sale.customerPhone.isNotEmpty ? sale.customerPhone : "Walk-in Customer"}',
                    style: TextStyle(fontSize: 11.5, color: context.colorTextSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${sale.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                AppBadge(
                  label: sale.paymentMethod.toUpperCase(),
                  type: sale.paymentMethod == 'cash'
                      ? AppBadgeType.success
                      : (sale.paymentMethod == 'upi' ? AppBadgeType.primary : AppBadgeType.warning),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('today_sales_empty_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('today_sales_empty_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text(context.tr('today_sales_open_pos')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.go('/merchant/pos'),
          ),
        ],
      ),
    );
  }
}
