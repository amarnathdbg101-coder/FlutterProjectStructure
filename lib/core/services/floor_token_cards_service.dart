import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Service to generate and print 20 laminated floor tokens (T-01 to T-20)
/// with bold token numbers and camera-scannable QR codes on a single A4 sheet.
class FloorTokenCardsService {
  /// Generates A4 PDF and triggers system print / save dialog
  static Future<void> printFloorTokens(
    BuildContext context, {
    String shopName = 'SHOPSILO STORE',
  }) async {
    final pdfBytes = await generateTokensPdf(shopName: shopName);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'ShopSilo_Floor_Tokens_T01_T20.pdf',
    );
  }

  /// Builds A4 PDF containing 20 tokens (4 columns x 5 rows)
  static Future<Uint8List> generateTokensPdf({
    String shopName = 'SHOPSILO STORE',
  }) async {
    final pdf = pw.Document();

    final cleanShopName = shopName.trim().isNotEmpty ? shopName.trim().toUpperCase() : 'SHOPSILO STORE';

    // A4 dimensions: 210mm x 297mm
    // Page with 20 cards (4 columns x 5 rows)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header title on sheet
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$cleanShopName - CUSTOMER FLOOR BASKET TOKENS (T-01 TO T-20)',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    'Cut along dashed lines & laminate for daily floor use',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // 5 Rows x 4 Columns = 20 Tokens Grid
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (rowIndex) {
                    return pw.Expanded(
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (colIndex) {
                          final tokenNum = (rowIndex * 4) + colIndex + 1;
                          final tokenLabel = 'T-${tokenNum.toString().padLeft(2, '0')}';
                          return pw.Expanded(
                            child: pw.Container(
                              margin: const pw.EdgeInsets.all(3),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey400,
                                  width: 1,
                                  style: pw.BorderStyle.dashed,
                                ),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  // Shop Name
                                  pw.Text(
                                    cleanShopName,
                                    maxLines: 1,
                                    style: pw.TextStyle(
                                      fontSize: 6.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blueGrey800,
                                    ),
                                  ),

                                  // Middle Section: Token Number + QR Code
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      // Bold Token Badge
                                      pw.Container(
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.blueGrey900,
                                          borderRadius: pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Text(
                                          tokenLabel,
                                          style: pw.TextStyle(
                                            fontSize: 16,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.white,
                                          ),
                                        ),
                                      ),

                                      // Scannable Token QR Code
                                      pw.Container(
                                        width: 44,
                                        height: 44,
                                        child: pw.BarcodeWidget(
                                          barcode: pw.Barcode.qrCode(),
                                          data: 'SHOP-TOKEN:$tokenLabel',
                                          color: PdfColors.black,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Instructions Subtitle
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey100,
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                    child: pw.Text(
                                      'FLOOR BASKET - PLEASE RETURN AT COUNTER',
                                      style: const pw.TextStyle(
                                        fontSize: 4.8,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
