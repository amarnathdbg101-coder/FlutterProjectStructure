import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product_model.dart';

/// Supported Barcode Sticker Formats for Indian Retailers
enum BarcodeLabelFormat {
  /// Micro Stickers for small items, packets, spices, cosmetics: 5 cols x 13 rows = 65 labels (~38mm x 21mm).
  a4Sheet65,

  /// Compact Stickers for groceries & snacks: 4 cols x 10 rows = 40 labels (~48.5mm x 25.4mm).
  a4Sheet40,

  /// Standard Retail Adhesive Sheet (Avery/Desmat 24L): 3 cols x 8 rows = 24 labels (~64mm x 34mm).
  a4Sheet24,

  /// Continuous Thermal Sticker Roll (2" x 1"): 50mm x 25mm.
  thermalRoll50x25,

  /// Mini Continuous Thermal Sticker Roll: 40mm x 20mm.
  thermalRoll40x20,
}

extension BarcodeLabelFormatExtension on BarcodeLabelFormat {
  String get title {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 'A4 • 65 Micro Labels (5x13)';
      case BarcodeLabelFormat.a4Sheet40:
        return 'A4 • 40 Compact Labels (4x10)';
      case BarcodeLabelFormat.a4Sheet24:
        return 'A4 • 24 Standard Labels (3x8)';
      case BarcodeLabelFormat.thermalRoll50x25:
        return 'Thermal Roll • 50x25 mm (2" x 1")';
      case BarcodeLabelFormat.thermalRoll40x20:
        return 'Thermal Roll • 40x20 mm (Mini)';
    }
  }

  String get subtitleEn {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 'Small items, pouches, spices, cosmetics (38 x 21 mm)';
      case BarcodeLabelFormat.a4Sheet40:
        return 'Medium packets, grocery cartons (48.5 x 25.4 mm)';
      case BarcodeLabelFormat.a4Sheet24:
        return 'Standard Indian retail adhesive sheets (64 x 34 mm)';
      case BarcodeLabelFormat.thermalRoll50x25:
        return 'Standard 2" desktop thermal barcode printer roll';
      case BarcodeLabelFormat.thermalRoll40x20:
        return 'Compact direct thermal barcode printer roll';
    }
  }

  String get subtitleHi {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 'छोटे सामान, मसाले, बिस्कुट पैकेट के लिए (38x21मिमी)';
      case BarcodeLabelFormat.a4Sheet40:
        return 'मीडियम किराना व स्नैक्स पैकेट के लिए (48.5x25मिमी)';
      case BarcodeLabelFormat.a4Sheet24:
        return 'स्टैंडर्ड रीटेल स्टीकर शीट (Desmat/Avery 24L)';
      case BarcodeLabelFormat.thermalRoll50x25:
        return '2 इंच कंटीन्यूअस थर्मल प्रिंटर रोल';
      case BarcodeLabelFormat.thermalRoll40x20:
        return 'छोटा थर्मल बारकोड स्टीकर रोल';
    }
  }

  int get labelsPerPage {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 65;
      case BarcodeLabelFormat.a4Sheet40:
        return 40;
      case BarcodeLabelFormat.a4Sheet24:
        return 24;
      case BarcodeLabelFormat.thermalRoll50x25:
      case BarcodeLabelFormat.thermalRoll40x20:
        return 1;
    }
  }

  bool get isA4Sheet =>
      this == BarcodeLabelFormat.a4Sheet65 ||
      this == BarcodeLabelFormat.a4Sheet40 ||
      this == BarcodeLabelFormat.a4Sheet24;

  int get columns {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 5;
      case BarcodeLabelFormat.a4Sheet40:
        return 4;
      case BarcodeLabelFormat.a4Sheet24:
        return 3;
      default:
        return 1;
    }
  }

  int get rows {
    switch (this) {
      case BarcodeLabelFormat.a4Sheet65:
        return 13;
      case BarcodeLabelFormat.a4Sheet40:
        return 10;
      case BarcodeLabelFormat.a4Sheet24:
        return 8;
      default:
        return 1;
    }
  }
}

/// Sheet Utilization & Paper Calculation Statistics
class SheetPackingStats {
  final int totalStickers;
  final int labelsPerPage;
  final int pagesNeeded;
  final int emptySlotsOnLastPage;
  final double utilizationPercentage;

  const SheetPackingStats({
    required this.totalStickers,
    required this.labelsPerPage,
    required this.pagesNeeded,
    required this.emptySlotsOnLastPage,
    required this.utilizationPercentage,
  });

