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
import '../controllers/pos_controller.dart';
import '../models/pos_model.dart';
import '../repositories/pos_advanced_repository.dart';
import '../widgets/day_close_reconciliation_sheet.dart';
import '../widgets/pos_bill_return_modal.dart';
import '../../auth/controllers/auth_controller.dart';

class TodaySalesScreen extends StatefulWidget {
  const TodaySalesScreen({super.key});

  @override
  State<TodaySalesScreen> createState() => _TodaySalesScreenState();
}

class _TodaySalesScreenState extends State<TodaySalesScreen> {
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().fetchBackendSales();
    });
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
                ? 'हेडलेस क्रोम द्वारा स्वचालित P&L रिपोर्ट बनाई जा रही है...'
                : 'Generating automated Chromedp P&L PDF report...'),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );

    final res = await PosAdvancedRepository().downloadEndOfDayReportPdfBytes();
    setState(() => _isDownloadingPdf = false);

    if (res.success && res.data != null) {
      await Printing.layoutPdf(
        onLayout: (format) async => res.data!,
        name: 'ShopSilo_Executive_EOD_Report.pdf',
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
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final soldProducts = pos.get24HourSoldProductsSummary();
    final recentSales = pos.serverSales.isNotEmpty ? pos.serverSales : LocalCacheService.get24HourSales();
    final totalRevenue = pos.today24hRevenue;
    final totalBills = pos.today24hBillCount;

    final int totalUnitsSold = soldProducts.fold(0, (sum, item) => sum + (item['qty'] as int));

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
          context.isHindi ? 'आज की बिक्री' : "Today's Sales",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.colorTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: _isDownloadingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
            tooltip: context.isHindi ? 'P&L PDF डाउनलोड करें' : 'Download Executive P&L PDF',
            onPressed: _isDownloadingPdf ? null : _downloadEodPdf,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.colorTextPrimary, size: 22),
            tooltip: context.isHindi ? 'अतिरिक्त विकल्प' : 'More Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
            onSelected: (val) async {
              switch (val) {
                case 'eod_pdf':
                  await _downloadEodPdf();
                  break;
                case 'day_close':
                  DayCloseReconciliationSheet.show(context);
                  break;
                case 'refresh':
                  await context.read<PosController>().fetchBackendSales();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.isHindi ? '✓ आज की बिक्री का डेटा रीफ्रेश हुआ' : '✓ Sales data refreshed'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                  break;
                case 'pos':
                  context.go('/merchant/pos');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'eod_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'स्वचालित P&L PDF रिपोर्ट' : 'Automated P&L PDF Report'),
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
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: ctx.colorTextPrimary, size: 18),
                    const SizedBox(width: 10),
                    Text(ctx.isHindi ? 'बिक्री डेटा रीफ्रेश करें' : 'Refresh Sales Data'),
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
                  // 1. Executive Summary Metric Cards (Total Revenue & Bills)
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('today_sales_total_rev'),
                          value: '₹${totalRevenue.toStringAsFixed(0)}',
                          subtitle: context.isHindi ? 'आज के 24 घंटों की बिक्री' : 'Last 24 hours sales',
                          icon: Icons.currency_rupee_rounded,
                          iconColor: AppColors.success,
                          iconBgColor: context.colorSuccessLight,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppStatCard(
                          title: context.tr('today_sales_total_bills'),
                          value: '$totalBills',
                          subtitle: '$totalUnitsSold ${context.isHindi ? 'सामान बिके' : 'Units Sold'}',
                          icon: Icons.receipt_long_rounded,
                          iconColor: AppColors.primary,
                          iconBgColor: context.colorPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Payment Method Breakdown Strip (Cash, UPI, Khata)
                  if (totalRevenue > 0) ...[
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PaymentPill(
                              label: context.isHindi ? 'नकद' : 'Cash',
                              amount: cashRevenue,
                              icon: Icons.payments_rounded,
                              color: AppColors.success,
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: context.colorBorder,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _PaymentPill(
                              label: 'UPI',
                              amount: upiRevenue,
                              icon: Icons.qr_code_2_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: context.colorBorder,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _PaymentPill(
                              label: context.isHindi ? 'उधार' : 'Credit',
                              amount: khataRevenue,
                              icon: Icons.menu_book_rounded,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 2B. Chromedp Automated Executive P&L PDF Report
                  InkWell(
                    onTap: _isDownloadingPdf ? null : _downloadEodPdf,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isDownloadingPdf
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.isHindi ? 'स्वचालित दैनिक P&L रिपोर्ट (PDF)' : 'Executive End-of-Day P&L PDF',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.isHindi
                                      ? 'हेडलेस क्रोम द्वारा पूर्ण वित्तीय विश्लेषण व गल्ला मिलान रसीद'
                                      : 'Chromedp automated daily profit & loss breakdown with shift telemetry',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFDC2626)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Section Header: Sold Products Ranking
                  AppSectionHeader(
                    title: context.isHindi ? 'बिके हुए उत्पाद (24 घंटे)' : 'Products Sold (Last 24 Hours)',
                    trailing: AppBadge(
                      label: '${soldProducts.length} ${context.isHindi ? 'उत्पाद' : 'Products'}',
                      type: AppBadgeType.neutral,
                    ),
                  ),

                  // 4. Products List or Empty State
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
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Rank badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? context.colorSuccessLight
                                      : context.colorSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: index == 0
                                        ? AppColors.success.withValues(alpha: 0.3)
                                        : context.colorBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: index == 0 ? AppColors.success : context.colorTextSecondary,
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

                  const SizedBox(height: 18),

                  // 5. Section: Recent Completed Bills
                  if (recentSales.isNotEmpty) ...[
                    AppSectionHeader(
                      title: context.tr('today_sales_recent_bills_header'),
                      trailing: AppBadge(
                        label: '${recentSales.length} ${context.isHindi ? 'बिल' : 'Bills'}',
                        type: AppBadgeType.neutral,
                      ),
                    ),
                    ...(List<SaleModel>.from(recentSales)..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                        .take(30)
                        .map((sale) => _buildSaleBillTile(context, sale)),
                  ],

                  const SizedBox(height: 28),
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

    String paymentLabel = isCash
        ? (context.isHindi ? 'नकद' : 'CASH')
        : (isUpi ? 'UPI' : (context.isHindi ? 'उधार' : 'KHATA'));

    String customerText = sale.customerPhone.isNotEmpty
        ? sale.customerPhone
        : (context.isHindi ? 'काउंटर ग्राहक' : 'Walk-in Customer');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
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
                  label: paymentLabel,
                  type: isCash
                      ? AppBadgeType.success
                      : (isUpi ? AppBadgeType.primary : AppBadgeType.warning),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showSaleActionsSheet(context, sale),
      ),
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
              // 1. Print Thermal Receipt (Reusable AppButton)
              AppButton(
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

              // 2. Process Bill Return & Restock (Reusable AppButton)
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

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('today_sales_empty_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
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
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale_rounded, size: 17),
            label: Text(
              context.tr('today_sales_open_pos'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.go('/merchant/pos'),
          ),
        ],
      ),
    );
  }
}

/// Compact payment breakdown pill inside Today's Sales
class _PaymentPill extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _PaymentPill({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colorTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.colorTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
