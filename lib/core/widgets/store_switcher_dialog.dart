import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import 'app_ui_components.dart';

class StoreSwitcherDialog {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => const _StoreSwitcherSheetContent(),
    );
  }
}

class _StoreSwitcherSheetContent extends StatefulWidget {
  const _StoreSwitcherSheetContent();

  @override
  State<_StoreSwitcherSheetContent> createState() => _StoreSwitcherSheetContentState();
}

class _StoreSwitcherSheetContentState extends State<_StoreSwitcherSheetContent> {
  bool _isCreatingBranch = false;
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _selectedCategory = 'General Store';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final currentShop = authController.currentShop;
    final managedShops = authController.managedShops;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 580,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('store_switcher_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        Text(
                          context.tr('store_switcher_subtitle'),
                          style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.colorTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 24, color: context.colorBorder),

              if (!_isCreatingBranch) ...[
                // Stores / Branches List
                if (managedShops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        context.isHindi ? 'कोई अतिरिक्त शाखा नहीं मिली' : 'No additional branches found',
                        style: TextStyle(color: context.colorTextSecondary),
                      ),
                    ),
                  )
                else
                  ...managedShops.map((shop) {
                    final isCurrent = currentShop != null && currentShop.id == shop.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isCurrent
                            ? null
                            : () async {
                                await authController.switchShop(shop.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✓ ${context.tr('store_switcher_switch_success')}: ${shop.name}',
                                      ),
                                      backgroundColor: AppColors.success,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent ? context.colorPrimaryLight.withValues(alpha: 0.3) : context.colorSurfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent ? AppColors.primary : context.colorBorder,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: shop.logoUrl,
                                name: shop.name,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            shop.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: context.colorTextPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.tr('store_switcher_active'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      shop.address.isNotEmpty ? shop.address : shop.category,
                                      style: TextStyle(fontSize: 12, color: context.colorTextSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              else
                                Icon(Icons.arrow_forward_ios_rounded, color: context.colorTextMuted, size: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 12),

                // Button to Open Add Branch Form
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_business_rounded, color: AppColors.primary, size: 18),
                  label: Text(
                    context.tr('store_switcher_add_branch'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: () {
                    setState(() => _isCreatingBranch = true);
                  },
                ),
              ] else ...[
                // Create New Branch Form
                Text(
                  context.tr('store_switcher_add_branch'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: '${context.tr('store_switcher_branch_name')} *',
                    hintText: context.isHindi ? 'उदा. मुख्य बाज़ार शाखा' : 'e.g. Main Market Branch',
                    prefixIcon: const Icon(Icons.store_rounded, size: 20),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: '${context.tr('store_switcher_branch_address')} *',
                    hintText: context.isHindi ? 'उदा. स्टेशन रोड, वार्ड 4' : 'e.g. Station Road, Ward 4',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.isHindi ? 'दुकान की श्रेणी' : 'Store Category',
                    prefixIcon: const Icon(Icons.category_outlined, size: 20),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'General Store',
                      child: Text(
                        context.isHindi ? 'किराना स्टोर' : 'General Store',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Dairy & Bakery',
                      child: Text(
                        context.isHindi ? 'डेयरी एवं बेकरी' : 'Dairy & Bakery',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Wholesale Depot',
                      child: Text(
                        context.isHindi ? 'थोक गोदाम' : 'Wholesale Depot',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Electricals & Hardware',
                      child: Text(
                        context.isHindi ? 'इलेक्ट्रिकल एवं हार्डवेयर' : 'Electricals & Hardware',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() => _isCreatingBranch = false),
                        child: Text(context.isHindi ? 'रद्द करें' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        label: Text(
                          context.tr('store_switcher_add_branch'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () async {
                          final name = _nameCtrl.text.trim();
                          final address = _addressCtrl.text.trim();
                          if (name.isEmpty || address.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.isHindi ? 'कृपया नाम और पता दर्ज करें' : 'Please enter branch name and address'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          await authController.registerBranchStore(
                            name: name,
                            address: address,
                            category: _selectedCategory,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('store_switcher_create_success')),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
