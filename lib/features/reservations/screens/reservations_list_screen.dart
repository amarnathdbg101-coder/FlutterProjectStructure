import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/responsive.dart';
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
  void _showVerifyCodeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify Counter Pickup Code',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Enter 4-digit pickup code shown by customer',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: '4812',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isVerifying ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
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
                                      const SnackBar(content: Text('Please enter 4-digit pickup code')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isVerifying = true);
                                  final ok = await context.read<ReservationController>().verifyPickupCode(code);
                                  if (ctx.mounted) {
                                    setDialogState(() => isVerifying = false);
                                    if (ok) {
                                      Navigator.pop(dialogCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✓ Counter Pickup Code Verified & Completed Successfully!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      final err = context.read<ReservationController>().errorMessage ?? 'Invalid pickup code';
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
                              : const Text('Verify & Complete', style: TextStyle(fontWeight: FontWeight.bold)),
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
            tooltip: 'Verify 4-Digit Pickup Code',
            onPressed: () => _showVerifyCodeDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => resCtrl.loadReservations(),
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
          label: const Text(
            'Verify Pickup Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                // Summary Banner
                AppSummaryBanner(
                  title: 'Active Counter Pickup Orders',
                  amount: '${resCtrl.activeCount} Pending',
                  subtitle: '${resCtrl.totalCount} Total Orders • ${resCtrl.completedCount} Completed',
                  icon: Icons.shopping_bag_outlined,
                  actionLabel: 'Verify Code',
                  onAction: () => _showVerifyCodeDialog(context),
                ),

                // KPI Stat Cards Row
                Row(
                  children: [
                    Expanded(
                      child: AppStatCard(
                        title: 'Active Orders',
                        value: '${resCtrl.activeCount}',
                        subtitle: 'Awaiting Pickup',
                        icon: Icons.pending_actions_rounded,
                        isAlert: resCtrl.activeCount > 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: 'Completed',
                        value: '${resCtrl.completedCount}',
                        subtitle: 'Verified at Counter',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppStatCard(
                        title: 'Cancelled',
                        value: '${resCtrl.cancelledCount}',
                        subtitle: 'Expired / Cancelled',
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
                    hintText: 'Search by Customer Name, Mobile, Code (#4812)...',
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
                      _buildFilterChip('All Orders', resCtrl.totalCount, resCtrl.activeTab == 'all', () => resCtrl.setActiveTab('all')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active / Pending', resCtrl.activeCount, resCtrl.activeTab == 'pending', () => resCtrl.setActiveTab('pending'), isAlert: resCtrl.activeCount > 0),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', resCtrl.completedCount, resCtrl.activeTab == 'completed', () => resCtrl.setActiveTab('completed')),
                      const SizedBox(width: 8),
                      _buildFilterChip('Cancelled', resCtrl.cancelledCount, resCtrl.activeTab == 'cancelled', () => resCtrl.setActiveTab('cancelled')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Orders List
                resCtrl.isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    : resCtrl.filteredReservations.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No counter pickup orders found', style: TextStyle(color: AppColors.textSecondary)),
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

  Widget _buildReservationCard(
    BuildContext context,
    ReservationModel r,
    ReservationController resCtrl,
    bool isDark,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Code Badge & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(height: 10),

          // Customer & Product Info Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 22),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${r.customerName} (${r.customerMobile})',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
                    '₹${r.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                  ),
                  Text(
                    'Qty: ${r.quantity}',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
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
                  'Booked: ${AppDateTimeUtils.formatDateTime(r.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (r.expiresAt != null) ...[
                  Text(
                    'Pickup by: ${AppDateTimeUtils.formatTime(r.expiresAt)}',
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
          const SizedBox(height: 12),

          // Action Footer
          Row(
            children: [
              if (r.customerMobile.isNotEmpty) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 14, color: Colors.white),
                  label: const Text('WhatsApp Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
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
                  child: const Text('Cancel', style: TextStyle(fontSize: 11, color: AppColors.error)),
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
                  label: const Text('Verify Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => _showVerifyCodeDialog(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
