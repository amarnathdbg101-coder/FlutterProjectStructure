import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/analytics_controller.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnalyticsController>();
    final data = controller.analytics;

    return MerchantShell(
      currentIndex: -1,
      child: Scaffold(
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
            'Profit & Shop Analytics',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colorTextPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh Analytics',
              onPressed: () async {
                await controller.fetchAnalytics();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Shop Analytics Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
                  );
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.fetchAnalytics(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ResponsiveContainer(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.isLoading && data == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data != null) ...[
                    // Hero Net Pocket Profit Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  'NET POCKET PROFIT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${data.averageMarginPct.toStringAsFixed(1)}% Avg Margin',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹${data.netPocketProfit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Net profit calculated from ${data.totalSalesCount} cleared counter bills',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Financial Profit Breakdown Formula
                    AppSectionHeader(title: 'FINANCIAL PROFIT BREAKDOWN'),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _buildFormulaRow(
                            context,
                            label: 'Total Sales Revenue',
                            value: '+₹${data.totalRevenue.toStringAsFixed(0)}',
                            valueColor: AppColors.success,
                          ),
                          const Divider(height: 18),
                          _buildFormulaRow(
                            context,
                            label: 'Inventory Cost (COGS)',
                            value: '-₹${data.totalCost.toStringAsFixed(0)}',
                            valueColor: AppColors.error,
                          ),
                          const Divider(height: 18),
                          _buildFormulaRow(
                            context,
                            label: 'Store Daily Expenses',
                            value: '-₹${data.totalExpenses.toStringAsFixed(0)}',
                            valueColor: AppColors.error,
                          ),
                          Divider(height: 24, thickness: 1.5, color: context.colorBorder),
                          _buildFormulaRow(
                            context,
                            label: 'Net Pocket Profit',
                            value: '₹${data.netPocketProfit.toStringAsFixed(0)}',
                            valueColor: AppColors.success,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Best Profitable Products
                    if (data.bestProfitable.isNotEmpty) ...[
                      AppSectionHeader(
                        title: 'TOP PROFITABLE PRODUCTS',
                        trailing: const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 20),
                      ),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.bestProfitable.length,
                          separatorBuilder: (_, _) => Divider(height: 12, color: context.colorBorder),
                          itemBuilder: (context, index) {
                            final item = data.bestProfitable[index];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: context.colorTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.soldQty} sold • Margin: ${item.marginPct.toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+₹${item.profitAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Dead Stock Alert
                    if (data.deadStock.isNotEmpty) ...[
                      AppSectionHeader(
                        title: 'DEAD STOCK ALERT',
                        trailing: const Icon(Icons.inventory_2_outlined, color: AppColors.warning, size: 20),
                      ),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.deadStock.length,
                          separatorBuilder: (_, _) => Divider(height: 12, color: context.colorBorder),
                          itemBuilder: (context, index) {
                            final item = data.deadStock[index];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: context.colorTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Stock: ${item.currentStock} pcs • ${item.daysInStock} days in stock',
                                        style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.warning,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                  label: const Text('Flash Clearance Deal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  onPressed: () {
                                    context.go('/merchant/offers');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Create a Flash Clearance Offer for "${item.name}"!'),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulaRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold ? context.colorTextPrimary : context.colorTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
