import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/merchant_shell.dart';
import '../../../core/widgets/store_qr_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/user_model.dart';
import '../../products/controllers/product_controller.dart';
import '../models/shop_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;
  bool _isUploadingLogo = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().fetchShopDetails();
      context.read<AuthController>().fetchUserProfile();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.wait([
      context.read<AuthController>().fetchShopDetails(),
      context.read<AuthController>().fetchUserProfile(),
    ]);
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _handleImageUpload({
    required bool isStoreLogo,
    required AuthController authController,
    VoidCallback? onStateUpdate,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = context.tr('profile_photo_updated');
    final errorMsg = context.tr('profile_photo_error');

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isStoreLogo
                        ? sheetCtx.tr('profile_upload_logo')
                        : sheetCtx.tr('profile_upload_avatar'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: sheetCtx.colorTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              Divider(color: sheetCtx.colorBorder),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text(
                  sheetCtx.tr('profile_choose_gallery'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: sheetCtx.colorTextPrimary,
                  ),
                ),
                onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text(
                  sheetCtx.tr('profile_take_camera'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: sheetCtx.colorTextPrimary,
                  ),
                ),
                onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      if (isStoreLogo) {
        _isUploadingLogo = true;
      } else {
        _isUploadingAvatar = true;
      }
    });
    onStateUpdate?.call();

    final success = isStoreLogo
        ? await authController.uploadShopLogo(picked)
        : await authController.uploadUserAvatar(picked);

    if (mounted) {
      setState(() {
        if (isStoreLogo) {
          _isUploadingLogo = false;
        } else {
          _isUploadingAvatar = false;
        }
      });
      onStateUpdate?.call();

      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? successMsg : (authController.errorMessage ?? errorMsg)),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final langController = context.watch<LanguageController>();
    final themeController = context.watch<ThemeController>();
    final prodController = context.watch<ProductController>();
    final user = authController.currentUser;
    final shop = authController.currentShop;

    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Store';
    final shopSlug = shop?.slug.isNotEmpty == true ? shop!.slug : 'store';
    final storeUrl = 'https://shopsilo.in/shop/$shopSlug';
    final isShopOpen = shop?.isOpen ?? true;
    final ownerName = user?.name.isNotEmpty == true ? user!.name : 'Merchant Owner';
    final statusUpdatedMsg = context.tr('profile_status_updated');

    return MerchantShell(
      currentIndex: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.colorSurface,
          leading: !Responsive.isWide(context)
              ? IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/merchant');
                    }
                  },
                )
              : null,
          title: Text(
            context.tr('profile_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.colorTextPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh_rounded, color: context.colorTextSecondary),
              tooltip: 'Refresh',
              onPressed: _isRefreshing ? null : _handleRefresh,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ResponsiveContainer(
              maxWidth: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // EXECUTIVE STORE & OWNER SUMMARY HEADER
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppAvatar(
                              imageUrl: shop?.logoUrl,
                              name: shopName,
                              radius: 28,
                              isEditable: true,
                              isLoading: _isUploadingLogo,
                              onEditTap: () => _handleImageUpload(
                                isStoreLogo: true,
                                authController: authController,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shopName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: context.colorTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$ownerName • ${shop?.category ?? 'General Retail'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colorTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isShopOpen
                                    ? AppColors.success.withValues(alpha: context.isDark ? 0.2 : 0.08)
                                    : AppColors.error.withValues(alpha: context.isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (isShopOpen ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isShopOpen ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isShopOpen ? context.tr('profile_status_open') : context.tr('profile_status_closed'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isShopOpen ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  SizedBox(
                                    height: 22,
                                    child: FittedBox(
                                      fit: BoxFit.fill,
                                      child: Switch(
                                        value: isShopOpen,
                                        activeThumbColor: AppColors.success,
                                        onChanged: (value) {
                                          final messenger = ScaffoldMessenger.of(context);
                                          authController.toggleShopStatus(value).then((success) {
                                            if (success) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(statusUpdatedMsg),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECTION 1: STORE & BUSINESS INFORMATION
                  AppSectionHeader(
                    title: context.tr('profile_store_info_section'),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      children: [
                        _SettingTile(
                          leadingWidget: AppAvatar(
                            imageUrl: shop?.logoUrl,
                            name: shopName,
                            radius: 18,
                            isEditable: true,
                            isLoading: _isUploadingLogo,
                            onEditTap: () => _handleImageUpload(
                              isStoreLogo: true,
                              authController: authController,
                            ),
                          ),
                          title: context.tr('profile_store_info_section'),
                          subtitle: '$shopName • ${shop != null && shop.fullAddress.isNotEmpty ? shop.fullAddress : (shop?.phone ?? 'Not specified')}',
                          trailingText: shop?.category ?? 'General Store',
                          onTap: () => _showEditStoreSheet(context, authController, shop),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        _SettingTile(
                          icon: Icons.location_on_rounded,
                          title: 'Store GPS Pin & Location',
                          subtitle: shop != null && shop.fullAddress.isNotEmpty
                              ? '${shop.fullAddress} (${shop.formattedGps})'
                              : 'Set GPS pin & Google Maps link for nearby search',
                          trailingText: shop?.hasGpsCoordinates == true ? 'GPS Active' : 'Set GPS',
                          onTap: () => _showEditLocationSheet(context, authController, shop),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        _SettingTile(
                          icon: Icons.collections_outlined,
                          title: 'Shop Showcase Banners',
                          subtitle: '${shop?.banners.length ?? 0}/2 Showcase Banners Uploaded',
                          trailingText: 'Edit Banners',
                          onTap: () => _showEditShopBannersSheet(context, authController, shop),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        _SettingTile(
                          icon: Icons.access_time_rounded,
                          title: context.tr('profile_timings_section'),
                          subtitle: '${shop?.openingTime ?? '09:00 AM'} - ${shop?.closingTime ?? '09:00 PM'} (${shop?.weeklyOff ?? 'Open 7 days'})',
                          trailingText: shop?.upiId?.isNotEmpty == true ? 'UPI Active' : 'Add UPI',
                          onTap: () => _showEditTimingsSheet(context, authController, shop),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        _SettingTile(
                          leadingWidget: AppAvatar(
                            imageUrl: user?.avatarUrl,
                            name: ownerName,
                            radius: 18,
                            isEditable: true,
                            isLoading: _isUploadingAvatar,
                            onEditTap: () => _handleImageUpload(
                              isStoreLogo: false,
                              authController: authController,
                            ),
                          ),
                          title: context.tr('profile_owner_section'),
                          subtitle: '$ownerName • ${user?.email ?? 'merchant@shopsilo.in'}',
                          onTap: () => _showEditOwnerSheet(context, authController, user),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECTION 2: DIGITAL STOREFRONT
                  AppSectionHeader(
                    title: context.tr('profile_storefront_link'),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: _SettingTile(
                      icon: Icons.qr_code_2_rounded,
                      title: context.tr('dash_dialog_qr_title'),
                      subtitle: storeUrl,
                      onTap: () => showStoreQrDialog(context, shop),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SECTION 3: APP PREFERENCES (Language & Theme Compact Toggles)
                  AppSectionHeader(
                    title: context.tr('settings_language_title'),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      children: [
                        // Language Toggle Tile
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colorPrimaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.language_rounded, size: 18, color: AppColors.primary),
                          ),
                          title: Text(
                            context.tr('settings_language_title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            langController.currentLanguage == AppLanguage.hindi ? 'हिन्दी (Hindi)' : 'English',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          trailing: Container(
                            height: 32,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: context.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colorBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TextTogglePill(
                                  label: 'EN',
                                  isSelected: langController.currentLanguage == AppLanguage.english,
                                  onTap: () => langController.setLanguage(AppLanguage.english),
                                ),
                                _TextTogglePill(
                                  label: 'हिन्दी',
                                  isSelected: langController.currentLanguage == AppLanguage.hindi,
                                  onTap: () => langController.setLanguage(AppLanguage.hindi),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        // Profit Margins Central Toggle Tile
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colorPrimaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics_outlined, size: 18, color: AppColors.primary),
                          ),
                          title: Text(
                            context.tr('settings_profit_margins_title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            context.tr('settings_profit_margins_subtitle'),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          value: prodController.showProfitMargins,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => prodController.setShowProfitMargins(val),
                        ),
                        Divider(height: 1, color: context.colorBorder),
                        // Theme Toggle Tile
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colorPrimaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
                          ),
                          title: Text(
                            context.tr('settings_theme_title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            themeController.themeMode == ThemeMode.dark
                                ? context.tr('theme_dark')
                                : (themeController.themeMode == ThemeMode.light
                                    ? context.tr('theme_light')
                                    : context.tr('theme_system')),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          trailing: Container(
                            height: 32,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: context.colorSurfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colorBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _IconTogglePill(
                                  icon: Icons.wb_sunny_rounded,
                                  tooltip: context.tr('theme_light'),
                                  isSelected: themeController.themeMode == ThemeMode.light,
                                  onTap: () => themeController.setThemeMode(ThemeMode.light),
                                ),
                                _IconTogglePill(
                                  icon: Icons.nightlight_round,
                                  tooltip: context.tr('theme_dark'),
                                  isSelected: themeController.themeMode == ThemeMode.dark,
                                  onTap: () => themeController.setThemeMode(ThemeMode.dark),
                                ),
                                _IconTogglePill(
                                  icon: Icons.settings_suggest_rounded,
                                  tooltip: context.tr('theme_system'),
                                  isSelected: themeController.themeMode == ThemeMode.system,
                                  onTap: () => themeController.setThemeMode(ThemeMode.system),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECTION 4: LOGOUT BUTTON
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: Text(
                      context.tr('btn_logout'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _confirmLogout(context, authController),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- LOGOUT CONFIRMATION ---
  void _confirmLogout(BuildContext context, AuthController authController) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('btn_logout')),
        content: const Text('Are you sure you want to log out from this store session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('btn_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await authController.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(context.tr('btn_logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- EDIT STORE LOCATION & GPS MODAL ---
  void _showEditLocationSheet(BuildContext context, AuthController authController, ShopModel? shop) {
    final addressCtrl = TextEditingController(text: shop?.address ?? '');
    final cityCtrl = TextEditingController(text: shop?.city ?? '');
    final pincodeCtrl = TextEditingController(text: shop?.pincode ?? '');
    final latCtrl = TextEditingController(text: shop?.latitude != null ? shop!.latitude.toString() : '');
    final lngCtrl = TextEditingController(text: shop?.longitude != null ? shop!.longitude.toString() : '');
    final mapsUrlCtrl = TextEditingController(text: shop?.googleMapsUrl ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
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
                      'Store GPS & Location Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ctx.colorTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(color: ctx.colorBorder),
                const SizedBox(height: 12),

                // Address & Landmark
                TextFormField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Store Street Address / Landmark',
                    hintText: 'Shop No 12, Main Market',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          hintText: 'Patna',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: pincodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          hintText: '800001',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // GPS Latitude & Longitude
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'GPS Latitude',
                          hintText: '25.5941',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'GPS Longitude',
                          hintText: '85.1376',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Auto-Generate GPS / Default Pin Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text('Auto-Generate Map Link & Pin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final lat = double.tryParse(latCtrl.text) ?? 25.5941;
                      final lng = double.tryParse(lngCtrl.text) ?? 85.1376;
                      latCtrl.text = lat.toStringAsFixed(4);
                      lngCtrl.text = lng.toStringAsFixed(4);
                      mapsUrlCtrl.text = 'https://maps.google.com/?q=$lat,$lng';
                      setSheetState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Google Maps Share URL
                TextFormField(
                  controller: mapsUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Google Maps Link / URL',
                    hintText: 'https://maps.google.com/?q=25.5941,85.1376',
                  ),
                ),
                const SizedBox(height: 12),

                if (mapsUrlCtrl.text.trim().isNotEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Open Location in Google Maps'),
                    onPressed: () async {
                      final url = Uri.parse(mapsUrlCtrl.text.trim());
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setSheetState(() => isSaving = true);
                          final lat = double.tryParse(latCtrl.text.trim());
                          final lng = double.tryParse(lngCtrl.text.trim());

                          final updatePayload = <String, dynamic>{
                            'address': addressCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'pincode': pincodeCtrl.text.trim(),
                            'google_maps_url': mapsUrlCtrl.text.trim(),
                          };
                          if (lat != null) updatePayload['latitude'] = lat;
                          if (lng != null) updatePayload['longitude'] = lng;

                          final success = await authController.updateShop(updatePayload);

                          if (ctx.mounted) {
                            setSheetState(() => isSaving = false);
                            if (success) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Store GPS location & address updated!')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authController.errorMessage ?? 'Failed to update location')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Location & GPS Pin'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBannerImagePickerOptions(
    BuildContext context, {
    required Function(List<String> paths) onImagesSelected,
    int maxAllowed = 2,
    int currentCount = 0,
  }) {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Shop Banner Image Source',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: sheetCtx.colorTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: sheetCtx.colorTextSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              Divider(color: sheetCtx.colorBorder),
              const SizedBox(height: 8),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text('Choose from Gallery / Photos', style: TextStyle(fontWeight: FontWeight.w600, color: sheetCtx.colorTextPrimary)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final pickedFiles = await picker.pickMultiImage(
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (pickedFiles.isNotEmpty) {
                    final remaining = maxAllowed - currentCount;
                    final selectedPaths = pickedFiles.take(remaining).map((f) => f.path).toList();
                    onImagesSelected(selectedPaths);
                  }
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorPrimaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600, color: sheetCtx.colorTextPrimary)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    onImagesSelected([picked.path]);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // --- EDIT SHOP BANNERS (Up to 2 Max Promotional Banners) ---
  void _showEditShopBannersSheet(BuildContext context, AuthController authController, ShopModel? shop) {
    List<String> bannerList = List<String>.from(shop?.banners ?? []);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shop Showcase Banners (${bannerList.length}/2)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ctx.colorTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: ctx.colorBorder),
              const SizedBox(height: 12),

              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ctx.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ctx.colorBorder),
                ),
                child: Row(
                  children: [
                    ...bannerList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final path = entry.value;

                      return Container(
                        width: 100,
                        height: 84,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ctx.colorBorder),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AppProductImage(
                                imageUrl: path,
                                width: 100,
                                height: 84,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.storefront_rounded,
                                fallbackIconSize: 28,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    bannerList.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (bannerList.length < 2)
                      InkWell(
                        onTap: () {
                          _showBannerImagePickerOptions(
                            ctx,
                            maxAllowed: 2,
                            currentCount: bannerList.length,
                            onImagesSelected: (paths) {
                              setSheetState(() {
                                for (final p in paths) {
                                  if (bannerList.length < 2 && p.isNotEmpty) {
                                    bannerList.add(p);
                                  }
                                }
                              });
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: ctx.colorSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_outlined, size: 22, color: AppColors.primary),
                              SizedBox(height: 2),
                              Text('Add Banner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setSheetState(() => isSaving = true);

                        // Upload any local image files before saving
                        final finalUploadedBanners = <String>[];
                        final localXFiles = <XFile>[];

                        for (final img in bannerList) {
                          if (isServerImageUrl(img)) {
                            finalUploadedBanners.add(img);
                          } else {
                            localXFiles.add(XFile(img));
                          }
                        }

                        if (localXFiles.isNotEmpty) {
                          final serverUrls = await authController.uploadShopBanners(localXFiles);
                          if (serverUrls.isNotEmpty) {
                            finalUploadedBanners.addAll(serverUrls);
                          } else {
                            if (ctx.mounted) {
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authController.errorMessage ?? 'Banner upload failed on server')),
                              );
                            }
                            return;
                          }
                        }

                        final success = await authController.updateShop({
                          'banners': finalUploadedBanners.take(2).toList(),
                        });

                        if (ctx.mounted) {
                          setSheetState(() => isSaving = false);
                          if (success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Shop gallery banners updated!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(authController.errorMessage ?? 'Failed to update shop banners')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Shop Banners'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- EDIT STORE MODAL ---
  void _showEditStoreSheet(BuildContext context, AuthController authController, ShopModel? shop) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: shop?.name ?? '');
    final categoryCtrl = TextEditingController(text: shop?.category ?? 'General Store');
    final phoneCtrl = TextEditingController(text: shop?.phone ?? '');
    final whatsappCtrl = TextEditingController(text: shop?.whatsappNumber ?? '');
    final addressCtrl = TextEditingController(text: shop?.address ?? '');
    final cityCtrl = TextEditingController(text: shop?.city ?? '');
    final pincodeCtrl = TextEditingController(text: shop?.pincode ?? '');
    final descriptionCtrl = TextEditingController(text: shop?.description ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ctx.tr('profile_store_info_section'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ctx.colorTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Divider(color: ctx.colorBorder),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: ctx.tr('profile_store_name'),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Store name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business Category',
                        hintText: 'Grocery, Kirana, Bakery, Mobile',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: ctx.tr('profile_phone'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Support Number',
                        hintText: '9876543210',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: ctx.tr('profile_address'),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: pincodeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Store Tagline / Description',
                        hintText: 'Best quality grocery & daily essentials',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              final success = await authController.updateShop({
                                'name': nameCtrl.text.trim(),
                                'category': categoryCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'whatsapp_number': whatsappCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'city': cityCtrl.text.trim(),
                                'pincode': pincodeCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim(),
                              });
                              if (ctx.mounted) {
                                setSheetState(() => isSaving = false);
                                if (success) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Store details updated successfully')),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(ctx.tr('btn_save')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- EDIT TIMINGS & PAYMENTS MODAL ---
  void _showEditTimingsSheet(BuildContext context, AuthController authController, ShopModel? shop) {
    final openingCtrl = TextEditingController(text: shop?.openingTime ?? '09:00 AM');
    final closingCtrl = TextEditingController(text: shop?.closingTime ?? '09:00 PM');
    final weeklyOffCtrl = TextEditingController(text: shop?.weeklyOff ?? 'Open 7 days');
    final upiCtrl = TextEditingController(text: shop?.upiId ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ctx.tr('profile_timings_section'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ctx.colorTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Divider(color: ctx.colorBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: openingCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Opening Time',
                        hintText: '09:00 AM',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: closingCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Closing Time',
                        hintText: '09:00 PM',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: weeklyOffCtrl,
                decoration: const InputDecoration(
                  labelText: 'Weekly Off Day',
                  hintText: 'Open 7 days / Sunday',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: upiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store UPI VPA ID (For Instant QR Payments)',
                  hintText: 'shopname@upi',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setSheetState(() => isSaving = true);
                        final success = await authController.updateShop({
                          'opening_time': openingCtrl.text.trim(),
                          'closing_time': closingCtrl.text.trim(),
                          'weekly_off': weeklyOffCtrl.text.trim(),
                          'upi_id': upiCtrl.text.trim(),
                        });
                        if (ctx.mounted) {
                          setSheetState(() => isSaving = false);
                          if (success) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Timings & payment VPA updated')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(ctx.tr('btn_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- EDIT OWNER PROFILE MODAL ---
  void _showEditOwnerSheet(BuildContext context, AuthController authController, UserModel? user) {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: ctx.colorSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ctx.tr('profile_owner_section'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ctx.colorTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ctx.colorTextSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Divider(color: ctx.colorBorder),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: ctx.tr('profile_phone'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setSheetState(() => isSaving = true);
                        final success = await authController.updateUserProfile(
                          fullName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        if (ctx.mounted) {
                          setSheetState(() => isSaving = false);
                          if (success) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Owner profile updated')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(ctx.tr('btn_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leadingWidget;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  const _SettingTile({
    this.icon,
    this.leadingWidget,
    required this.title,
    required this.subtitle,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: leadingWidget ??
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: context.colorTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: context.colorTextSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colorTextMuted,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded, size: 18, color: context.colorTextMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _IconTogglePill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconTogglePill({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : context.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _TextTogglePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TextTogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : context.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}
