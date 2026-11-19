import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../analytics/controllers/analytics_controller.dart';
import '../../analytics/models/analytics_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';
import '../repositories/pos_advanced_repository.dart';
import '../services/sales_pdf_service.dart';
import '../widgets/day_close_reconciliation_sheet.dart';
import '../widgets/pos_bill_return_modal.dart';

class TodaySalesScreen extends StatefulWidget {
  const TodaySalesScreen({super.key});

  @override
  State<TodaySalesScreen> createState() => _TodaySalesScreenState();
}

class _TodaySalesScreenState extends State<TodaySalesScreen> {
  bool _isDownloadingPdf = false;
  int _selectedWindowDays = 1; // 1 = Today (24 Hours), 10 = Last 10 Days Rolling Record
  int _activeTabIndex = 0; // 0 = Sold Items, 1 = Bills, 2 = Top Ranking
  bool _showProfitBreakdown = false; // Toggle P&L breakdown
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().fetchBackendSales();
      try {
        Provider.of<AnalyticsController>(context, listen: false).fetchAnalytics();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _downloadEodPdf() async {
    setState(() => _isDownloadingPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text(context.isHindi
                ? 'सेल रिपोर्ट PDF तैयार की जा रही है...'
                : 'Generating sales PDF report...'),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );

    final pos = context.read<PosController>();
    final metrics = pos.getSalesMetrics(windowDays: _selectedWindowDays);
    final allTimeSortedItems = metrics.timeSortedItems;
    final totalRevenue = metrics.totalRevenue;
    final totalBills = metrics.totalBills;
    final cashRevenue = metrics.cashRevenue;
    final upiRevenue = metrics.upiRevenue;
    final khataRevenue = metrics.khataRevenue;

    final cachedShop = LocalCacheService.getShop();
    final effectiveShopName = (cachedShop?.name.trim().isNotEmpty ?? false)
        ? cachedShop!.name.trim()
        : 'ShopSilo Partner Store';

    try {
      // ⚡ 1. Primary: Instant 24ms stream from pure-Go backend (zero phone UI freeze or skipped frames!)
      final res = await PosAdvancedRepository().downloadEndOfDayReportPdfBytes(
        days: _selectedWindowDays,
      );
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final fileName = _selectedWindowDays > 1
            ? 'ShopSilo_${_selectedWindowDays}Day_Sales_Journal.pdf'
            : 'ShopSilo_Today_Sales_Report.pdf';
        await Printing.sharePdf(
          bytes: res.data!,
          filename: fileName,
        );
        return;
      }
      throw Exception(res.error ?? 'Backend report unavailable');
    } catch (err) {
      debugPrint('[SalesPDF] Backend fetch error: $err, falling back to local generation');
      try {
        // ⚡ 2. Offline Fallback: Local on-device generation if device is offline
        await SalesPdfService.shareSalesSheet(
          shopName: effectiveShopName,
          items: allTimeSortedItems,
          totalRevenue: totalRevenue,
          totalBills: totalBills,
          cashRevenue: cashRevenue,
          upiRevenue: upiRevenue,
          khataRevenue: khataRevenue,
          windowDays: _selectedWindowDays,
          shopAddress: cachedShop?.address,
          shopPhone: cachedShop?.phone ?? cachedShop?.whatsappNumber,
        );
      } catch (fallbackErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.isHindi ? 'रिपोर्ट तैयार करने में त्रुटि: $fallbackErr' : 'Failed to generate report: $fallbackErr'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    AnalyticsModel? analytics;
    try {
      analytics = Provider.of<AnalyticsController>(context).analytics;
    } catch (_) {
      analytics = null;
    }

    // ⚡ 0ms Memoized Single-Pass Sales & P&L Metrics from PosController
    final metrics = pos.getSalesMetrics(
      windowDays: _selectedWindowDays,
      storeExpenses: analytics?.totalExpenses ?? 0.0,
    );

    final totalRevenue = metrics.totalRevenue;
    final totalBills = metrics.totalBills;
    final totalUnitsSold = metrics.totalUnitsSold;
    final cashRevenue = metrics.cashRevenue;
    final upiRevenue = metrics.upiRevenue;
    final khataRevenue = metrics.khataRevenue;
    final totalCogs = metrics.totalCogs;
    final netProfit = metrics.netProfit;
    final marginPct = metrics.marginPct;
    final allTimeSortedItems = metrics.timeSortedItems;
    final allSoldRanking = metrics.productRanking;

    // Strict in-memory deduplication of bills by billNumber so duplicate records NEVER display
    final Map<String, SaleModel> deduplicatedBillsMap = {};
    for (final sale in metrics.recentSales) {
      final billNum = sale.billNumber?.trim() ?? '';
      final key = billNum.isNotEmpty
          ? billNum
          : 's_${sale.createdAt.millisecondsSinceEpoch}_${sale.totalAmount}';
      deduplicatedBillsMap[key] = sale;
    }
    final recentSales = deduplicatedBillsMap.values.toList();
    recentSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final is10Days = _selectedWindowDays == 10;

    // Search filter logic
    final filteredSoldItems = _searchQuery.isEmpty
        ? allTimeSortedItems
        : allTimeSortedItems.where((i) =>
            i.productName.toLowerCase().contains(_searchQuery) ||
            i.billNumber.toLowerCase().contains(_searchQuery) ||
            i.customerPhone.contains(_searchQuery)).toList();

    final filteredBills = _searchQuery.isEmpty
        ? recentSales
        : recentSales.where((s) =>
            (s.billNumber ?? '').toLowerCase().contains(_searchQuery) ||
            s.customerPhone.contains(_searchQuery) ||
            s.items.any((i) => i.product.name.toLowerCase().contains(_searchQuery))).toList();

    final filteredRanking = _searchQuery.isEmpty
        ? allSoldRanking
        : allSoldRanking.where((r) =>
            (r['name'] as String).toLowerCase().contains(_searchQuery)).toList();

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
          tooltip: context.isHindi ? 'वापस जाएं' : 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/merchant');
            }
          },
        ),
        title: Text(
          is10Days
              ? (context.isHindi ? '10-दिवसीय बिक्री व मुनाफा' : '10-Day Sales & Profit')
              : (context.isHindi ? 'आज की बिक्री व मुनाफा' : "Today's Sales & Profit"),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          // Quick Universal Native Share
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary, size: 21),
            tooltip: context.isHindi ? 'सेल रिपोर्ट शेयर करें (WhatsApp, Bluetooth...)' : 'Share Sales PDF (WhatsApp, Bluetooth...)',
            onPressed: _isDownloadingPdf ? null : _downloadEodPdf,
          ),
          // Quick PDF Download & Print Layout
          IconButton(
            icon: _isDownloadingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
            tooltip: context.isHindi ? 'P&L PDF डाउनलोड / प्रिंट करें' : 'Download Executive P&L PDF',
            onPressed: _isDownloadingPdf ? null : _downloadEodPdf,
          ),
          // Quick Refresh
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.colorTextPrimary, size: 21),
            tooltip: context.isHindi ? 'डेटा रीफ्रेश करें' : 'Refresh Sales',
            onPressed: () async {
              final List<Future> refreshTasks = [
                context.read<PosController>().fetchBackendSales(),
              ];
              try {
                refreshTasks.add(Provider.of<AnalyticsController>(context, listen: false).fetchAnalytics());
              } catch (_) {}
              await Future.wait(refreshTasks);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.isHindi ? '✓ बिक्री व मुनाफा डेटा रीफ्रेश हुआ' : '✓ Sales & Profit data refreshed'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          // More Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
            onSelected: (val) async {
              switch (val) {
                case 'analytics':
                  context.push('/merchant/analytics');
                  break;
                case 'day_close':
                  DayCloseReconciliationSheet.show(context);
                  break;
                case 'pos':
                  context.go('/merchant/pos');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'analytics',
                child: Row(
                  children: [
                    const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'व्यापार व मुनाफा रिपोर्ट (Analytics)' : 'Profit & Shop Analytics'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'day_close',
                child: Row(
                  children: [
                    const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'दुकान बंद / गल्ला मिलान' : 'Day Close & Reconciliation'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'pos',
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'बिलिंग काउंटर पर जाएं' : 'Go to POS Terminal'),
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
          onRefresh: () async {
            final List<Future> refreshTasks = [
              context.read<PosController>().fetchBackendSales(),
            ];
            try {
              refreshTasks.add(Provider.of<AnalyticsController>(context, listen: false).fetchAnalytics());
            } catch (_) {}
            await Future.wait(refreshTasks);
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: ResponsiveContainer(
              maxWidth: 780,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Clean, Calm & Non-Cluttered Header Section
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. Clean Duration Filter Switcher
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.colorBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PeriodTab(
                                    label: context.isHindi ? 'आज (24 घंटे)' : 'Today (24h)',
                                    isSelected: !is10Days,
                                    onTap: () => setState(() => _selectedWindowDays = 1),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _PeriodTab(
                                    label: context.isHindi ? 'पिछले 10 दिन का हिसाब' : 'Last 10 Days Record',
                                    isSelected: is10Days,
                                    onTap: () => setState(() => _selectedWindowDays = 10),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // B. Calm & Clear Financial Hero Card (Spacious, No Cramping)
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Sales on left, Net Profit on right (Fully Responsive & Overflow-Safe)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left: Total Sales
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.isHindi ? 'कुल बिक्री (Sales)' : 'Total Sales',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: context.colorTextSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '₹${totalRevenue.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: context.colorTextPrimary,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$totalBills ${context.isHindi ? 'बिल' : 'bills'} • $totalUnitsSold ${context.isHindi ? 'सामान' : 'items'}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: context.colorTextMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Right: Net Pocket Profit
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              context.isHindi ? 'शुद्ध जेब मुनाफा' : 'Net Profit',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '${netProfit >= 0 ? "+" : ""}₹${netProfit.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w900,
                                                  color: netProfit >= 0 ? AppColors.success : AppColors.error,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: AppBadge(
                                                size: AppBadgeSize.sm,
                                                label: '${marginPct.toStringAsFixed(1)}% ${context.isHindi ? 'मार्जिन' : 'margin'}',
                                                type: netProfit >= 0 ? AppBadgeType.success : AppBadgeType.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Divider(height: 1, color: context.colorBorder),
                                const SizedBox(height: 10),

                                // Bottom Row: Quick P&L math link + PDF Report
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: InkWell(
                                        onTap: () => setState(() => _showProfitBreakdown = !_showProfitBreakdown),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _showProfitBreakdown ? Icons.keyboard_arrow_up_rounded : Icons.calculate_outlined,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  context.isHindi ? 'मुनाफा हिसाब' : 'P&L Details',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: InkWell(
                                        onTap: _isDownloadingPdf ? null : _downloadEodPdf,
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFFDC2626)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  context.isHindi ? 'सेल रिपोर्ट PDF' : 'Sales PDF',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Expandable P&L Formula
                                if (_showProfitBreakdown) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: context.colorSurfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: context.colorBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.isHindi ? 'दुकानदार शुद्ध मुनाफा गणित' : 'SHOP PROFIT & LOSS MATHEMATICS',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: context.colorTextMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildFormulaItem(
                                          context,
                                          title: context.isHindi ? '+ कुल बिक्री आय (Sales Revenue)' : '+ Total Sales Revenue',
                                          value: '+₹${totalRevenue.toStringAsFixed(0)}',
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(height: 3),
                                        _buildFormulaItem(
                                          context,
                                          title: context.isHindi ? '- सामान खरीद लागत (Estimated COGS)' : '- Cost of Goods Sold (COGS)',
                                          value: '-₹${totalCogs.toStringAsFixed(0)}',
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(height: 4),
                                        Divider(height: 1, color: context.colorBorder),
                                        const SizedBox(height: 4),
                                        _buildFormulaItem(
                                          context,
                                          title: context.isHindi ? '= शुद्ध जेब मुनाफा (Net Pocket Profit)' : '= Net Pocket Profit',
                                          value: '${netProfit >= 0 ? "+" : ""}₹${netProfit.toStringAsFixed(0)} (${marginPct.toStringAsFixed(1)}%)',
                                          color: netProfit >= 0 ? AppColors.success : AppColors.error,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // C. Clean 3-Column Payment Mode Summary (Zero Horizontal Scroll)
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PaymentColumn(
                                    label: context.isHindi ? 'नकद' : 'Cash',
                                    amount: cashRevenue,
                                    icon: Icons.payments_rounded,
                                    color: AppColors.success,
                                  ),
                                ),
                                Container(width: 1, height: 32, color: context.colorBorder),
                                Expanded(
                                  child: _PaymentColumn(
                                    label: 'UPI',
                                    amount: upiRevenue,
                                    icon: Icons.qr_code_2_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Container(width: 1, height: 32, color: context.colorBorder),
                                Expanded(
                                  child: _PaymentColumn(
                                    label: context.isHindi ? 'उधार' : 'Khata',
                                    amount: khataRevenue,
                                    icon: Icons.menu_book_rounded,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // D. Sleek 3-Tab View Switcher (Bills First by Default)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.colorBorder),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _SegmentTab(
                                    icon: Icons.shopping_bag_outlined,
                                    label: context.isHindi ? 'बिके उत्पाद' : 'Sold Items',
                                    count: allTimeSortedItems.length,
                                    isSelected: _activeTabIndex == 0,
                                    onTap: () => setState(() => _activeTabIndex = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _SegmentTab(
                                    icon: Icons.receipt_long_rounded,
                                    label: context.isHindi ? 'बिल रसीद' : 'Bills',
                                    count: recentSales.length,
                                    isSelected: _activeTabIndex == 1,
                                    onTap: () => setState(() => _activeTabIndex = 1),
                                  ),
                                ),
                                Expanded(
                                  child: _SegmentTab(
                                    icon: Icons.leaderboard_rounded,
                                    label: context.isHindi ? 'रैंकिंग' : 'Top Ranking',
                                    count: allSoldRanking.length,
                                    isSelected: _activeTabIndex == 2,
                                    onTap: () => setState(() => _activeTabIndex = 2),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // E. Customer Style Spacious Search Bar
                          AppSearchField(
                            controller: _searchController,
                            hintText: _activeTabIndex == 0
                                ? (context.isHindi ? 'उत्पाद या बिल नंबर खोजें...' : 'Search item or bill #...')
                                : (_activeTabIndex == 1
                                    ? (context.isHindi ? 'बिल नंबर या फोन नंबर खोजें...' : 'Search bill # or customer phone...')
                                    : (context.isHindi ? 'उत्पाद का नाम खोजें...' : 'Search product name...')),
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            onSubmitted: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. High-Performance Virtualized Slivers (120 FPS Buttery-Smooth Scrolling)
                  // Tab 0: Time-Sorted Sold Products Timeline
                  if (_activeTabIndex == 0) ...[
                    if (filteredSoldItems.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyState(
                            context,
                            message: _searchQuery.isNotEmpty
                                ? (context.isHindi ? 'कोई मेल खाता उत्पाद नहीं मिला' : 'No matching sold products found')
                                : (context.isHindi ? 'इस अवधि में कोई उत्पाद नहीं बिका' : 'No products sold in this period'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filteredSoldItems.length,
                          itemBuilder: (context, index) {
                            return _buildSoldProductTimelineTile(context, filteredSoldItems[index]);
                          },
                        ),
                      ),
                  ],

                  // Tab 1: Completed Sales Bills with Direct 1-Tap Actions
                  if (_activeTabIndex == 1) ...[
                    if (filteredBills.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyState(
                            context,
                            message: _searchQuery.isNotEmpty
                                ? (context.isHindi ? 'कोई मेल खाता बिल नहीं मिला' : 'No matching bills found')
                                : (context.isHindi ? 'इस अवधि में कोई बिल नहीं बना' : 'No sales bills recorded in this period'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filteredBills.length,
                          itemBuilder: (context, index) {
                            return _buildSaleBillTile(context, filteredBills[index]);
                          },
                        ),
                      ),
                  ],

                  // Tab 2: Top Selling Products Leaderboard
                  if (_activeTabIndex == 2) ...[
                    if (filteredRanking.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyState(
                            context,
                            message: _searchQuery.isNotEmpty
                                ? (context.isHindi ? 'कोई मेल खाता उत्पाद नहीं मिला' : 'No matching products found')
                                : (context.isHindi ? 'रैंकिंग के लिए अभी कोई बिक्री नहीं हुई' : 'No sales data to generate ranking'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filteredRanking.length,
                          itemBuilder: (context, index) {
                            return _buildRankingTile(context, index, filteredRanking[index], totalRevenue);
                          },
                        ),
                      ),
                  ],

                  // 3. Subtle 10-Day Retention Footer Note
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 13, color: context.colorTextMuted),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                context.isHindi
                                    ? '10-दिवसीय रोलिंग रिकॉर्ड • 10 दिन बाद स्वतः हट जाते हैं • PDF डाउनलोड कर स्थायी रखें'
                                    : '10-day rolling records • Auto-purged after 10 days • Download PDF to archive',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: context.colorTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a ranking card for top selling products
  Widget _buildRankingTile(BuildContext context, int index, Map<String, dynamic> r, double totalRevenue) {
    final name = r['name'] as String;
    final qty = (r['quantity'] ?? r['qty']) as int;
    final total = ((r['total_revenue'] ?? r['total']) as num).toDouble();
    final unitPrice = qty > 0 ? (total / qty) : 0.0;
    final pct = totalRevenue > 0 ? (total / totalRevenue) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: index == 0
                    ? const Color(0xFFFEF3C7)
                    : (index == 1
                        ? const Color(0xFFF1F5F9)
                        : (index == 2 ? const Color(0xFFFED7AA) : context.colorSurfaceSubtle)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == 0
                      ? const Color(0xFFF59E0B)
                      : (index == 1
                          ? const Color(0xFF94A3B8)
                          : (index == 2 ? const Color(0xFFF97316) : context.colorBorder)),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: index == 0
                      ? const Color(0xFFB45309)
                      : (index == 1
                          ? const Color(0xFF475569)
                          : (index == 2 ? const Color(0xFFC2410C) : context.colorTextSecondary)),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colorTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.isHindi
                        ? 'दर: ₹${unitPrice.toStringAsFixed(0)} • मात्रा: $qty इकाई'
                        : 'Rate: ₹${unitPrice.toStringAsFixed(0)} • Qty: $qty units',
                    style: TextStyle(
                      fontSize: 11.5,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: index == 0 ? AppColors.success : context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  context.isHindi
                      ? 'कुल का ${(pct * 100).toStringAsFixed(1)}%'
                      : '${(pct * 100).toStringAsFixed(1)}% of sales',
                  style: TextStyle(
                    fontSize: 10.5,
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

  /// Builds an individual timeline card for a sold product
  Widget _buildSoldProductTimelineTile(BuildContext context, SoldProductTimelineItem item) {
    final isCash = item.paymentMethod.toLowerCase() == 'cash';
    final isUpi = item.paymentMethod.toLowerCase() == 'upi';
    final modeColor = isCash ? AppColors.success : (isUpi ? AppColors.primary : AppColors.warning);
    final paymentLabel = isCash
        ? (context.isHindi ? 'नकद' : 'CASH')
        : (isUpi ? 'UPI' : (context.isHindi ? 'उधार' : 'KHATA'));

    final localTimeStr = AppDateTimeUtils.formatTime(item.soldAt);
    final relativeTimeStr = AppDateTimeUtils.formatRelativeDate(item.soldAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: modeColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colorTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: context.colorTextMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$localTimeStr ($relativeTimeStr)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.colorTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.billNumber.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text('•', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${context.isHindi ? 'बिल' : 'Bill'} #${item.billNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colorTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} ${context.isHindi ? 'इकाई' : 'units'} × ₹${item.unitPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item.totalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                AppBadge(
                  label: paymentLabel,
                  type: isCash
                      ? AppBadgeType.success
                      : (isUpi ? AppBadgeType.primary : AppBadgeType.warning),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a high-utility invoice passbook card for a completed bill with exact time, clean spacing, and direct 1-tap actions
  Widget _buildSaleBillTile(BuildContext context, SaleModel sale) {
    final localDt = sale.createdAt.toLocal();
    final timeStr = AppDateTimeUtils.formatTime(localDt);
    final dateStr = DateFormat('dd MMM yyyy').format(localDt);

    final isCash = sale.paymentMethod.toLowerCase() == 'cash';
    final isUpi = sale.paymentMethod.toLowerCase() == 'upi';
    final isSplit = sale.paymentMethod.toLowerCase() == 'split' || sale.splitPayments != null;

    final Color modeColor = isSplit
        ? const Color(0xFF8B5CF6)
        : (isCash ? AppColors.success : (isUpi ? AppColors.primary : AppColors.warning));

    final String paymentLabel = isSplit
        ? (context.isHindi ? 'विभाजित' : 'SPLIT')
        : (isCash
            ? (context.isHindi ? 'नकद' : 'CASH')
            : (isUpi ? 'UPI' : (context.isHindi ? 'उधार' : 'KHATA')));

    final String customerText = sale.customerPhone.isNotEmpty
        ? sale.customerPhone
        : (context.isHindi ? 'काउंटर ग्राहक' : 'Walk-in Customer');

    final authShop = context.read<AuthController>().currentShop;
    final cachedShop = LocalCacheService.getShop();
    final shop = authShop ?? cachedShop;
    final rawShopName = (shop?.name ?? '').trim();
    final shopName = rawShopName.isNotEmpty && rawShopName != 'ShopSilo Retail Store'
        ? rawShopName
        : (cachedShop?.name.trim().isNotEmpty ?? false
            ? cachedShop!.name.trim()
            : 'ShopSilo Retail Store');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _showSaleActionsSheet(context, sale),
        child: Column(
          children: [
            // Row 1: Bill Header & Amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSplit
                        ? Icons.call_split_rounded
                        : (isCash ? Icons.payments_rounded : (isUpi ? Icons.qr_code_2_rounded : Icons.menu_book_rounded)),
                    color: modeColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${context.isHindi ? 'बिल' : 'Bill'} #${sale.billNumber ?? "1001"}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.colorTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 11, color: context.colorTextMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sale.items.length} ${context.isHindi ? 'सामान' : 'items'} • $customerText • $dateStr',
                        style: TextStyle(fontSize: 11.5, color: context.colorTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹${sale.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: context.colorTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppBadge(
                      label: paymentLabel,
                      type: isCash
                          ? AppBadgeType.success
                          : (isUpi ? AppBadgeType.primary : AppBadgeType.warning),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: context.colorBorder),
            const SizedBox(height: 8),

            // Row 2: Direct 1-Tap Quick Actions Bar (Share, Print, Return)
            Row(
              children: [
                // Quick 1-Tap Universal Native Share (0ms from byte cache)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      context.read<PosController>().shareThermalReceiptPdf(
                        sale,
                        shopName,
                        shopAddress: shop?.address ?? '',
                        shopPhone: shop?.phone ?? shop?.whatsappNumber ?? '',
                        shopGstin: shop?.gstin ?? '',
                        upiId: shop?.upiId ?? '',
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.share_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                context.isHindi ? 'शेयर' : 'Share',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Quick 1-Tap Thermal Printer Layout (0ms from byte cache)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      context.read<PosController>().generateThermalReceiptPdf(
                        context,
                        sale,
                        shopName,
                        shopAddress: shop?.address ?? '',
                        shopPhone: shop?.phone ?? shop?.whatsappNumber ?? '',
                        shopGstin: shop?.gstin ?? '',
                        upiId: shop?.upiId ?? '',
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      decoration: BoxDecoration(
                        color: context.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colorBorder),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_rounded, size: 14, color: context.colorTextPrimary),
                              const SizedBox(width: 4),
                              Text(
                                context.isHindi ? 'प्रिंट' : 'Print',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.colorTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Quick 1-Tap Return Action
                Expanded(
                  child: InkWell(
                    onTap: () {
                      PosBillReturnModal.show(
                        context,
                        sale: sale,
                        onReturnSuccess: () {
                          context.read<PosController>().fetchBackendSales();
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_return_rounded, size: 14, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Text(
                                context.isHindi ? 'वापसी' : 'Return',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaItem(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isBold ? 12 : 11.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold ? context.colorTextPrimary : context.colorTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showSaleActionsSheet(BuildContext context, SaleModel sale) {
    final isHindi = context.isHindi;
    final authShop = context.read<AuthController>().currentShop;
    final cachedShop = LocalCacheService.getShop();
    final shop = authShop ?? cachedShop;
    final rawShopName = (shop?.name ?? '').trim();
    final shopName = rawShopName.isNotEmpty && rawShopName != 'ShopSilo Retail Store'
        ? rawShopName
        : (cachedShop?.name.trim().isNotEmpty ?? false
            ? cachedShop!.name.trim()
            : 'ShopSilo Retail Store');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          top: 14,
          left: 20,
          right: 20,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8,
          maxWidth: 580,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isHindi ? 'बिल' : 'Bill'} #${sale.billNumber ?? "WALK-IN"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${sale.items.length} ${isHindi ? 'वस्तुएं' : 'items'} • ₹${sale.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Items summary list
              ...sale.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final rawName = item.product.name.trim();
                final cleanName = rawName.isNotEmpty ? rawName : 'Item #${idx + 1}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$cleanName (×${item.quantity})',
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),

              // Action Buttons
              // 1. Share Thermal Receipt (Bluetooth, WhatsApp, Instagram, etc.)
              AppButton(
                text: isHindi ? 'रसीद शेयर करें (WhatsApp, Bluetooth...)' : 'Share Receipt (WhatsApp, Bluetooth...)',
                icon: Icons.share_rounded,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.read<PosController>().shareThermalReceiptPdf(
                    sale,
                    shopName,
                    shopAddress: shop?.address ?? '',
                    shopPhone: shop?.phone ?? shop?.whatsappNumber ?? '',
                    shopGstin: shop?.gstin ?? '',
                    upiId: shop?.upiId ?? '',
                  );
                },
              ),
              const SizedBox(height: 8),

              // 2. Print Thermal Receipt
              AppButton.outline(
                text: isHindi ? 'थर्मल रसीद प्रिंट करें (58mm/80mm)' : 'Print Thermal Slip (58mm/80mm)',
                icon: Icons.print_rounded,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.read<PosController>().generateThermalReceiptPdf(
                    context,
                    sale,
                    shopName,
                    shopAddress: shop?.address ?? '',
                    shopPhone: shop?.phone ?? shop?.whatsappNumber ?? '',
                    shopGstin: shop?.gstin ?? '',
                    upiId: shop?.upiId ?? '',
                  );
                },
              ),
              const SizedBox(height: 8),

              // 3. Process Bill Return & Restock
              AppButton.outline(
                text: isHindi ? 'सामान वापसी / रिफंड दर्ज करें (Return)' : 'Process Return & Restock',
                icon: Icons.assignment_return_rounded,
                customColor: AppColors.warning,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  PosBillReturnModal.show(
                    context,
                    sale: sale,
                    onReturnSuccess: () {
                      context.read<PosController>().fetchBackendSales();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {String? message}) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            message ?? context.tr('today_sales_empty_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: context.colorTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('today_sales_empty_sub'),
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
              context.tr('today_sales_open_pos'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.go('/merchant/pos'),
          ),
        ],
      ),
    );
  }
}

/// Period Tab button for switching between Today (24h) and 10 Days
class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primary : context.colorTextMuted,
          ),
        ),
      ),
    );
  }
}

/// Balanced Vertical Payment Column inside the clean 3-part card
class _PaymentColumn extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _PaymentColumn({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colorTextMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: context.colorTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented tab button for switching between Sold Items, Bills, and Ranking
class _SegmentTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? AppColors.primary : context.colorTextMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? context.colorTextPrimary : context.colorTextSecondary,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : context.colorBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primary : context.colorTextMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
