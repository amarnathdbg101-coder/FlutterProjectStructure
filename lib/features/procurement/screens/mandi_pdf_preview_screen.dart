import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../models/procurement_model.dart';
import '../services/procurement_pdf_service.dart';

/// 🖨️ Interactive In-App PDF Preview & Print Screen for Mandi Sourcing Sheet.
/// Allows merchants to visually review the generated purchase order, zoom, page through,
/// print via wireless/Bluetooth printers, or share via WhatsApp/Bluetooth directly.
class MandiPdfPreviewScreen extends StatelessWidget {
  final String shopName;
  final List<ProcurementItemModel> items;
  final double totalBudget;
  final String? shopAddress;
  final String? shopPhone;

  const MandiPdfPreviewScreen({
    super.key,
    required this.shopName,
    required this.items,
    required this.totalBudget,
    this.shopAddress,
    this.shopPhone,
  });

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final safeName = shopName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').trim();
    final fileName = safeName.isNotEmpty && safeName != '_'
        ? '${safeName}_Mandi_Order.pdf'
        : 'Mandi_Wholesale_Order.pdf';

    return Scaffold(
      backgroundColor: context.colorSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.colorSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colorTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? 'क्रय मांग पत्र (PDF प्रिव्यू)' : 'Purchase Order (PDF Preview)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colorTextPrimary),
            ),
            Text(
              '${items.length} ${isHindi ? "सामग्री • थोक क्रय" : "Items • Wholesale"}',
              style: TextStyle(fontSize: 11, color: context.colorTextMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 21, color: AppColors.primary),
            tooltip: isHindi ? 'शेयर करें' : 'Share PDF',
            onPressed: () async {
              await ProcurementPdfService.shareProcurementSheet(
                shopName: shopName,
                items: items,
                totalBudget: totalBudget,
                shopAddress: shopAddress,
                shopPhone: shopPhone,
                isHindi: isHindi,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PdfPreview(
        maxPageWidth: 700,
        build: (format) => ProcurementPdfService.generateProcurementPdf(
          shopName: shopName,
          items: items,
          totalBudget: totalBudget,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          isHindi: isHindi,
        ),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: fileName,
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        loadingWidget: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                isHindi ? 'मांग पत्र तैयार हो रहा है...' : 'Generating Purchase Order PDF...',
                style: TextStyle(fontSize: 13, color: context.colorTextMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
