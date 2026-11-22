import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../controllers/batch_expiry_controller.dart';

/// Industrial PDF Generator for Store Expiry Audits & Stock Verification
class ExpiryAuditPdfService {
  static Future<Uint8List> generateAuditPdf({
    required List<ExpiryTrackedItem> items,
    required double totalCapitalAtRisk,
    required double expiredCapitalLost,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'STORE EXPIRY RADAR & AUDIT SHEET',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                ),
                pw.Text(
                  'Date: $nowFormatted',
                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Store: $shopName | Physical Shelf Verification & Clearance Checklist',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (context) => [
          // Executive Metric Summary Cards
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricBox('Total Tracked', '${items.length} SKUs', PdfColors.blueGrey800),
              _buildMetricBox('Capital at Risk (30D)', 'Rs. ${totalCapitalAtRisk.toStringAsFixed(0)}', PdfColors.amber900),
              _buildMetricBox('Expired Dead Stock', 'Rs. ${expiredCapitalLost.toStringAsFixed(0)}', PdfColors.red800),
            ],
          ),
          pw.SizedBox(height: 14),
          // Verified Stock Table
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'Product Name',
              'Batch / Lot',
              'Expiry',
              'Urgency',
              'Stock',
              'Cost',
              'MRP',
              'Checked',
            ],
            data: items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final i = entry.value;
              String urgency;
              if (i.isExpired) {
                urgency = 'EXPIRED (${i.daysRemaining.abs()}d ago)';
              } else if (i.daysRemaining <= 7) {
                urgency = 'CRITICAL (${i.daysRemaining}d)';
              } else if (i.daysRemaining <= 30) {
                urgency = 'WARNING (${i.daysRemaining}d)';
              } else {
                urgency = 'SAFE (${i.daysRemaining}d)';
              }

              return [
                '$idx',
                i.name.length > 25 ? '${i.name.substring(0, 22)}...' : i.name,
                i.batchNumber ?? '-',
                dateFormat.format(i.expiryDate),
                urgency,
                '${i.stockQuantity.toStringAsFixed(0)} ${i.unit}',
                'Rs. ${i.purchaseCost.toStringAsFixed(0)}',
                'Rs. ${i.mrp.toStringAsFixed(0)}',
                '[   ]',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
          ),
        ],
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ShopSilo Enterprise Inventory Control System', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricBox(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static Future<void> printOrShareAuditPdf({
    required List<ExpiryTrackedItem> items,
    required double totalCapitalAtRisk,
    required double expiredCapitalLost,
    required String shopName,
  }) async {
    final pdfBytes = await generateAuditPdf(
      items: items,
      totalCapitalAtRisk: totalCapitalAtRisk,
      expiredCapitalLost: expiredCapitalLost,
      shopName: shopName,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Expiry_Audit_Sheet_${DateFormat("yyyyMMdd").format(DateTime.now())}.pdf',
    );
  }
}
