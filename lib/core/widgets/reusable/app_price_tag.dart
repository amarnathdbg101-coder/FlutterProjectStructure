import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Typographic scale for consistent price display across ShopSilo.
enum AppPriceSize {
  /// 12.5px: Compact for cart item subtitles, table rows
  sm,

  /// 15.0px: Default for standard product tiles and list cards
  md,

  /// 19.0px: Emphasized for product detail screens, subtotal summaries
  lg,

  /// 24.0px: Hero scale for final checkout totals and KPI highlights
  xl,
}

/// Universal Production-Grade Price & Currency Display Component.
/// Handles Indian Rupee (₹) symbol, optional strikethrough MRP, and percentage savings pills.
class AppPriceTag extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final AppPriceSize size;
  final Color? color;
  final String? unit;
  final bool showSavingsPill;
  final bool isBold;

  const AppPriceTag({
    super.key,
    required this.price,
    this.originalPrice,
    this.size = AppPriceSize.md,
    this.color,
    this.unit,
    this.showSavingsPill = true,
    this.isBold = true,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve font sizes based on scale preset
    double mainFontSize;
    double mrpFontSize;
    double savingsFontSize;

    switch (size) {
      case AppPriceSize.sm:
        mainFontSize = 12.5;
        mrpFontSize = 10.5;
        savingsFontSize = 9.5;
        break;
      case AppPriceSize.md:
        mainFontSize = 15.0;
        mrpFontSize = 12.0;
        savingsFontSize = 10.0;
        break;
      case AppPriceSize.lg:
        mainFontSize = 19.0;
        mrpFontSize = 13.5;
        savingsFontSize = 11.0;
        break;
      case AppPriceSize.xl:
        mainFontSize = 24.0;
        mrpFontSize = 15.0;
        savingsFontSize = 12.0;
        break;
    }

    final hasDiscount = originalPrice != null && originalPrice! > price;
    final discountPercent = hasDiscount
        ? (((originalPrice! - price) / originalPrice!) * 100).round()
        : 0;

    final effectiveColor = color ?? context.colorTextPrimary;

    // Formatting: omit decimals if whole number, else show 2 decimals
    final formattedPrice = price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
    final formattedMrp = (originalPrice != null)
        ? (originalPrice! % 1 == 0 ? originalPrice!.toInt().toString() : originalPrice!.toStringAsFixed(2))
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 1. Primary Selling Price
        Text(
          '₹$formattedPrice',
          style: TextStyle(
            fontSize: mainFontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: effectiveColor,
            letterSpacing: -0.3,
          ),
        ),

        // Optional unit (e.g., "/kg" or "/m")
        if (unit != null && unit!.trim().isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(
            unit!.startsWith('/') ? unit! : '/$unit',
            style: TextStyle(
              fontSize: mrpFontSize,
              color: context.colorTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // 2. Strikethrough Original MRP (if discounted)
        if (hasDiscount) ...[
          const SizedBox(width: 6),
          Text(
            '₹$formattedMrp',
            style: TextStyle(
              fontSize: mrpFontSize,
              color: context.colorTextMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: context.colorTextMuted.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // 3. Discount Percentage Pill (e.g. "20% OFF")
        if (hasDiscount && showSavingsPill && discountPercent > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.darkSuccessLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25), width: 0.6),
            ),
            child: Text(
              '$discountPercent% OFF',
              style: TextStyle(
                fontSize: savingsFontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
