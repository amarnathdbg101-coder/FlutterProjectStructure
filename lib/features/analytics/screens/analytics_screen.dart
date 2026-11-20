import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/analytics_controller.dart';
import '../models/analytics_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsController>().fetchAnalytics();
    });
  }

  void _sharePnLSummaryOnWhatsApp(BuildContext context, AnalyticsModel data, String shopName) {
    final isHindi = context.isHindi;
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    final buffer = StringBuffer();
    buffer.writeln(isHindi ? '📊 *दुकान मुनाफा व वित्तीय रिपोर्ट*' : '📊 *Store Profit & Loss Report*');
    if (shopName.isNotEmpty) {
      buffer.writeln('🏪 *$shopName*');
    }
    buffer.writeln('📅 $dateStr\n');

    buffer.writeln(isHindi ? '💰 *कुल बिक्री आय:* ₹${data.totalRevenue.toStringAsFixed(0)}' : '💰 *Gross Sales:* ₹${data.totalRevenue.toStringAsFixed(0)}');
    buffer.writeln(isHindi ? '📦 *सामान खरीद लागत:* -₹${data.totalCost.toStringAsFixed(0)}' : '📦 *Inventory Cost (COGS):* -₹${data.totalCost.toStringAsFixed(0)}');
    buffer.writeln(isHindi ? '💸 *दुकान खर्चे:* -₹${data.totalExpenses.toStringAsFixed(0)}' : '💸 *Store Expenses:* -₹${data.totalExpenses.toStringAsFixed(0)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    final profitPrefix = data.netPocketProfit >= 0 ? '+' : '';
    buffer.writeln(isHindi
        ? '🏆 *शुद्ध जेब बचत:* $profitPrefix₹${data.netPocketProfit.toStringAsFixed(0)} (${data.averageMarginPct.toStringAsFixed(1)}% मार्जिन)'
        : '🏆 *Net In-Hand Profit:* $profitPrefix₹${data.netPocketProfit.toStringAsFixed(0)} (${data.averageMarginPct.toStringAsFixed(1)}% Margin)');
    buffer.writeln(isHindi
        ? '🧾 *कुल बिल:* ${data.totalSalesCount} बिल'
        : '🧾 *Total Bills:* ${data.totalSalesCount} cleared bills');

    if (data.bestProfitable.isNotEmpty) {
      buffer.writeln(isHindi ? '\n🔥 *सर्वाधिक मुनाफे वाले सामान:*' : '\n🔥 *Top Profitable Items:*');
      for (int i = 0; i < data.bestProfitable.take(3).length; i++) {
        final p = data.bestProfitable[i];
        buffer.writeln('${i + 1}. ${p.name} (+₹${p.profitAmount.toStringAsFixed(0)})');
      }
    }

    WhatsAppShareHelper.shareToWhatsApp(
      context: context,
      message: buffer.toString(),
      successToast: isHindi ? 'व्हाट्सएप पर रिपोर्ट भेजी जा रही है...' : 'Sharing report to WhatsApp...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AnalyticsController>();
    final data = controller.analytics;
    final isHindi = context.isHindi;

    AuthController? authCtrl;
    try {
      authCtrl = context.watch<AuthController>();
    } catch (_) {}
    final shopName = authCtrl?.currentShop?.name ?? '';

    return MerchantShell(
      currentIndex: -1,
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: context.colorBorder, height: 1.0),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary, size: 22),
          tooltip: isHindi ? 'वापस जाएं' : 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/merchant');
            }
          },
        ),
        title: Text(
          isHindi ? 'दुकान मुनाफा व विश्लेषण' : 'Profit & Shop Analytics',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.colorTextPrimary, size: 21),
            tooltip: isHindi ? 'रिपोर्ट रीफ्रेश करें' : 'Refresh Report',
            onPressed: () async {
              await controller.fetchAnalytics();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isHindi ? '✓ एनालिटिक्स डेटा रीफ्रेश हुआ' : '✓ Shop Analytics Refreshed'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            tooltip: isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
            onSelected: (val) {
              switch (val) {
                case 'share':
                  if (data != null) {
                    _sharePnLSummaryOnWhatsApp(context, data, shopName);
                  }
                  break;
                case 'today_sales':
                  context.push('/merchant/today-sales');
                  break;
                case 'expenses':
                  context.push('/merchant/expenses');
                  break;
                case 'pos':
                  context.go('/merchant/pos');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (data != null)
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 18),
                      const SizedBox(width: 10),
                      Text(ctx.isHindi ? 'व्हाट्सएप पर रिपोर्ट भेजें' : 'Share on WhatsApp'),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'today_sales',
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'आज की बिक्री (Today Sales)' : "Today's Sales"),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'expenses',
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'दुकान खर्चे (Expenses)' : 'Store Expenses'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'pos',
                child: Row(
                  children: [
                    const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'POS बिलिंग काउंटर' : 'POS Terminal'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.fetchAnalytics(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ResponsiveContainer(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.isLoading && data == null)
                    const AppStatCardSkeleton()
                  else if (data != null) ...[
                    // 1. Executive Clean Net Pocket Profit Card
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: data.netPocketProfit >= 0 ? AppColors.success : AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHindi ? 'शुद्ध जेब मुनाफा (NET IN-HAND)' : 'NET POCKET PROFIT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: context.colorTextMuted,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              AppBadge(
                                label: '${data.averageMarginPct.toStringAsFixed(1)}% ${isHindi ? 'औसत मार्जिन' : 'Avg Margin'}',
                                type: data.netPocketProfit >= 0 ? AppBadgeType.success : AppBadgeType.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${data.netPocketProfit >= 0 ? "+" : ""}₹${data.netPocketProfit.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: data.netPocketProfit >= 0 ? AppColors.success : AppColors.error,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isHindi
                                ? 'कुल ${data.totalSalesCount} बिलों के हिसाब से शुद्ध बचत (खर्चे व खरीद निकाल कर)'
                                : 'Net profit calculated from ${data.totalSalesCount} cleared counter bills',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Financial Profit Breakdown (P&L Mathematics)
                    AppSectionHeader(
                      title: isHindi ? 'वित्तीय मुनाफा विवरण (P&L गणित)' : 'FINANCIAL PROFIT BREAKDOWN',
                    ),
                    const SizedBox(height: 6),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildFormulaRow(
                            context,
                            label: isHindi ? '+ कुल बिक्री आय (Gross Sales)' : '+ Total Sales Revenue',
                            value: '+₹${data.totalRevenue.toStringAsFixed(0)}',
                            valueColor: AppColors.success,
                          ),
                          const Divider(height: 16),
                          _buildFormulaRow(
                            context,
                            label: isHindi ? '- सामान खरीद लागत (Wholesale Cost)' : '- Inventory Cost (COGS)',
                            value: '-₹${data.totalCost.toStringAsFixed(0)}',
                            valueColor: AppColors.error,
                          ),
                          const Divider(height: 16),
                          _buildFormulaRow(
                            context,
                            label: isHindi ? '- दुकान के रोज के खर्चे (Expenses)' : '- Store Daily Expenses',
                            value: '-₹${data.totalExpenses.toStringAsFixed(0)}',
                            valueColor: AppColors.error,
                          ),
                          Divider(height: 22, thickness: 1.2, color: context.colorBorder),
                          _buildFormulaRow(
                            context,
                            label: isHindi ? '= शुद्ध जेब बचत (Net Profit)' : '= Net Pocket Profit',
                            value: '${data.netPocketProfit >= 0 ? "+" : ""}₹${data.netPocketProfit.toStringAsFixed(0)}',
                            valueColor: data.netPocketProfit >= 0 ? AppColors.success : AppColors.error,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Quick High-Utility Action Cards (Min 52px height)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/merchant/today-sales'),
                            borderRadius: BorderRadius.circular(12),
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isHindi ? 'आज की बिक्री' : "Today's Sales",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: context.colorTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          isHindi ? 'बिल व बिके उत्पाद →' : 'Bills & items →',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.colorTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/merchant/expenses'),
                            borderRadius: BorderRadius.circular(12),
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.warning, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isHindi ? 'दुकान खर्चे' : 'Expenses',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: context.colorTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          isHindi ? 'खर्च जोड़ें व देखें →' : 'Log expenses →',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.colorTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 4. Best Profitable Products
                    if (data.bestProfitable.isNotEmpty) ...[
                      AppSectionHeader(
                        title: isHindi ? 'सबसे ज्यादा मुनाफा देने वाले सामान' : 'TOP PROFITABLE PRODUCTS',
                        trailing: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(height: 6),
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
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: index == 0 ? const Color(0xFFFEF3C7) : context.colorSurfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: index == 0 ? const Color(0xFFF59E0B) : context.colorBorder,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: index == 0 ? const Color(0xFFB45309) : context.colorTextSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                                        isHindi
                                            ? '${item.soldQty} पीस बिके • ${item.marginPct.toStringAsFixed(1)}% मार्जिन'
                                            : '${item.soldQty} sold • ${item.marginPct.toStringAsFixed(1)}% margin',
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
                      const SizedBox(height: 16),
                    ],

                    // 5. Dead Stock Alert
                    if (data.deadStock.isNotEmpty) ...[
                      AppSectionHeader(
                        title: isHindi ? 'धीमा / रुका हुआ स्टॉक (DEAD STOCK)' : 'DEAD STOCK ALERT',
                        trailing: const Icon(Icons.inventory_2_outlined, color: AppColors.warning, size: 20),
                      ),
                      const SizedBox(height: 6),
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
                                        isHindi
                                            ? 'स्टॉक: ${item.currentStock} पीस • ${item.daysInStock} दिनों से बिना बिक्री'
                                            : 'Stock: ${item.currentStock} pcs • ${item.daysInStock} days idle',
                                        style: TextStyle(fontSize: 11, color: context.colorTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.warning,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(110, 42),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    isHindi ? 'ऑफर बनाएं' : 'Clearance',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  onPressed: () {
                                    context.go('/merchant/offers');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isHindi
                                            ? '"${item.name}" के लिए क्लीयरेंस ऑफर बनाएं!'
                                            : 'Create a Flash Clearance Offer for "${item.name}"!'),
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
                  ] else ...[
                    // Empty State
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colorPrimaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isHindi ? 'अभी कोई एनालिटिक्स डेटा उपलब्ध नहीं है' : 'No analytics data available yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHindi
                                ? 'POS काउंटर पर बिलिंग शुरू करने के बाद मुनाफा और बिक्री का विस्तृत हिसाब यहाँ दिखेगा।'
                                : 'Start billing on the POS counter to see detailed profits and sales analytics here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                            label: Text(
                              isHindi ? 'POS काउंटर खोलें' : 'Open POS Counter',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              minimumSize: const Size(140, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.go('/merchant/pos'),
                          ),
                        ],
                      ),
                    ),
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
