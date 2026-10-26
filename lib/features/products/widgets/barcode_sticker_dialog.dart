import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/product_model.dart';
import '../screens/barcode_sheet_studio_screen.dart';
import '../services/barcode_generator_service.dart';

class BarcodeStickerDialog extends StatefulWidget {
  final ProductModel product;

  const BarcodeStickerDialog({
    super.key,
    required this.product,
  });

  /// Static helper to show the dialog
  static Future<void> show(BuildContext context, ProductModel product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeStickerDialog(product: product),
    );
  }

  @override
  State<BarcodeStickerDialog> createState() => _BarcodeStickerDialogState();
}

class _BarcodeStickerDialogState extends State<BarcodeStickerDialog> {
  BarcodeLabelFormat _format = BarcodeLabelFormat.a4Sheet24;
  int _copies = 24; // Default to 1 full A4 sheet
  bool _isProcessing = false;

  void _adjustCopies(int delta) {
    setState(() {
      _copies = (_copies + delta).clamp(1, 120);
    });
  }

  void _setCopies(int count) {
    setState(() {
      _copies = count.clamp(1, 120);
    });
  }

  Future<void> _handlePrint() async {
    setState(() => _isProcessing = true);
    try {
      final shop = context.read<AuthController>().currentShop;
      final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'SHOPSILO MART';
      final item = BarcodeLabelItem.fromProduct(product: widget.product, shopName: shopName);
      final items = List.generate(_copies, (_) => item);

      await BarcodeGeneratorService.printLabels(
        items: items,
        format: _format,
        jobName: '${widget.product.name}_Labels',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSharePdf() async {
    setState(() => _isProcessing = true);
    try {
      final shop = context.read<AuthController>().currentShop;
      final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'SHOPSILO MART';
      final item = BarcodeLabelItem.fromProduct(product: widget.product, shopName: shopName);
      final items = List.generate(_copies, (_) => item);

      await BarcodeGeneratorService.shareLabelsPdf(
        items: items,
        format: _format,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<AuthController>().currentShop;
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'SHOPSILO MART';
    final labelItem = BarcodeLabelItem.fromProduct(product: widget.product, shopName: shopName);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('barcode_label_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colorTextPrimary,
                      ),
                    ),
                    Text(
                      context.tr('barcode_label_sub'),
                      style: TextStyle(fontSize: 11.5, color: context.colorTextMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. LIVE STICKER PREVIEW CARD
                  Text(
                    context.tr('barcode_preview'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Shop Name & Unit
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  labelItem.shopName,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (labelItem.unit.isNotEmpty)
                                Text(
                                  labelItem.unit,
                                  style: TextStyle(fontSize: 8, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Product Name
                          Text(
                            labelItem.productName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),

                          // Selling Price & MRP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${labelItem.sellingPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              if (labelItem.mrp > labelItem.sellingPrice) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'MRP: ₹${labelItem.mrp.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Vector Code 128 Barcode Widget
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: labelItem.barcode,
                            width: 200,
                            height: 38,
                            drawText: false,
                            color: Colors.black,
                          ),
                          const SizedBox(height: 3),

                          // Barcode String & PKD
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                labelItem.barcode,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (labelItem.pkdDate != null)
                                Text(
                                  '${context.tr("barcode_pkd")}: ${labelItem.pkdDate}',
                                  style: TextStyle(fontSize: 7.5, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // STUDIO PROMO BANNER FOR MULTI-PRODUCT PRINTING
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isHindi
                                    ? '1-2 स्टीकर दूसरे सामान के साथ प्रिंट करें?'
                                    : 'Print 1-2 labels along with other items?',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                context.isHindi
                                    ? 'बारकोड प्रिंट स्टूडियो में जाकर कई सामानों की संयुक्त शीट बनाएं।'
                                    : 'Open Barcode Studio to combine multiple items onto one A4 sticker sheet.',
                                style: TextStyle(fontSize: 10.5, color: context.colorTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            BarcodeSheetStudioScreen.show(context, initialProduct: widget.product);
                          },
                          child: Text(
                            context.isHindi ? 'स्टूडियो' : 'Studio',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. FORMAT SELECTOR
                  Text(
                    context.tr('barcode_format'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFormatCard(
                        context,
                        title: 'A4 • 65 Micro',
                        subtitle: context.isHindi ? 'छोटा (38x21mm)' : 'Micro (38x21mm)',
                        icon: Icons.apps_rounded,
                        isSelected: _format == BarcodeLabelFormat.a4Sheet65,
                        onTap: () {
                          setState(() {
                            _format = BarcodeLabelFormat.a4Sheet65;
                            if (_copies > 65) _copies = 65;
                          });
                        },
                      ),
                      _buildFormatCard(
                        context,
                        title: 'A4 • 40 Compact',
                        subtitle: context.isHindi ? 'मीडियम (48x25mm)' : 'Compact (48x25mm)',
                        icon: Icons.grid_on_rounded,
                        isSelected: _format == BarcodeLabelFormat.a4Sheet40,
                        onTap: () {
                          setState(() {
                            _format = BarcodeLabelFormat.a4Sheet40;
                            if (_copies > 40) _copies = 40;
                          });
                        },
                      ),
                      _buildFormatCard(
                        context,
                        title: context.tr('barcode_format_a4'),
                        subtitle: context.isHindi ? 'बड़ा (64x34mm)' : 'Standard 24L',
                        icon: Icons.grid_view_rounded,
                        isSelected: _format == BarcodeLabelFormat.a4Sheet24,
                        onTap: () {
                          setState(() {
                            _format = BarcodeLabelFormat.a4Sheet24;
                            if (_copies > 24) _copies = 24;
                          });
                        },
                      ),
                      _buildFormatCard(
                        context,
                        title: context.tr('barcode_format_thermal'),
                        subtitle: context.isHindi ? 'रोल प्रिंटर' : 'Roll Printer',
                        icon: Icons.receipt_long_rounded,
                        isSelected: _format == BarcodeLabelFormat.thermalRoll50x25,
                        onTap: () {
                          setState(() {
                            _format = BarcodeLabelFormat.thermalRoll50x25;
                            if (_copies > 20) _copies = 5;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. NUMBER OF COPIES STEPPER & QUICK CHIPS
                  Text(
                    context.tr('barcode_qty_copies'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colorTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.colorSurfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                          onPressed: () => _adjustCopies(-1),
                        ),
                        Row(
                          children: [
                            Text(
                              '$_copies',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: context.colorTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('inv_stock_units'),
                              style: TextStyle(fontSize: 12, color: context.colorTextMuted),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.primary),
                          onPressed: () => _adjustCopies(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick chips - 1, 2, 5, 10, 24, 40, 65
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [1, 2, 5, 10, 24, 40, 65].map((count) {
                      final isSel = _copies == count;
                      return ActionChip(
                        label: Text(
                          '$count ${context.tr("inv_stock_units")}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? AppColors.primary : context.colorTextPrimary,
                          ),
                        ),
                        backgroundColor: isSel ? context.colorPrimaryLight : context.colorSurfaceSubtle,
                        side: BorderSide(color: isSel ? AppColors.primary : context.colorBorder),
                        onPressed: () => _setCopies(count),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Print & Share PDF
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    context.tr('barcode_btn_share_pdf'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  onPressed: _isProcessing ? null : _handleSharePdf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                  label: Text(
                    context.tr('barcode_btn_print'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: _isProcessing ? null : _handlePrint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.colorPrimaryLight : context.colorSurfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.colorBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : context.colorTextMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : context.colorTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colorTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
