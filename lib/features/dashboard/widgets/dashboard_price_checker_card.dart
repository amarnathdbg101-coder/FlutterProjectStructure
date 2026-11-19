import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/mobile_barcode_scanner_dialog.dart';

/// Executive Dashboard Launcher Card for Instant Price & Stock Checker.
/// Replaces the old heavy inline search box with a sleek, clean, modern
/// quick-action card that opens the dedicated full-screen PriceCheckerScreen.
class DashboardPriceCheckerCard extends StatelessWidget {
  const DashboardPriceCheckerCard({super.key});

  void _openCameraScanner(BuildContext context) {
    MobileBarcodeScannerDialog.show(
      context,
      title: context.isHindi ? 'बारकोड स्कैन करें' : 'Scan Product Barcode',
      subtitle: context.isHindi
          ? 'रेट व स्टॉक तुरंत देखने के लिए स्कैन करें'
          : 'Scan barcode to check live rate & stock',
      autoCloseOnSuccess: true,
      onBarcodeScanned: (barcode) async {
        final clean = barcode.trim();
        if (clean.isNotEmpty) {
          context.push('/merchant/price-checker?barcode=${Uri.encodeComponent(clean)}');
        }
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/merchant/price-checker'),
      child: Row(
        children: [
          // Sleek Tonal Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colorPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.price_check_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Titles & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isHindi ? 'तुरंत भाव व स्टॉक जांचें' : 'Instant Price & Stock Checker',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.colorTextPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isHindi ? 'तेज़' : 'FAST',
                        style: const TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isHindi
                      ? 'बारकोड स्कैन या नाम से सही रेट व स्टॉक देखें'
                      : 'Scan barcode or search name for instant rates',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: context.colorTextMuted,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Buttons: Quick Camera Scan + Open Checker
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick 1-Tap Camera Scan Pill
              InkWell(
                onTap: () => _openCameraScanner(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colorBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isHindi ? 'स्कैन' : 'Scan',
                        style: const TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: context.colorTextMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
