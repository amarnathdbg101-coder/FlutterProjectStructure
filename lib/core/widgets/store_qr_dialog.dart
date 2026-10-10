import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../widgets/app_ui_components.dart';
import '../../features/dashboard/models/shop_model.dart';

void showStoreQrDialog(BuildContext context, ShopModel? shop) {
  final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Store';
  final shopSlug = shop?.slug.isNotEmpty == true ? shop!.slug : 'store';
  final storefrontUrl = 'https://shopsilo.in/shop/$shopSlug';
  final isOpen = shop?.isOpen ?? true;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ctx.colorSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ctx.colorPrimaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ctx.tr('dash_dialog_qr_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ctx.colorTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: ctx.colorTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: ctx.colorBorder),
              const SizedBox(height: 14),

              // Store Meta
              Text(
                shopName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: ctx.colorTextPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  AppBadge(
                    label: shop?.category.isNotEmpty == true ? shop!.category : 'General Store',
                    type: AppBadgeType.primary,
                  ),
                  AppBadge(
                    label: isOpen ? ctx.tr('profile_status_open') : ctx.tr('profile_status_closed'),
                    type: isOpen ? AppBadgeType.success : AppBadgeType.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scannable Real QR Standee
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ctx.colorBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: storefrontUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  embeddedImage: null,
                ),
              ),
              const SizedBox(height: 12),

              // Helpful Instruction
              Text(
                ctx.tr('storefront_qr_dialog_scan'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: ctx.colorTextSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),

              // Real URL Display Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ctx.colorSurfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ctx.colorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'shopsilo.in/shop/$shopSlug',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                      tooltip: ctx.tr('btn_copy'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: storefrontUrl));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(ctx.tr('profile_link_copied')),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons: Preview Customer Store & Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        ctx.tr('storefront_preview_btn'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/shop/$shopSlug');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Brand Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: Text(
                        ctx.tr('storefront_share_btn'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final shareText = Uri.encodeComponent(
                          'Visit $shopName online store to order directly: $storefrontUrl',
                        );
                        final waUrl = Uri.parse('https://wa.me/?text=$shareText');
                        if (await canLaunchUrl(waUrl)) {
                          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
