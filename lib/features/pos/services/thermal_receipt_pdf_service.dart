import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/pos_model.dart';
import '../../../core/constants/app_colors.dart';

enum ThermalReceiptWidth {
  /// Standard 58mm (2-inch) thermal paper roll
  roll58mm,

  /// Standard 80mm (3-inch) thermal paper roll
  roll80mm,
}

/// Enterprise Vector Thermal Receipt PDF Service
/// Renders crisp, printer-ready receipts for ESC/POS Bluetooth, USB & Desktop printers.
class ThermalReceiptPdfService {
  /// Generates printable PDF bytes for a given SaleModel and Shop Details
  static Future<Uint8List> generateReceiptPdf({
    required SaleModel sale,
    required String shopName,
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    ThermalReceiptWidth width = ThermalReceiptWidth.roll80mm,
    bool isHindi = false,
  }) async {
    final pdf = pw.Document();

    // Define page dimensions for 80mm or 58mm continuous roll
    final pageFormat = width == ThermalReceiptWidth.roll58mm
        ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
        : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm);

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt);
    final totalItemsCount = sale.items.fold(0, (sum, i) => sum + i.quantity);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. STORE HEADER
                pw.Text(
                  shopName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: width == ThermalReceiptWidth.roll58mm ? 12 : 14),
                  textAlign: pw.TextAlign.center,
                ),
                if (shopAddress.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    shopAddress.trim(),
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                if (shopPhone.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Phone: ${shopPhone.trim()}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                if (shopGstin.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'GSTIN: ${shopGstin.trim()}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                pw.SizedBox(height: 3),
                pw.Text(
                  'RETAIL TAX INVOICE / बिल',
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),

                // Dashed Line
                pw.SizedBox(height: 4),
                _buildDashedLine(),
                pw.SizedBox(height: 4),

                // 2. INVOICE META
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bill #: ${sale.billNumber ?? "WALK-IN"}', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.Text(sale.paymentMethod.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: $dateStr', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                    if (sale.customerPhone.isNotEmpty)
                      pw.Text('Cust: ${sale.customerPhone}', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                  ],
                ),

                pw.SizedBox(height: 4),
                _buildDashedLine(),
                pw.SizedBox(height: 4),

                // 3. TABLE HEADER
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('ITEM', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('QTY', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('RATE', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.right),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('AMT', style: pw.TextStyle(font: fontBold, fontSize: 8), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),

                pw.SizedBox(height: 2),
                _buildDashedLine(),
                pw.SizedBox(height: 3),

                // 4. ITEMS LIST
                ...sale.items.map((item) {
                  final rate = item.effectivePrice;
                  final total = item.total;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.product.name,
                                style: pw.TextStyle(font: fontRegular, fontSize: 8),
                                maxLines: 2,
                              ),
                              if (item.product.unit.isNotEmpty)
                                pw.Text(
                                  '(${item.product.unit})',
                                  style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: PdfColors.grey700),
                                ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '${item.quantity}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            rate.toStringAsFixed(0),
                            style: pw.TextStyle(font: fontRegular, fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            total.toStringAsFixed(0),
                            style: pw.TextStyle(font: fontBold, fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 4),
                _buildDashedLine(),
                pw.SizedBox(height: 4),

                // 5. TOTALS & SUMMARY
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Items: ${sale.items.length} (Qty $totalItemsCount)', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    pw.Text('Subtotal: ₹${sale.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
                if (sale.discountAmount > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Discount / छूट:', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                      pw.Text('-₹${sale.discountAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.symmetric(
                      horizontal: const pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('GRAND TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    ],
                  ),
                ),

                // Payment Breakdown if split
                if (sale.splitPayments != null) ...[
                  pw.SizedBox(height: 3),
                  if (sale.splitPayments!.cashAmount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Paid Cash:', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                        pw.Text('₹${sale.splitPayments!.cashAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                      ],
                    ),
                  if (sale.splitPayments!.onlineAmount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Paid UPI/Online:', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                        pw.Text('₹${sale.splitPayments!.onlineAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                      ],
                    ),
                  if (sale.splitPayments!.khataAmount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Added to Khata (Udhar):', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                        pw.Text('₹${sale.splitPayments!.khataAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                      ],
                    ),
                ],

                // 6. UPI QR Code for Store Reorder or Payment
                if (upiId.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Container(
                      width: 55,
                      height: 55,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(shopName)}&am=${sale.totalAmount.toStringAsFixed(2)}&cu=INR',
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Scan to Pay via PhonePe / GPay / Paytm',
                    style: pw.TextStyle(font: fontRegular, fontSize: 6.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ],

                // 7. FOOTER NOTE
                pw.SizedBox(height: 6),
                _buildDashedLine(),
                pw.SizedBox(height: 4),
                pw.Text(
                  'THANK YOU! VISIT AGAIN / धन्यवाद!',
                  style: pw.TextStyle(font: fontBold, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Software by ShopSilo | shopsilo.in',
                  style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds a clean dashed divider line
  static pw.Widget _buildDashedLine() {
    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final dashWidth = 3.0;
        final dashSpace = 2.0;
        final totalWidth = constraints?.maxWidth ?? 200.0;
        final count = (totalWidth / (dashWidth + dashSpace)).floor();
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return pw.Container(
              width: dashWidth,
              height: 0.8,
              color: PdfColors.black,
            );
          }),
        );
      },
    );
  }

  /// Direct 1-tap Print via OS Spooler (ESC/POS, Bluetooth, USB, Desktop)
  static Future<bool> directPrintReceipt({
    required SaleModel sale,
    required String shopName,
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    ThermalReceiptWidth width = ThermalReceiptWidth.roll80mm,
    bool isHindi = false,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      sale: sale,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      upiId: upiId,
      width: width,
      isHindi: isHindi,
    );

    return await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${sale.billNumber ?? "Sale"}',
    );
  }

  /// Direct 1-tap PDF Share / WhatsApp PDF export
  static Future<void> shareReceiptPdf({
    required SaleModel sale,
    required String shopName,
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    ThermalReceiptWidth width = ThermalReceiptWidth.roll80mm,
    bool isHindi = false,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      sale: sale,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopGstin: shopGstin,
      upiId: upiId,
      width: width,
      isHindi: isHindi,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Receipt_${sale.billNumber ?? "Sale"}.pdf',
    );
  }
}
