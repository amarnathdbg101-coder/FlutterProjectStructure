import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product_model.dart';

enum BarcodeLabelFormat {
  /// Standard pre-cut adhesive sticker sheet: 3 columns x 8 rows = 24 labels per A4 page (~70mm x 37mm per label).
  a4Sheet24,

  /// Continuous thermal sticker printer roll: Single label 50mm x 25mm.
  thermalRoll50x25,
}

class BarcodeLabelItem {
  final String productName;
  final String shopName;
  final String barcode;
  final String sku;
  final double sellingPrice;
  final double mrp;
  final String unit;
  final String? pkdDate;

  BarcodeLabelItem({
    required this.productName,
    required this.shopName,
    required this.barcode,
    required this.sku,
    required this.sellingPrice,
    this.mrp = 0.0,
    this.unit = '',
    this.pkdDate,
  });

  factory BarcodeLabelItem.fromProduct({
    required ProductModel product,
    String shopName = 'SHOPSILO STORE',
  }) {
    // Sanitize or fallback barcode string
    String rawBarcode = product.barcode.trim();
    if (rawBarcode.isEmpty) {
      rawBarcode = product.sku.trim();
    }
    if (rawBarcode.isEmpty) {
      rawBarcode = 'PRD-${product.id.toString().padLeft(6, '0')}';
    }

    // Clean non-ascii for Code 128 compatibility
    final cleanBarcode = rawBarcode.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

    return BarcodeLabelItem(
      productName: product.name.trim(),
      shopName: shopName.trim().toUpperCase(),
      barcode: cleanBarcode.isNotEmpty ? cleanBarcode : 'PRD-000001',
      sku: product.sku.trim().isNotEmpty ? product.sku.trim() : rawBarcode,
      sellingPrice: product.price,
      mrp: product.comparePrice > product.price ? product.comparePrice : 0.0,
      unit: product.unit.trim(),
      pkdDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
  }
}

class BarcodeGeneratorService {
  /// Generates PDF document bytes for a list of label items in the selected format.
  static Future<Uint8List> generatePdfBytes({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelFormat format,
  }) async {
    final pdf = pw.Document();

    if (format == BarcodeLabelFormat.a4Sheet24) {
      _buildA4SheetPages(pdf, items);
    } else {
      _buildThermalRollPages(pdf, items);
    }

    return await pdf.save();
  }

  /// Sends the generated label document directly to the native OS printer spooler/dialog.
  static Future<bool> printLabels({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelFormat format,
    String jobName = 'ShopSilo_Barcode_Labels',
  }) async {
    final bytes = await generatePdfBytes(items: items, format: format);
    return await Printing.layoutPdf(
      onLayout: (PdfPageFormat pdfFormat) async => bytes,
      name: jobName,
    );
  }

  /// Shares the generated label document via WhatsApp, AirDrop, or local file save.
  static Future<void> shareLabelsPdf({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelFormat format,
    String? filename,
  }) async {
    final bytes = await generatePdfBytes(items: items, format: format);
    final safeName = filename ?? 'ShopSilo_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: safeName);
  }

  // --- A4 24-LABEL SHEET ENGINE (3 Columns x 8 Rows) ---
  static void _buildA4SheetPages(pw.Document pdf, List<BarcodeLabelItem> items) {
    const int labelsPerPage = 24;
    const int cols = 3;

    // A4: 210 x 297 mm
    // Margin: left/right 6mm, top/bottom 8mm
    // Available width = 198mm, height = 281mm
    // Per label: width = 64mm, height = 34mm
    for (int pageStart = 0; pageStart < items.length; pageStart += labelsPerPage) {
      final pageItems = items.skip(pageStart).take(labelsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 17, vertical: 22),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: 64 / 34,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
              children: List.generate(pageItems.length, (index) {
                return _buildA4SingleLabel(pageItems[index]);
              }),
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildA4SingleLabel(BarcodeLabelItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header: Store Name & Unit
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  item.shopName,
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              if (item.unit.isNotEmpty)
                pw.Text(
                  item.unit,
                  style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600),
                ),
            ],
          ),

          // Product Name
          pw.Text(
            item.productName,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Price & MRP Row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Rs. ${item.sellingPrice.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              if (item.mrp > item.sellingPrice) ...[
                pw.SizedBox(width: 4),
                pw.Text(
                  'MRP: Rs. ${item.mrp.toStringAsFixed(0)}',
                  style: const pw.TextStyle(
                    fontSize: 5.5,
                    color: PdfColors.grey600,
                    decoration: pw.TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),

          // Scannable Code 128 Vector Barcode
          pw.Container(
            height: 18,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: item.barcode,
              drawText: false,
              color: PdfColors.black,
            ),
          ),

          // Barcode Number / SKU and PKD
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                item.barcode,
                style: pw.TextStyle(
                  fontSize: 5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              if (item.pkdDate != null)
                pw.Text(
                  'PKD: ${item.pkdDate}',
                  style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- THERMAL CONTINUOUS ROLL ENGINE (50mm x 25mm) ---
  static void _buildThermalRollPages(pw.Document pdf, List<BarcodeLabelItem> items) {
    // 50mm = 141.73 points, 25mm = 70.86 points
    const format = PdfPageFormat(141.73, 70.86, marginAll: 5.66);

    for (final item in items) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Store Name & PKD
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      item.shopName,
                      style: pw.TextStyle(
                        fontSize: 5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (item.pkdDate != null)
                      pw.Text(
                        'PKD: ${item.pkdDate}',
                        style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600),
                      ),
                  ],
                ),

                // Product Name
                pw.Text(
                  item.productName,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textAlign: pw.TextAlign.center,
                ),

                // Price Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Rs. ${item.sellingPrice.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    if (item.mrp > item.sellingPrice) ...[
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'MRP: Rs. ${item.mrp.toStringAsFixed(0)}',
                        style: const pw.TextStyle(
                          fontSize: 5,
                          color: PdfColors.grey600,
                          decoration: pw.TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),

                // Code 128 Barcode
                pw.Container(
                  height: 18,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: item.barcode,
                    drawText: false,
                    color: PdfColors.black,
                  ),
                ),

                // Barcode text
                pw.Text(
                  item.barcode,
                  style: pw.TextStyle(
                    fontSize: 5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }
}
