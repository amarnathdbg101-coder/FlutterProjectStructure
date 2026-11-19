import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _showProfitBreakdown = false; // Toggle P&L breakdown drawer
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
    final maxAge = _selectedWindowDays == 1 ? const Duration(hours: 24) : const Duration(days: 10);
    final allTimeSortedItems = pos.getTimeSortedSoldItems(maxAge: maxAge);
    final allSales = pos.serverSales.isNotEmpty ? pos.serverSales : LocalCacheService.get10DaySales();
    final cutoff = DateTime.now().subtract(maxAge);
    final recentSales = allSales.where((s) => s.createdAt.isAfter(cutoff)).toList();

    final totalRevenue = recentSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalBills = recentSales.length;

    double cashRevenue = 0;
    double upiRevenue = 0;
    double khataRevenue = 0;
    for (final sale in recentSales) {
      final method = sale.paymentMethod.toLowerCase();
      if (method == 'cash') {
        cashRevenue += sale.totalAmount;
      } else if (method == 'upi') {
        upiRevenue += sale.totalAmount;
      } else if (method == 'khata') {
        khataRevenue += sale.totalAmount;
      }
    }

    final cachedShop = LocalCacheService.getShop();
    final effectiveShopName = (cachedShop?.name.trim().isNotEmpty ?? false)
        ? cachedShop!.name.trim()
        : 'ShopSilo Partner Store';

    try {
      // ⚡ Direct 1-Tap Universal Native Share Sheet (Bluetooth, WhatsApp, Instagram, Quick Share, etc.)
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
    } catch (err) {
      debugPrint('[SalesPDF] Local generation error: $err, falling back to backend');
      final res = await PosAdvancedRepository().downloadEndOfDayReportPdfBytes(
        days: _selectedWindowDays,
      );
      if (res.success && res.data != null) {
        final fileName = _selectedWindowDays > 1
            ? 'ShopSilo_${_selectedWindowDays}Day_Sales_Journal.pdf'
            : 'ShopSilo_Today_Sales_Report.pdf';
        await Printing.layoutPdf(
          onLayout: (format) async => res.data!,
          name: fileName,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Failed to download P&L PDF report'),
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
    final maxAge = _selectedWindowDays == 1 ? const Duration(hours: 24) : const Duration(days: 10);

    final allTimeSortedItems = pos.getTimeSortedSoldItems(maxAge: maxAge);
    final allSoldRanking = pos.getSoldProductsSummary(maxAge: maxAge);
    final allSales = pos.serverSales.isNotEmpty ? pos.serverSales : LocalCacheService.get10DaySales();
    final cutoff = DateTime.now().subtract(maxAge);
    final recentSales = allSales.where((s) => s.createdAt.isAfter(cutoff)).toList();
    recentSales.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalRevenue = recentSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalBills = recentSales.length;
    final int totalUnitsSold = allTimeSortedItems.fold(0, (sum, item) => sum + item.quantity);

    // Calculate Payment Method Breakdown (Cash vs UPI vs Khata)
    double cashRevenue = 0;
    double upiRevenue = 0;
    double khataRevenue = 0;
    for (final sale in recentSales) {
      final method = sale.paymentMethod.toLowerCase();
      if (method == 'cash') {
        cashRevenue += sale.totalAmount;
      } else if (method == 'upi') {
        upiRevenue += sale.totalAmount;
      } else if (method == 'khata') {
        khataRevenue += sale.totalAmount;
      }
    }

    // Dynamic Real-time COGS and Net Profit Calculation
    double totalCogs = 0.0;
    for (final sale in recentSales) {
      for (final item in sale.items) {
        final cost = item.product.costPrice > 0 ? item.product.costPrice : (item.customPrice * 0.75);
        totalCogs += cost * item.quantity;
      }
    }
    final grossProfit = totalRevenue - totalCogs;
    final proratedExpenses = _selectedWindowDays == 1
        ? ((analytics?.totalExpenses ?? 0.0) / 30.0)
        : ((analytics?.totalExpenses ?? 0.0) / 3.0);
    final effectiveExpenses = proratedExpenses > 0 ? proratedExpenses : 0.0;
    final netProfit = grossProfit - effectiveExpenses;
    final marginPct = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100).clamp(-100.0, 100.0) : 0.0;

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
          // Quick Universal Native Share (Bluetooth, WhatsApp, Instagram, etc.)
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ResponsiveContainer(
              maxWidth: 780,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Consolidated Executive Hero Card (Sales + Profit Unified)
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Live indicator & Duration Pill Switcher
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  is10Days
                                      ? (context.isHindi ? '10-दिवसीय बिक्री व मुनाफा' : '10-DAY TOTAL SALES')
                                      : (context.isHindi ? 'आज की कुल बिक्री व मुनाफा' : "TODAY'S TOTAL SALES"),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: context.colorTextMuted,
                                  ),
                                ),
                              ],
                            ),
                            // Compact Duration Switcher Pill
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: context.colorSurfaceSubtle,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MiniPill(
                                    label: context.isHindi ? 'आज (24h)' : 'Today',
                                    isSelected: !is10Days,
                                    onTap: () => setState(() => _selectedWindowDays = 1),
                                  ),
                                  _MiniPill(
                                    label: context.isHindi ? '10 दिन' : '10 Days',
                                    isSelected: is10Days,
                                    onTap: () => setState(() => _selectedWindowDays = 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Prominent Revenue & Profit Metrics
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 420;
                            final salesCol = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.isHindi ? 'कुल बिक्री (Sales)' : 'Total Sales',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colorTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${totalRevenue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: context.colorTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalBills ${context.isHindi ? 'बिल' : 'bills'} • $totalUnitsSold ${context.isHindi ? 'सामान' : 'items'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.colorTextMuted,
                                  ),
                                ),
                              ],
                            );

                            final profitCol = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.isHindi ? 'शुद्ध मुनाफा' : 'Net Profit',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${netProfit >= 0 ? "+" : ""}₹${netProfit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: netProfit >= 0 ? AppColors.success : AppColors.error,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AppBadge(
                                    label: '${marginPct.toStringAsFixed(1)}% ${context.isHindi ? 'मार्जिन' : 'margin'}',
                                    type: netProfit >= 0 ? AppBadgeType.success : AppBadgeType.error,
                                  ),
                                ],
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  salesCol,
                                  const SizedBox(height: 12),
                                  profitCol,
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: salesCol),
                                const SizedBox(width: 12),
                                profitCol,
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),
                        Divider(height: 1, color: context.colorBorder),
                        const SizedBox(height: 12),

                        // Cash, UPI, Khata breakdown bar & Interactive Profit Toggle
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _MiniMetric(
                                label: context.isHindi ? 'नकद' : 'Cash',
                                amount: cashRevenue,
                                color: AppColors.success,
                                icon: Icons.payments_rounded,
                              ),
                              Container(width: 1, height: 18, color: context.colorBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
                              _MiniMetric(
                                label: 'UPI',
                                amount: upiRevenue,
                                color: AppColors.primary,
                                icon: Icons.qr_code_2_rounded,
                              ),
                              Container(width: 1, height: 18, color: context.colorBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
                              _MiniMetric(
                                label: context.isHindi ? 'उधार' : 'Khata',
                                amount: khataRevenue,
                                color: AppColors.warning,
                                icon: Icons.menu_book_rounded,
                              ),
                              Container(width: 1, height: 18, color: context.colorBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),

                              // Interactive Profit Breakdown Toggle Pill
                              InkWell(
                                onTap: () => setState(() => _showProfitBreakdown = !_showProfitBreakdown),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _showProfitBreakdown ? AppColors.primary.withValues(alpha: 0.12) : context.colorSurfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _showProfitBreakdown ? AppColors.primary : context.colorBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showProfitBreakdown ? Icons.keyboard_arrow_up_rounded : Icons.calculate_outlined,
                                        size: 14,
                                        color: _showProfitBreakdown ? AppColors.primary : context.colorTextSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.isHindi ? 'मुनाफा हिसाब' : 'P&L Details',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _showProfitBreakdown ? AppColors.primary : context.colorTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Quick PDF Export Pill
                              InkWell(
                                onTap: _isDownloadingPdf ? null : _downloadEodPdf,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.isHindi ? 'P&L PDF' : 'P&L PDF',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ⚡ Expandable Profit & Expenses Calculation Details Box
                        if (_showProfitBreakdown) ...[
                          const SizedBox(height: 14),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    InkWell(
                                      onTap: () => context.push('/merchant/analytics'),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            context.isHindi ? 'विस्तृत रिपोर्ट →' : 'Full Report →',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildFormulaItem(
                                  context,
                                  title: context.isHindi ? '+ कुल बिक्री आय (Sales Revenue)' : '+ Total Sales Revenue',
                                  value: '+₹${totalRevenue.toStringAsFixed(0)}',
                                  color: AppColors.success,
                                ),
                                const SizedBox(height: 4),
                                _buildFormulaItem(
                                  context,
                                  title: context.isHindi ? '- सामान खरीद लागत (Estimated COGS)' : '- Cost of Goods Sold (COGS)',
                                  value: '-₹${totalCogs.toStringAsFixed(0)}',
                                  color: AppColors.error,
                                ),
                                if (effectiveExpenses > 0) ...[
                                  const SizedBox(height: 4),
                                  _buildFormulaItem(
                                    context,
                                    title: context.isHindi ? '- दुकान खर्चे (Expenses)' : '- Store Expenses',
                                    value: '-₹${effectiveExpenses.toStringAsFixed(0)}',
                                    color: AppColors.error,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Divider(height: 1, color: context.colorBorder),
                                const SizedBox(height: 6),
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

                  const SizedBox(height: 12),

                  // 2. Sleek 3-Tab Segmented Switcher (Preserves clean tab state)
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

                  // 3. Customer Style Spacious Search Bar
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

                  const SizedBox(height: 10),

                  // 4. Tab 0: Time-Sorted Sold Products Timeline
                  if (_activeTabIndex == 0) ...[
                    if (filteredSoldItems.isEmpty)
                      _buildEmptyState(
                        context,
                        message: _searchQuery.isNotEmpty
                            ? (context.isHindi ? 'कोई मेल खाता उत्पाद नहीं मिला' : 'No matching sold products found')
                            : (context.isHindi ? 'इस अवधि में कोई उत्पाद नहीं बिका' : 'No products sold in this period'),
                      )
                    else
                      ...filteredSoldItems.map((item) => _buildSoldProductTimelineTile(context, item)),
                  ],

                  // 5. Tab 1: Completed Sales Bills with Direct 1-Tap Actions
                  if (_activeTabIndex == 1) ...[
                    if (filteredBills.isEmpty)
                      _buildEmptyState(
                        context,
                        message: _searchQuery.isNotEmpty
                            ? (context.isHindi ? 'कोई मेल खाता बिल नहीं मिला' : 'No matching bills found')
                            : (context.isHindi ? 'इस अवधि में कोई बिल नहीं बना' : 'No sales bills recorded in this period'),
                      )
                    else
                      ...filteredBills.map((sale) => _buildSaleBillTile(context, sale)),
                  ],

                  // 6. Tab 2: Top Selling Products Leaderboard
                  if (_activeTabIndex == 2) ...[
                    if (filteredRanking.isEmpty)
                      _buildEmptyState(
                        context,
                        message: _searchQuery.isNotEmpty
                            ? (context.isHindi ? 'कोई मेल खाता उत्पाद नहीं मिला' : 'No matching products found')
                            : (context.isHindi ? 'रैंकिंग के लिए अभी कोई बिक्री नहीं हुई' : 'No sales data to generate ranking'),
                      )
                    else
                      ...filteredRanking.asMap().entries.map((entry) {
                        final index = entry.key;
                        final r = entry.value;
                        final name = r['name'] as String;
                        final qty = r['quantity'] as int;
                        final total = (r['total_revenue'] as num).toDouble();
                        final unitPrice = qty > 0 ? (total / qty) : 0.0;
                        final pct = totalRevenue > 0 ? (total / totalRevenue) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Rank Badge (Clean metallic badge, strictly zero rainbow)
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
                      }),
                  ],

                  const SizedBox(height: 14),

                  // 7. Subtle 10-Day Retention Footer Note
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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

    final relativeTimeStr = AppDateTimeUtils.formatRelativeDate(item.soldAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mode Indicator Icon (Clean bag icon, strictly no vegetable icons)
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

            // Product name, time, bill number, qty & rate
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
                      Text(
                        relativeTimeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.colorTextSecondary,
                        ),
                      ),
                      if (item.billNumber.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(fontSize: 11, color: context.colorTextMuted)),
                        const SizedBox(width: 6),
                        Text(
                          '${context.isHindi ? 'बिल' : 'Bill'} #${item.billNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.colorTextSecondary,
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

            // Total price & payment badge
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

  /// Builds a high-utility invoice passbook card for a completed bill with direct 1-tap Share & Print
  Widget _buildSaleBillTile(BuildContext context, SaleModel sale) {
    final timeStr = AppDateTimeUtils.formatTime(sale.createdAt);
    final isCash = sale.paymentMethod.toLowerCase() == 'cash';
    final isUpi = sale.paymentMethod.toLowerCase() == 'upi';

    final Color modeColor = isCash ? AppColors.success : (isUpi ? AppColors.primary : AppColors.warning);

    final String paymentLabel = isCash
        ? (context.isHindi ? 'नकद' : 'CASH')
        : (isUpi ? 'UPI' : (context.isHindi ? 'उधार' : 'KHATA'));

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
                    isCash ? Icons.payments_rounded : (isUpi ? Icons.qr_code_2_rounded : Icons.menu_book_rounded),
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
                        '${sale.items.length} ${context.isHindi ? 'सामान' : 'items'} • $customerText',
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
                    Text(
                      '₹${sale.totalAmount.toStringAsFixed(0)}',
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

            const SizedBox(height: 10),
            Divider(height: 1, color: context.colorBorder),
            const SizedBox(height: 8),

            // Row 2: Direct 1-Tap Quick Actions Bar (Share, Print, Return)
            Row(
              children: [
                // Quick 1-Tap Universal Native Share
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 5),
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
                const SizedBox(width: 8),

                // Quick 1-Tap Thermal Printer Layout
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colorSurfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colorBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_rounded, size: 14, color: context.colorTextPrimary),
                          const SizedBox(width: 5),
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
                const SizedBox(width: 8),

                // Quick 1-Tap Return Action
                InkWell(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 12 : 11.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? context.colorTextPrimary : context.colorTextSecondary,
          ),
        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isHindi ? 'बिल' : 'Bill'} #${sale.billNumber ?? "WALK-IN"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${sale.items.length} ${isHindi ? 'वस्तुएं' : 'items'} • ₹${sale.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
                      ),
                    ],
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

/// Compact duration switcher pill inside the Hero Card
class _MiniPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MiniPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
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
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primary : context.colorTextMuted,
          ),
        ),
      ),
    );
  }
}

/// Compact inline metric for Cash, UPI, and Khata in the Hero Card
class _MiniMetric extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colorTextMuted,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
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
        child: Row(
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
    );
  }
}
