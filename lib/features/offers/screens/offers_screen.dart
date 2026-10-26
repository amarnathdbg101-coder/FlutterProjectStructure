import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../controllers/offer_controller.dart';
import '../models/offer_model.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  @override
  Widget build(BuildContext context) {
    final offerController = context.watch<OfferController>();
    final offers = offerController.offers;

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
            'Offers & Store Deals',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.colorTextPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Refresh Deals',
              onPressed: () async {
                await offerController.fetchOffers();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Store Offers Refreshed'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Create New Offer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showOfferDialog(context, offerController),
        ),
        body: RefreshIndicator(
          onRefresh: () => offerController.fetchOffers(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ResponsiveContainer(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HEADER CARD WITH QUICK PRESETS
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Attract Walk-In & Online Shoppers',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Configure day-wise recurring offers (e.g. Sunday Special) or flat discounts. Offers sync live in <15ms to your storefront banner!',
                          style: TextStyle(fontSize: 12.5, color: context.colorTextSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 14),

                        // Quick Fill Presets
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Quick Deal Presets:',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickPresetChip(
                                context,
                                '⚡ Sunday Special (Flat 15% OFF)',
                                'Sunday Grocery Dhamaka',
                                'Flat 15% OFF',
                                'Exclusive weekend discount for counter & online shoppers.',
                                'percentage',
                                15,
                                300,
                                'sunday',
                                '⚡ Sunday Special',
                                'SUN15',
                                offerController,
                              ),
                              _buildQuickPresetChip(
                                context,
                                '🎁 ₹50 OFF on ₹499+',
                                'Welcome Discount',
                                'Flat ₹50 OFF',
                                'Flat ₹50 instant discount on orders above ₹499.',
                                'flat',
                                50,
                                499,
                                'all',
                                '🔥 Special Offer',
                                'SAVE50',
                                offerController,
                              ),
                              _buildQuickPresetChip(
                                context,
                                '🎉 Tuesday Super Saver',
                                'Mangalwar Mega Bachat',
                                'Flat 10% OFF',
                                'Special mid-week savings on all store items.',
                                'percentage',
                                10,
                                200,
                                'tuesday',
                                '🎉 Festive Dhamaka',
                                'TUE10',
                                offerController,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ACTIVE STORE DEALS HEADER
                  AppSectionHeader(
                    title: 'Active Store Deals (${offers.length})',
                  ),

                  if (offerController.isLoading && offers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (offers.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.local_offer_outlined, size: 48, color: context.colorTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No live offers right now',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Publish day-wise deals to increase counter sales & online storefront orders.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            label: const Text('Create Your First Offer', style: TextStyle(color: Colors.white)),
                            onPressed: () => _showOfferDialog(context, offerController),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: offers.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = offers[index];
                        return _buildOfferCard(context, item, offerController);
                      },
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPresetChip(
    BuildContext context,
    String label,
    String defaultTitle,
    String defaultBadge,
    String defaultDesc,
    String discountType,
    double discountValue,
    double minOrder,
    String applicableDays,
    String bannerTag,
    String promoCode,
    OfferController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _showOfferDialog(
          context,
          controller,
          initialTitle: defaultTitle,
          initialBadge: defaultBadge,
          initialDesc: defaultDesc,
          initialDiscountType: discountType,
          initialDiscountValue: discountValue,
          initialMinOrder: minOrder,
          initialDays: applicableDays,
          initialBannerTag: bannerTag,
          initialPromoCode: promoCode,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.colorSurfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colorBorder),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, OfferModel item, OfferController controller) {
    // Days label formatting
    String dayLabel = 'रोजाना (All Days)';
    if (item.applicableDays.isNotEmpty && item.applicableDays.toLowerCase() != 'all') {
      final days = item.applicableDays.split(',').map((d) {
        final clean = d.trim().toLowerCase();
        switch (clean) {
          case 'monday': return 'सोम';
          case 'tuesday': return 'मंगल';
          case 'wednesday': return 'बुध';
          case 'thursday': return 'गुरु';
          case 'friday': return 'शुक्र';
          case 'saturday': return 'शनि';
          case 'sunday': return 'रवि';
          default: return clean;
        }
      }).join(', ');
      dayLabel = 'केवल $days';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isActive ? AppColors.success : context.colorTextMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.discountText,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (item.bannerTag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.bannerTag,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Switch.adaptive(
                    value: item.isActive,
                    activeTrackColor: AppColors.success,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      controller.toggleOfferActive(item);
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.edit_outlined, size: 18, color: context.colorTextSecondary),
                    tooltip: 'Edit Offer',
                    onPressed: () => _showOfferDialog(
                      context,
                      controller,
                      editOffer: item,
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.colorTextMuted),
                    tooltip: 'Delete Offer',
                    onPressed: () => _confirmDeleteOffer(context, item.id, controller),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            item.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
            ),
          ],
          const SizedBox(height: 10),

          // Chips info row (Days, Min Order, Promo Code)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadgePill(
                icon: Icons.calendar_month_rounded,
                text: dayLabel,
                color: item.isApplicableToday ? AppColors.primary : context.colorTextMuted,
              ),
              if (item.minOrderAmount > 0)
                _buildBadgePill(
                  icon: Icons.currency_rupee_rounded,
                  text: 'Min ₹${item.minOrderAmount.toStringAsFixed(0)}',
                  color: context.colorTextSecondary,
                ),
              if (item.promoCode.isNotEmpty)
                _buildBadgePill(
                  icon: Icons.confirmation_number_outlined,
                  text: 'Code: ${item.promoCode}',
                  color: AppColors.success,
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: context.colorTextMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Valid for ${item.expiresInDays} days • ${item.isActive ? (item.isApplicableToday ? "🟢 Live in Storefront Today" : "🟡 Scheduled (Inactive Today)") : "🔴 Paused by Shopkeeper"}',
                  style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePill({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOffer(BuildContext context, dynamic id, OfferController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Offer'),
        content: const Text('Are you sure you want to permanently delete this promotional deal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await controller.deleteOffer(id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offer removed from storefront')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOfferDialog(
    BuildContext context,
    OfferController controller, {
    OfferModel? editOffer,
    String? initialTitle,
    String? initialBadge,
    String? initialDesc,
    String? initialDiscountType,
    double? initialDiscountValue,
    double? initialMinOrder,
    String? initialDays,
    String? initialBannerTag,
    String? initialPromoCode,
  }) {
    final isEditing = editOffer != null;
    final titleCtrl = TextEditingController(text: editOffer?.title ?? initialTitle ?? '');
    final discountCtrl = TextEditingController(text: editOffer?.discountText ?? initialBadge ?? '');
    final descCtrl = TextEditingController(text: editOffer?.description ?? initialDesc ?? '');
    final discValCtrl = TextEditingController(
      text: editOffer != null && editOffer.discountValue > 0
          ? editOffer.discountValue.toStringAsFixed(0)
          : (initialDiscountValue != null && initialDiscountValue > 0 ? initialDiscountValue.toStringAsFixed(0) : ''),
    );
    final minOrderCtrl = TextEditingController(
      text: editOffer != null && editOffer.minOrderAmount > 0
          ? editOffer.minOrderAmount.toStringAsFixed(0)
          : (initialMinOrder != null && initialMinOrder > 0 ? initialMinOrder.toStringAsFixed(0) : ''),
    );
    final promoCtrl = TextEditingController(text: editOffer?.promoCode ?? initialPromoCode ?? '');

    String discountType = editOffer?.discountType ?? initialDiscountType ?? 'percentage';
    String bannerTag = editOffer?.bannerTag ?? initialBannerTag ?? '🔥 Special Offer';
    int selectedDaysDuration = editOffer?.expiresInDays ?? 7;

    // Day selections
    final rawDays = (editOffer?.applicableDays ?? initialDays ?? 'all').toLowerCase();
    bool allDays = rawDays == 'all' || rawDays.isEmpty;
    final selectedDaySet = <String>{};
    if (!allDays) {
      selectedDaySet.addAll(rawDays.split(',').map((e) => e.trim()));
    }

    bool isSaving = false;

    final weekDays = [
      {'key': 'monday', 'label': 'सोम (Mon)'},
      {'key': 'tuesday', 'label': 'मंगल (Tue)'},
      {'key': 'wednesday', 'label': 'बुध (Wed)'},
      {'key': 'thursday', 'label': 'गुरु (Thu)'},
      {'key': 'friday', 'label': 'शुक्र (Fri)'},
      {'key': 'saturday', 'label': 'शनि (Sat)'},
      {'key': 'sunday', 'label': 'रवि (Sun)'},
    ];

    final bannerTagsList = [
      '🔥 Special Offer',
      '⚡ Flash Deal',
      '🎉 Festive Dhamaka',
      '⭐ Member Special',
      '🛍️ Weekend Sale',
      '🚀 Super Saver',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: sheetCtx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Promotional Deal' : 'Create Promotional Deal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sheetCtx.colorTextPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Divider(color: sheetCtx.colorBorder),
                  const SizedBox(height: 12),

                  // 1. Title
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Offer Title *',
                      hintText: 'e.g. Sunday Grocery Dhamaka',
                      prefixIcon: Icon(Icons.title_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Discount Type Selector (Flat vs Percentage)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setSheetState(() {
                              discountType = 'percentage';
                              if (discountCtrl.text.isEmpty || discountCtrl.text.contains('₹')) {
                                discountCtrl.text = discValCtrl.text.isNotEmpty ? '${discValCtrl.text}% OFF' : 'Flat 10% OFF';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: discountType == 'percentage' ? AppColors.primary : sheetCtx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: discountType == 'percentage' ? AppColors.primary : sheetCtx.colorBorder),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.percent_rounded, size: 16, color: discountType == 'percentage' ? Colors.white : sheetCtx.colorTextPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  '% Percentage',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: discountType == 'percentage' ? Colors.white : sheetCtx.colorTextPrimary,
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
                          onTap: () {
                            setSheetState(() {
                              discountType = 'flat';
                              if (discountCtrl.text.isEmpty || discountCtrl.text.contains('%')) {
                                discountCtrl.text = discValCtrl.text.isNotEmpty ? 'Flat ₹${discValCtrl.text} OFF' : 'Flat ₹50 OFF';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: discountType == 'flat' ? AppColors.primary : sheetCtx.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: discountType == 'flat' ? AppColors.primary : sheetCtx.colorBorder),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.currency_rupee_rounded, size: 16, color: discountType == 'flat' ? Colors.white : sheetCtx.colorTextPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  '₹ Flat Rupee',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: discountType == 'flat' ? Colors.white : sheetCtx.colorTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Discount Amount & Badge Text
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: discValCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: discountType == 'percentage' ? 'Discount %' : 'Flat ₹',
                            hintText: discountType == 'percentage' ? 'e.g. 15' : 'e.g. 50',
                            prefixIcon: Icon(discountType == 'percentage' ? Icons.percent_rounded : Icons.currency_rupee_rounded, size: 18),
                          ),
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              setSheetState(() {
                                discountCtrl.text = discountType == 'percentage' ? 'Flat $val% OFF' : 'Flat ₹$val OFF';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: discountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Badge Tagline *',
                            hintText: 'e.g. Flat 15% OFF',
                            prefixIcon: Icon(Icons.local_offer_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Min Order Amount & Promo Code
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minOrderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min Order Amount',
                            hintText: 'e.g. 499 (0 for none)',
                            prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: promoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Promo Code (Optional)',
                            hintText: 'e.g. SUN15',
                            prefixIcon: Icon(Icons.confirmation_number_outlined, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. Day-wise Recurring Schedule
                  Text(
                    'Applicable Days (किस दिन लागू होगा):',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: sheetCtx.colorTextPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('All Days (रोजाना)'),
                        selected: allDays,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: allDays ? Colors.white : sheetCtx.colorTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                        onSelected: (selected) {
                          setSheetState(() {
                            allDays = true;
                            selectedDaySet.clear();
                          });
                        },
                      ),
                      ...weekDays.map((wd) {
                        final key = wd['key']!;
                        final isSel = !allDays && selectedDaySet.contains(key);
                        return FilterChip(
                          label: Text(wd['label']!),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : sheetCtx.colorTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                          onSelected: (selected) {
                            setSheetState(() {
                              allDays = false;
                              if (selected) {
                                selectedDaySet.add(key);
                              } else {
                                selectedDaySet.remove(key);
                                if (selectedDaySet.isEmpty) {
                                  allDays = true;
                                }
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Banner Tag Pill
                  Text(
                    'Banner Tag Highlight:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: sheetCtx.colorTextPrimary),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: bannerTagsList.map((tag) {
                        final isSel = bannerTag == tag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: isSel,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSel ? AppColors.primary : sheetCtx.colorTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) {
                              setSheetState(() => bannerTag = tag);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7. Description
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Terms / Notes (Optional)',
                      hintText: 'e.g. Valid on all counter billing and online delivery.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 8. Valid Duration Dropdown
                  DropdownButtonFormField<int>(
                    key: const ValueKey('offers_valid_days_dropdown'),
                    isExpanded: true,
                    initialValue: selectedDaysDuration,
                    decoration: const InputDecoration(
                      labelText: 'Valid Duration',
                      prefixIcon: Icon(Icons.timer_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 Days')),
                      DropdownMenuItem(value: 7, child: Text('7 Days (1 Week)')),
                      DropdownMenuItem(value: 15, child: Text('15 Days')),
                      DropdownMenuItem(value: 30, child: Text('30 Days (1 Month)')),
                      DropdownMenuItem(value: 90, child: Text('90 Days (Quarterly)')),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedDaysDuration = val;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 9. Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(content: Text('Please enter Offer Title and Tagline')),
                              );
                              return;
                            }
                            setSheetState(() => isSaving = true);

                            final appDaysString = allDays ? 'all' : selectedDaySet.join(',');
                            final dVal = double.tryParse(discValCtrl.text.trim()) ?? 0.0;
                            final minOrd = double.tryParse(minOrderCtrl.text.trim()) ?? 0.0;

                            bool success = false;
                            if (isEditing) {
                              success = await controller.updateOffer(
                                id: editOffer.id,
                                title: titleCtrl.text.trim(),
                                discountText: discountCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                discountType: discountType,
                                discountValue: dVal,
                                minOrderAmount: minOrd,
                                applicableDays: appDaysString,
                                bannerTag: bannerTag,
                                promoCode: promoCtrl.text.trim(),
                                expiresInDays: selectedDaysDuration,
                                isActive: editOffer.isActive,
                              );
                            } else {
                              success = await controller.createOffer(
                                title: titleCtrl.text.trim(),
                                discountText: discountCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                discountType: discountType,
                                discountValue: dVal,
                                minOrderAmount: minOrd,
                                applicableDays: appDaysString,
                                bannerTag: bannerTag,
                                promoCode: promoCtrl.text.trim(),
                                expiresInDays: selectedDaysDuration,
                              );
                            }

                            if (sheetCtx.mounted) {
                              setSheetState(() => isSaving = false);
                              if (success) {
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing ? '✓ Offer Updated Successfully!' : '⚡ Offer Published Live on Storefront! (<15ms Sync)'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEditing ? 'Save Changes' : 'Publish Offer Live (<15ms)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
}
