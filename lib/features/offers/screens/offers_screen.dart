import 'package:flutter/material.dart';
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
                    const SnackBar(content: Text('✓ Store Offers Refreshed'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
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
          onPressed: () => _showCreateOfferSheet(context, offerController),
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
                  // 1. BANNER / INFO HEADER CARD WITH 1-TAP PRESETS
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
                              'Attract Nearby Walk-In Shoppers',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Publish discount deals or festival offers. Nearby customers see live offers on your storefront page and customer app feed!',
                          style: TextStyle(fontSize: 12.5, color: context.colorTextSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 14),

                        // Quick Fill Deal Presets
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
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickPresetChip(
                                context,
                                '🔥 Flat 20% OFF',
                                'Flat Discount on All Items',
                                'Flat 20% OFF',
                                'Special discount on all items in-store. Walk in & claim.',
                                offerController,
                              ),
                              _buildQuickPresetChip(
                                context,
                                '🎁 Buy 1 Get 1',
                                'Buy 1 Get 1 Free Special',
                                'Buy 1 Get 1',
                                'Buy selected item, get another free today at counter.',
                                offerController,
                              ),
                              _buildQuickPresetChip(
                                context,
                                '⚡ Festive Bonanza',
                                'Festival Celebration Offer',
                                'Festive Special',
                                'Celebrate with special discounted prices in-store.',
                                offerController,
                              ),
                              _buildQuickPresetChip(
                                context,
                                '🚀 Free Delivery',
                                'Free Home Delivery Deal',
                                'Free Delivery',
                                'Get free doorstep delivery on orders above ₹300.',
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
                            'Shops with active deals get up to 2x more walk-in customer visits.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            label: const Text('Create Your First Offer'),
                            onPressed: () => _showCreateOfferSheet(context, offerController),
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
    OfferController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _showCreateOfferSheet(
          context,
          controller,
          initialTitle: defaultTitle,
          initialBadge: defaultBadge,
          initialDesc: defaultDesc,
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
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.discountText,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Row(
                children: [
                  Switch.adaptive(
                    value: item.isActive,
                    activeTrackColor: AppColors.success,
                    onChanged: (_) => controller.toggleOfferActive(item),
                  ),
                  const SizedBox(width: 4),
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
          const SizedBox(height: 12),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: context.colorTextMuted),
              const SizedBox(width: 6),
              Text(
                'Valid for ${item.expiresInDays} days • ${item.isActive ? "Live in Storefront" : "Paused"}',
                style: TextStyle(fontSize: 11, color: context.colorTextMuted, fontWeight: FontWeight.w600),
              ),
            ],
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
        content: const Text('Are you sure you want to delete this promotional offer?'),
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
                  const SnackBar(content: Text('Offer deleted from storefront')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateOfferSheet(
    BuildContext context,
    OfferController controller, {
    String? initialTitle,
    String? initialBadge,
    String? initialDesc,
  }) {
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final discountCtrl = TextEditingController(text: initialBadge ?? '');
    final descCtrl = TextEditingController(text: initialDesc ?? '');
    int selectedDays = 7;
    bool isSaving = false;

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
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
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
                      'Create Promotional Offer',
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

                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Offer Title *',
                    hintText: 'e.g. Weekend Grocery Bonanza',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: discountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Discount Badge Text *',
                    hintText: 'e.g. Flat 20% OFF or Buy 1 Get 1',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Items included, terms, etc.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const ValueKey('offers_valid_days_dropdown'),
                  isExpanded: true,
                  initialValue: selectedDays,
                  decoration: const InputDecoration(labelText: 'Valid Duration'),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 Days')),
                    DropdownMenuItem(value: 7, child: Text('7 Days (1 Week)')),
                    DropdownMenuItem(value: 15, child: Text('15 Days')),
                    DropdownMenuItem(value: 30, child: Text('30 Days (1 Month)')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedDays = val;
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(content: Text('Please enter Title and Discount Text')),
                            );
                            return;
                          }
                          setSheetState(() => isSaving = true);

                          final success = await controller.createOffer(
                            title: titleCtrl.text.trim(),
                            discountText: discountCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            expiresInDays: selectedDays,
                          );

                          if (sheetCtx.mounted) {
                            setSheetState(() => isSaving = false);
                            if (success) {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Offer Published Live on Storefront!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Publish Offer Live', style: TextStyle(fontWeight: FontWeight.bold)),
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