  factory SheetPackingStats.calculate({
    required int totalStickers,
    required BarcodeLabelFormat format,
  }) {
    if (totalStickers <= 0) {
      return const SheetPackingStats(
        totalStickers: 0,
        labelsPerPage: 1,
        pagesNeeded: 0,
        emptySlotsOnLastPage: 0,
        utilizationPercentage: 0.0,
      );
    }

    final perPage = format.labelsPerPage;
    if (!format.isA4Sheet) {
      return SheetPackingStats(
        totalStickers: totalStickers,
        labelsPerPage: 1,
        pagesNeeded: totalStickers,
        emptySlotsOnLastPage: 0,
        utilizationPercentage: 100.0,
      );
    }

    final pages = (totalStickers / perPage).ceil();
    final totalCapacity = pages * perPage;
    final emptySlots = totalCapacity - totalStickers;
    final utilization = (totalStickers / totalCapacity) * 100.0;

    return SheetPackingStats(
      totalStickers: totalStickers,
      labelsPerPage: perPage,
      pagesNeeded: pages,
      emptySlotsOnLastPage: emptySlots,
      utilizationPercentage: utilization,
    );
  }
}

/// Item to be rendered inside an individual barcode sticker slot
class BarcodeLabelItem {
  final String productName;
  final String shopName;
  final String barcode;
  final String sku;
  final double sellingPrice;
  final double mrp;
  final String unit;
  final String? pkdDate;
  final bool showShopName;
  final bool showPrice;
  final bool showPkd;

  BarcodeLabelItem({
    required this.productName,
    required this.shopName,
    required this.barcode,
    required this.sku,
    required this.sellingPrice,
    this.mrp = 0.0,
    this.unit = '',
    this.pkdDate,
    this.showShopName = true,
    this.showPrice = true,
    this.showPkd = true,
  });

  factory BarcodeLabelItem.fromProduct({
    required ProductModel product,
    String shopName = 'SHOPSILO STORE',
    bool showShopName = true,
    bool showPrice = true,
    bool showPkd = true,
  }) {
    String rawBarcode = product.barcode.trim();
    if (rawBarcode.isEmpty) {
      rawBarcode = product.sku.trim();
    }
    if (rawBarcode.isEmpty) {
      rawBarcode = 'PRD-${product.id.toString().padLeft(6, '0')}';
    }

    // Clean non-ascii characters for standard Code 128 compatibility
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
      showShopName: showShopName,
      showPrice: showPrice,
      showPkd: showPkd,
    );
  }
}

class BarcodeGeneratorService {
  /// Computes sheet capacity and page breakdown
  static SheetPackingStats calculatePacking({
    required int totalStickers,
    required BarcodeLabelFormat format,
  }) {
    return SheetPackingStats.calculate(
      totalStickers: totalStickers,
      format: format,
    );
  }

