import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_drawer.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/reservation_controller.dart';
import '../models/reservation_model.dart';

class ReservationsListScreen extends StatefulWidget {
  const ReservationsListScreen({super.key});

  @override
  State<ReservationsListScreen> createState() => _ReservationsListScreenState();
}

class _ReservationsListScreenState extends State<ReservationsListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservationController>().loadReservations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // DIALOG: 1-TAP COUNTER OTP / QR VERIFICATION
  // ==========================================
  void _showVerifyCodeDialog(BuildContext context, {ReservationModel? prefillReservation}) {
    final codeCtrl = TextEditingController(text: prefillReservation?.pickupCode ?? '');
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isHindi ? 'काउंटर पिकअप कोड सत्यापित करें' : 'Verify Counter Pickup Code',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                prefillReservation != null
                                    ? (context.isHindi ? '${prefillReservation.customerName} के लिए कोड पुष्टि करें' : 'Confirm code for ${prefillReservation.customerName}')
                                    : (context.isHindi ? '6-अंकों का पिकअप कोड या ऑर्डर नंबर दर्ज करें' : 'Enter 6-digit pickup code or reservation number'),
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.text,
                      maxLength: 25,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
                      decoration: InputDecoration(
                        hintText: context.isHindi ? 'उदा. 582914 या HLD-...' : 'e.g. 582914 or HLD-...',
                        counterText: '',
                        prefixIcon: const Icon(Icons.pin_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isVerifying ? null : () => Navigator.pop(dialogCtx),
                          child: Text(context.tr('btn_cancel')),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  final code = codeCtrl.text.trim();
                                  if (code.length < 4) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(context.isHindi ? 'कृपया मान्य कोड दर्ज करें (कम से कम 4 अक्षर)' : 'Please enter valid pickup code (at least 4 characters)')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isVerifying = true);
                                  final ok = await context.read<ReservationController>().verifyPickupCode(
                                    code,
                                    reservationNumber: prefillReservation?.reservationNumber,
                                  );
                                  if (ctx.mounted) {
                                    setDialogState(() => isVerifying = false);
                                    if (ok) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(context.isHindi ? '✓ काउंटर पिकअप कोड सत्यापित एवं पूर्ण हुआ!' : '✓ Counter Pickup Code Verified & Completed Successfully!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      final err = context.read<ReservationController>().errorMessage ?? (context.isHindi ? 'अमान्य पिकअप कोड' : 'Invalid pickup code');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err), backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                          child: isVerifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(context.isHindi ? 'सत्यापित एवं पूर्ण करें' : 'Verify & Complete', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resCtrl = context.watch<ReservationController>();
    final authCtrl = context.watch<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shop = authCtrl.currentShop;

    return MerchantShell(
      currentIndex: 0,
      appBar: AppBar(
        title: const Text(
          'Customer Pickup Orders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Verify Counter Pickup Code',
            onPressed: () => _showVerifyCodeDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: context.isHindi ? 'पिकअप ऑर्डर्स रीफ्रेश करें' : 'Refresh Counter Pickup Orders',
            onPressed: () async {
              await resCtrl.loadReservations();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.isHindi ? '✓ काउंटर पिकअप ऑर्डर्स रीफ्रेश हुए' : '✓ Counter Pickup Orders Refreshed'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      drawer: MerchantDrawer(
        onShowQr: (slug, name) => showStoreQrDialog(context, shop),
      ),
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.pin_rounded, color: Colors.white),
          label: Text(
            context.isHindi ? 'पिकअप कोड सत्यापित करें' : 'Verify Pickup Code',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showVerifyCodeDialog(context),
        ),
        body: RefreshIndicator(
          onRefresh: () => resCtrl.loadReservations(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ResponsiveContainer(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Real-Time Incoming Order Flash Alert
                if (resCtrl.latestAlertReservation != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isHindi
                                    ? '🔔 नया पिकअप ऑर्डर प्राप्त हुआ! (#${resCtrl.latestAlertReservation!.pickupCode})'
                                    : '🔔 New Pickup Order Received! (#${resCtrl.latestAlertReservation!.pickupCode})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                              ),
                              Text(
                                context.isHindi
                                    ? '${resCtrl.latestAlertReservation!.customerName} ने ${resCtrl.latestAlertReservation!.productName} का ऑर्डर दिया (मात्रा: ${resCtrl.latestAlertReservation!.quantity})'
                                    : '${resCtrl.latestAlertReservation!.customerName} ordered ${resCtrl.latestAlertReservation!.productName} (Qty: ${resCtrl.latestAlertReservation!.quantity})',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => resCtrl.clearLatestAlert(),
                        ),
                      ],
                    ),
                  ),
                ],

                // Summary Banner
                AppSummaryBanner(
                  title: context.isHindi ? 'सक्रिय काउंटर पिकअप ऑर्डर्स' : 'Active Counter Pickup Orders',
                  amount: context.isHindi ? '${resCtrl.activeCount} लंबित' : '${resCtrl.activeCount} Pending',
                  subtitle: context.isHindi
                      ? '${resCtrl.totalCount} कुल ऑर्डर्स • ${resCtrl.completedCount} पूर्ण'
                      : '${resCtrl.totalCount} Total Orders • ${resCtrl.completedCount} Completed',
                  icon: Icons.shopping_bag_outlined,
                  actionLabel: context.isHindi ? 'कोड सत्यापित करें' : 'Verify Code',
                  onAction: () => _showVerifyCodeDialog(context),
                ),

                // KPI Stat Cards Row
                Row(
                  children: [
                    Expanded(
                      child: AppStatCard(
                        title: context.isHindi ? 'सक्रिय ऑर्डर्स' : 'Active Orders',
                        value: '${resCtrl.activeCount}',
                        subtitle: context.isHindi ? 'पिकअप प्रतीक्षारत' : 'Awaiting Pickup',
                        icon: Icons.pending_actions_rounded,
                        isAlert: resCtrl.activeCount > 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: context.isHindi ? 'पूर्ण ऑर्डर्स' : 'Completed',
                        value: '${resCtrl.completedCount}',
                        subtitle: context.isHindi ? 'काउंटर पर सत्यापित' : 'Verified at Counter',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: context.isHindi ? 'रद्द ऑर्डर्स' : 'Cancelled',
                        value: '${resCtrl.cancelledCount}',
                        subtitle: context.isHindi ? 'समाप्त / रद्द' : 'Expired / Cancelled',
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.isHindi ? 'ग्राहक नाम, मोबाइल या कोड (#582914) से खोजें...' : 'Search by Customer Name, Mobile, Code (#582914)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              resCtrl.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) => resCtrl.setSearchQuery(query),
                ),
                const SizedBox(height: 10),

                // Status Segment Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(context.isHindi ? 'सभी ऑर्डर्स' : 'All Orders', resCtrl.totalCount, resCtrl.activeTab == 'all', () => resCtrl.setActiveTab('all')),
                      const SizedBox(width: 8),
                      _buildFilterChip(context.isHindi ? 'सक्रिय / लंबित' : 'Active / Pending', resCtrl.activeCount, resCtrl.activeTab == 'pending', () => resCtrl.setActiveTab('pending'), isAlert: resCtrl.activeCount > 0),
                      const SizedBox(width: 8),
                      _buildFilterChip(context.isHindi ? 'पूर्ण ऑर्डर्स' : 'Completed', resCtrl.completedCount, resCtrl.activeTab == 'completed', () => resCtrl.setActiveTab('completed')),
                      const SizedBox(width: 8),
                      _buildFilterChip(context.isHindi ? 'रद्द ऑर्डर्स' : 'Cancelled', resCtrl.cancelledCount, resCtrl.activeTab == 'cancelled', () => resCtrl.setActiveTab('cancelled')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Orders List
                resCtrl.isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    : resCtrl.filteredReservations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(context.isHindi ? 'कोई काउंटर पिकअप ऑर्डर नहीं मिला' : 'No counter pickup orders found', style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: resCtrl.filteredReservations.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = resCtrl.filteredReservations[index];
                              return _buildReservationCard(context, item, resCtrl, isDark);
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildFilterChip(String label, int count, bool isSelected, VoidCallback onSelected, {bool isAlert = false}) {
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : (isAlert ? AppColors.error : AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isAlert ? AppColors.error : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildDetailChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
    );
  }

  void _showReservationDetailSheet(
    BuildContext context,
    ReservationModel r,
    ReservationController resCtrl,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.isHindi ? 'पिकअप ऑर्डर विवरण' : 'Pickup Order Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${context.isHindi ? 'ऑर्डर' : 'Order'} #${r.pickupCode} • ${r.reservationNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: r.status.toUpperCase(),
                    type: r.isCompleted
                        ? AppBadgeType.success
                        : r.isCancelled
                            ? AppBadgeType.error
                            : AppBadgeType.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product Showcase Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppProductImage(
                      imageUrl: r.productImageUrl,
                      width: 72,
                      height: 72,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.productName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (r.productSku.isNotEmpty)
                                _buildDetailChip('SKU: ${r.productSku}', isDark),
                              if (r.categoryName.isNotEmpty)
                                _buildDetailChip(r.categoryName, isDark),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.isHindi
                                ? 'मात्रा: ${r.quantity} इकाई'
                                : 'Quantity: ${r.quantity} unit${r.quantity > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            context.isHindi
                                ? 'दर: ₹${r.unitPrice.toStringAsFixed(0)} प्रति इकाई'
                                : 'Rate: ₹${r.unitPrice.toStringAsFixed(0)} each',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Multi-item Order Breakdown (if multiple items from cart)
              if (r.itemsBreakdown.isNotEmpty) ...[
                Text(
                  context.isHindi ? 'ऑर्डर की गई वस्तुएं' : 'Itemized Order Items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: r.itemsBreakdown.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Customer & Amount Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.isHindi ? 'ग्राहक का नाम' : 'Customer Name', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            r.customerName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.isHindi ? 'ग्राहक का मोबाइल' : 'Customer Mobile', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            r.customerMobile.isNotEmpty ? r.customerMobile : (context.isHindi ? 'उपलब्ध नहीं' : 'Not Provided'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.isHindi ? 'कुल देय राशि' : 'Total Amount Payable', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${r.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6-Digit Counter Code Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.isHindi ? 'काउंटर पिकअप पिन' : 'Counter Pickup PIN', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text(
                            '#${r.pickupCode}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    if (r.isPending || r.isReady)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text(context.isHindi ? 'पिन सत्यापित करें' : 'Verify PIN', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showVerifyCodeDialog(context, prefillReservation: r);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Customer Communication Buttons
              if (r.customerMobile.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                        label: Text(context.isHindi ? 'ग्राहक को कॉल करें' : 'Call Customer'),
                        onPressed: () => resCtrl.makeCustomerCall(context, r),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        icon: const Icon(Icons.chat_rounded, color: Colors.white),
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () => resCtrl.openWhatsAppChat(context, r),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    ReservationModel r,
    ReservationController resCtrl,
    bool isDark,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showReservationDetailSheet(context, r, resCtrl, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Code Badge & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'CODE: #${r.pickupCode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (r.reservationNumber.isNotEmpty && r.reservationNumber != r.pickupCode) ...[
                        const SizedBox(height: 3),
                        Text(
                          r.reservationNumber,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppBadge(
                    label: r.status.toUpperCase(),
                    type: r.isCompleted
                        ? AppBadgeType.success
                        : r.isCancelled
                            ? AppBadgeType.error
                            : AppBadgeType.warning,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Product Info Row with Real Photo Thumbnail
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppProductImage(
                    imageUrl: r.productImageUrl,
                    width: 54,
                    height: 54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (r.productSku.isNotEmpty)
                              _buildDetailChip('SKU: ${r.productSku}', isDark),
                            if (r.categoryName.isNotEmpty)
                              _buildDetailChip(r.categoryName, isDark),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${r.customerName} (${r.customerMobile})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${r.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                      ),
                      Text(
                        'Qty: ${r.quantity}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      ),
                      if (r.quantity > 1 && r.unitPrice > 0)
                        Text(
                          '₹${r.unitPrice.toStringAsFixed(0)}/ea',
                          style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        ),
                    ],
                  ),
                ],
              ),

              // Itemized Multi-Items Tag List (if cart checkout)
              if (r.itemsBreakdown.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.itemsBreakdown.join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Date & Expiration Time Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      '${context.isHindi ? 'ऑर्डर समय' : 'Booked'}: ${AppDateTimeUtils.formatDateTime(r.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (r.expiresAt != null) ...[
                      Text(
                        '${context.isHindi ? 'पिकअप समय' : 'Pickup by'}: ${AppDateTimeUtils.formatTime(r.expiresAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: r.isPending ? AppColors.warning : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Customer Notes
              if (r.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.notes,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Action Footer
              Row(
                children: [
                  if (r.customerMobile.isNotEmpty) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                      label: Text(context.isHindi ? 'कॉल' : 'Call', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      onPressed: () => resCtrl.makeCustomerCall(context, r),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 14, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => resCtrl.openWhatsAppChat(context, r),
                    ),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  if (r.isPending || r.isReady) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => resCtrl.cancelReservation(r.id.toString()),
                      child: Text(context.isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(fontSize: 11, color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      label: Text(context.isHindi ? 'कोड सत्यापित करें' : 'Verify Code', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => _showVerifyCodeDialog(context, prefillReservation: r),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