  /// Generates PDF document bytes for a list of label items in the selected format.
  static Future<Uint8List> generatePdfBytes({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelFormat format,
  }) async {
    final pdf = pw.Document();

    switch (format) {
      case BarcodeLabelFormat.a4Sheet65:
        _buildA4Sheet65Pages(pdf, items);
        break;
      case BarcodeLabelFormat.a4Sheet40:
        _buildA4Sheet40Pages(pdf, items);
        break;
      case BarcodeLabelFormat.a4Sheet24:
        _buildA4Sheet24Pages(pdf, items);
        break;
      case BarcodeLabelFormat.thermalRoll50x25:
        _buildThermalRollPages(pdf, items, widthPt: 141.73, heightPt: 70.86);
        break;
      case BarcodeLabelFormat.thermalRoll40x20:
        _buildThermalRollPages(pdf, items, widthPt: 113.39, heightPt: 56.69);
        break;
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

  // =========================================================================
  // 1. A4 65-LABEL MICRO SHEET ENGINE (5 Columns x 13 Rows)
  // Dimensions per label: ~38.1mm x 21.2mm (Ideal for small items & spices)
  // =========================================================================
  static void _buildA4Sheet65Pages(pw.Document pdf, List<BarcodeLabelItem> items) {
    const int labelsPerPage = 65;
    const int cols = 5;

    for (int pageStart = 0; pageStart < items.length; pageStart += labelsPerPage) {
      final pageItems = items.skip(pageStart).take(labelsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: 38.1 / 21.2,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              children: List.generate(pageItems.length, (index) {
                return _buildA4Sheet65SingleLabel(pageItems[index]);
              }),
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildA4Sheet65SingleLabel(BarcodeLabelItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.35),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header: Shop Name & Unit
          if (item.showShopName)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    item.shopName,
                    style: pw.TextStyle(
                      fontSize: 4.0,
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
                    style: const pw.TextStyle(fontSize: 3.8, color: PdfColors.grey600),
                  ),
              ],
            ),

          // Product Name
          pw.Text(
            item.productName,
            style: pw.TextStyle(
              fontSize: 5.2,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Price Row
          if (item.showPrice)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Rs. ${item.sellingPrice.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                    fontSize: 7.0,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                if (item.mrp > item.sellingPrice) ...[
                  pw.SizedBox(width: 2),
                  pw.Text(
                    'MRP: ${item.mrp.toStringAsFixed(0)}',
                    style: const pw.TextStyle(
                      fontSize: 4.0,
                      color: PdfColors.grey600,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),

          // Code 128 Vector Barcode
          pw.Container(
            height: 10.5,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: item.barcode,
              drawText: false,
              color: PdfColors.black,
            ),
          ),

          // Barcode Text & PKD
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                item.barcode,
                style: pw.TextStyle(
                  fontSize: 3.8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              if (item.showPkd && item.pkdDate != null)
                pw.Text(
                  item.pkdDate!,
                  style: const pw.TextStyle(fontSize: 3.4, color: PdfColors.grey600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. A4 40-LABEL COMPACT SHEET ENGINE (4 Columns x 10 Rows)
  // Dimensions per label: ~48.5mm x 25.4mm
  // =========================================================================
  static void _buildA4Sheet40Pages(pw.Document pdf, List<BarcodeLabelItem> items) {
    const int labelsPerPage = 40;
    const int cols = 4;

    for (int pageStart = 0; pageStart < items.length; pageStart += labelsPerPage) {
      final pageItems = items.skip(pageStart).take(labelsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: 48.5 / 25.4,
              crossAxisSpacing: 5,
              mainAxisSpacing: 4.5,
              children: List.generate(pageItems.length, (index) {
                return _buildA4Sheet40SingleLabel(pageItems[index]);
              }),
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildA4Sheet40SingleLabel(BarcodeLabelItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 2.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header: Shop Name & Unit
          if (item.showShopName)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    item.shopName,
                    style: pw.TextStyle(
                      fontSize: 4.8,
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
                    style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600),
                  ),
              ],
            ),

          // Product Name
          pw.Text(
            item.productName,
            style: pw.TextStyle(
              fontSize: 6.6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Price Row
          if (item.showPrice)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Rs. ${item.sellingPrice.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                if (item.mrp > item.sellingPrice) ...[
                  pw.SizedBox(width: 3),
                  pw.Text(
                    'MRP: ${item.mrp.toStringAsFixed(0)}',
                    style: const pw.TextStyle(
                      fontSize: 4.8,
                      color: PdfColors.grey600,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),

          // Code 128 Barcode
          pw.Container(
            height: 14,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: item.barcode,
              drawText: false,
              color: PdfColors.black,
            ),
          ),

          // Barcode Text & PKD
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                item.barcode,
                style: pw.TextStyle(
                  fontSize: 4.6,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              if (item.showPkd && item.pkdDate != null)
                pw.Text(
                  'PKD: ${item.pkdDate}',
                  style: const pw.TextStyle(fontSize: 4.0, color: PdfColors.grey600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. A4 24-LABEL STANDARD SHEET ENGINE (3 Columns x 8 Rows)
  // Dimensions per label: ~64mm x 34mm (Standard Desmat/Avery 24L)
  // =========================================================================
  static void _buildA4Sheet24Pages(pw.Document pdf, List<BarcodeLabelItem> items) {
    const int labelsPerPage = 24;
    const int cols = 3;

    for (int pageStart = 0; pageStart < items.length; pageStart += labelsPerPage) {
      final pageItems = items.skip(pageStart).take(labelsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: cols,
              childAspectRatio: 64 / 34,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
              children: List.generate(pageItems.length, (index) {
                return _buildA4Sheet24SingleLabel(pageItems[index]);
              }),
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildA4Sheet24SingleLabel(BarcodeLabelItem item) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header: Store Name & Unit
          if (item.showShopName)
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
              fontSize: 7.6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),

          // Price & MRP Row
          if (item.showPrice)
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
                  fontSize: 5.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              if (item.showPkd && item.pkdDate != null)
                pw.Text(
                  'PKD: ${item.pkdDate}',
                  style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. THERMAL CONTINUOUS ROLL ENGINE (Flexible Width/Height Points)
  // =========================================================================
  static void _buildThermalRollPages(
    pw.Document pdf,
    List<BarcodeLabelItem> items, {
    required double widthPt,
    required double heightPt,
  }) {
    final format = PdfPageFormat(widthPt, heightPt, marginAll: 4.5);

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
                if (item.showShopName || (item.showPkd && item.pkdDate != null))
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.showShopName)
                        pw.Text(
                          item.shopName,
                          style: pw.TextStyle(
                            fontSize: 5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      if (item.showPkd && item.pkdDate != null)
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
                    fontSize: 7.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textAlign: pw.TextAlign.center,
                ),

                // Price Row
                if (item.showPrice)
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
                  height: 17,
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
                    fontSize: 5.0,
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
