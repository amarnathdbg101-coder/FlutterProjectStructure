import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../models/pos_model.dart';

/// Executive Sales & Day Close PDF Generator for ShopSilo.
/// Matches the exact styling, colors, and layout of the Mandi Procurement Sheet.
/// 100% vector-based, offline-capable, ultra-crisp printing with full Hindi & ₹ Rupee support.
class SalesPdfService {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  static File? _findFontFile(String filename) {
    final candidates = [
      'assets/fonts/$filename',
      'Frontend/assets/fonts/$filename',
      '../assets/fonts/$filename',
      '${Directory.current.path}/assets/fonts/$filename',
      '${Directory.current.path}/Frontend/assets/fonts/$filename',
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) return f;
    }
    return null;
  }

  static Future<pw.ThemeData> _getTheme() async {
    if (_cachedRegular == null) {
      try {
        ByteData regData;
        try {
          regData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
        } catch (_) {
          final f = _findFontFile('NotoSansDevanagari-Regular.ttf');
          if (f != null) {
            regData = ByteData.view(f.readAsBytesSync().buffer);
          } else {
            rethrow;
          }
        }
        _cachedRegular = pw.Font.ttf(regData);
      } catch (_) {
        _cachedRegular = null;
      }
    }
    if (_cachedBold == null) {
      try {
        ByteData boldData;
        try {
          boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
        } catch (_) {
          final f = _findFontFile('NotoSansDevanagari-Bold.ttf');
          if (f != null) {
            boldData = ByteData.view(f.readAsBytesSync().buffer);
          } else {
            rethrow;
          }
        }
        _cachedBold = pw.Font.ttf(boldData);
      } catch (_) {
        _cachedBold = null;
      }
    }

    final devanagariFallback = [
      if (_cachedRegular != null) _cachedRegular!,
      if (_cachedBold != null) _cachedBold!,
    ];

    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      fontFallback: devanagariFallback,
    );
  }

  static pw.MemoryImage? _cachedLogo;

  static Future<pw.MemoryImage?> _getLogoImage() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      ByteData data;
      try {
        data = await rootBundle.load('assets/images/app_mark.png');
      } catch (_) {
        final candidates = [
          'assets/images/app_mark.png',
          'Frontend/assets/images/app_mark.png',
          '../assets/images/app_mark.png',
          '${Directory.current.path}/assets/images/app_mark.png',
          '${Directory.current.path}/Frontend/assets/images/app_mark.png',
        ];
        File? f;
        for (final c in candidates) {
          final file = File(c);
          if (file.existsSync()) {
            f = file;
            break;
          }
        }
        if (f != null) {
          data = ByteData.view(f.readAsBytesSync().buffer);
        } else {
          return null;
        }
      }
      _cachedLogo = pw.MemoryImage(data.buffer.asUint8List());
      return _cachedLogo;
    } catch (_) {
      return null;
    }
  }

  // In-memory LRU byte cache for generated Sales PDF Reports (0ms instant sharing)
  static final Map<String, Uint8List> _salesPdfByteCache = {};

  static String _buildCacheKey({
    required String shopName,
    required int windowDays,
    required int totalBills,
    required double totalRevenue,
    required int itemsCount,
    required bool isHindi,
  }) {
    return '${shopName}_${windowDays}_${totalBills}_${totalRevenue.toStringAsFixed(0)}_${itemsCount}_${isHindi ? "hi" : "en"}';
  }

  /// Builds printable A4 PDF bytes for the given list of sold items.
  /// Strictly outputs 100% English or 100% pure Hindi based on active language.
  static Future<Uint8List> generateSalesPdf({
    required String shopName,
    required List<SoldProductTimelineItem> items,
    required double totalRevenue,
    required int totalBills,
    required double cashRevenue,
    required double upiRevenue,
    required double khataRevenue,
    int windowDays = 1,
    String? shopAddress,
    String? shopPhone,
    bool? isHindi,
  }) async {
    final useHindi = isHindi ?? LanguageController.isHindi;
    final cachedShop = LocalCacheService.getShop();
    final cleanShopName = shopName.trim().isNotEmpty && shopName.trim() != 'ShopSilo Merchant'
        ? shopName.trim()
        : (cachedShop?.name.trim().isNotEmpty ?? false
            ? cachedShop!.name.trim()
            : (useHindi ? 'शॉपसाइलो पार्टनर स्टोर' : 'ShopSilo Partner Store'));

    final cacheKey = _buildCacheKey(
      shopName: cleanShopName,
      windowDays: windowDays,
      totalBills: totalBills,
      totalRevenue: totalRevenue,
      itemsCount: items.length,
      isHindi: useHindi,
    );
    if (_salesPdfByteCache.containsKey(cacheKey)) {
      return _salesPdfByteCache[cacheKey]!;
    }

    final theme = await _getTheme();
    final logoImg = await _getLogoImage();
    final pdf = pw.Document(theme: theme);

    final dateStr = DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now());

    final cleanAddress = (shopAddress != null && shopAddress.trim().isNotEmpty)
        ? shopAddress.trim()
        : (cachedShop != null && cachedShop.address.trim().isNotEmpty
            ? cachedShop.address.trim()
            : null);

    final cleanPhone = (shopPhone != null && shopPhone.trim().isNotEmpty)
        ? shopPhone.trim()
        : (cachedShop != null && cachedShop.phone.trim().isNotEmpty
            ? cachedShop.phone.trim()
            : (cachedShop != null && cachedShop.whatsappNumber.trim().isNotEmpty
                ? cachedShop.whatsappNumber.trim()
                : null));

    final is10Days = windowDays > 1;
    final reportTitle = is10Days
        ? (useHindi
            ? '${cleanShopName.toUpperCase()} - 10 दिवसीय बिक्री रिपोर्ट एवं ऑडिट'
            : '${cleanShopName.toUpperCase()} - 10-DAY SALES JOURNAL & AUDIT')
        : (useHindi
            ? '${cleanShopName.toUpperCase()} - दैनिक बिक्री एवं लाभ-हानि रिपोर्ट'
            : '${cleanShopName.toUpperCase()} - TODAY SALES & P&L REPORT');

    final totalUnitsSold = items.fold(0, (sum, i) => sum + i.quantity);

    // Executive Color Palette (Identical to Mandi Procurement Sheet)
    const cTopBanner = PdfColor.fromInt(0xFF0F172A); // #0f172a (Dark Navy Executive Bar)
    const cHeaderSub = PdfColor.fromInt(0xFF94A3B8); // #94a3b8 (Slate Muted)
    const cDark = PdfColor.fromInt(0xFF0F172A);      // #0f172a (Primary text)
    const cMuted = PdfColor.fromInt(0xFF475569);     // #475569 (Secondary text)
    const cTblHeader = PdfColor.fromInt(0xFF312E81); // #312e81 (Deep Indigo Table Header)
    const cAltRow = PdfColor.fromInt(0xFFF8FAFC);    // #f8fafc (Alternate row)
    const cBorder = PdfColor.fromInt(0xFFE2E8F0);    // #e2e8f0 (Grid borders)
    const cCardBg = PdfColor.fromInt(0xFFF8FAFC);    // #f8fafc (Pill background)
    const cCardBorder = PdfColor.fromInt(0xFFCBD5E1);// #cbd5e1 (Pill border)
    const cBlueAccent = PdfColor.fromInt(0xFF1E3A8A);// #1e3a8a (Pill text / Qty)

    // Pagination chunking
    const int page1MaxItems = 15;
    const int otherPagesMaxItems = 25;

    List<List<SoldProductTimelineItem>> pages = [];
    if (items.isEmpty) {
      pages.add([]);
    } else {
      int remainingStart = 0;
      // First page chunk
      final firstChunkEnd = items.length > page1MaxItems ? page1MaxItems : items.length;
      pages.add(items.sublist(0, firstChunkEnd));
      remainingStart = firstChunkEnd;

      // Subsequent page chunks
      while (remainingStart < items.length) {
        final end = (remainingStart + otherPagesMaxItems < items.length)
            ? remainingStart + otherPagesMaxItems
            : items.length;
        pages.add(items.sublist(remainingStart, end));
        remainingStart = end;
      }
    }

    final totalPages = pages.length;
    int globalIndex = 0;

    for (int pIdx = 0; pIdx < totalPages; pIdx++) {
      final pageItems = pages[pIdx];
      final isFirstPage = pIdx == 0;
      final isLastPage = pIdx == totalPages - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. TOP FULL-WIDTH DARK NAVY EXECUTIVE BANNER
                pw.Container(
                  color: cTopBanner,
                  padding: pw.EdgeInsets.symmetric(
                    vertical: isFirstPage ? 14 : 9,
                    horizontal: 20,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImg != null) ...[
                        pw.Container(
                          width: isFirstPage ? 36 : 28,
                          height: isFirstPage ? 30 : 24,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            cleanShopName.toUpperCase(),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: isFirstPage ? 16 : 13,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            isFirstPage
                                ? reportTitle
                                : (useHindi
                                    ? '$reportTitle  |  पृष्ठ ${pIdx + 1} / $totalPages'
                                    : '$reportTitle  |  PAGE ${pIdx + 1} OF $totalPages'),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8.5,
                              color: cHeaderSub,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. INNER CONTENT WRAPPER
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Centered Store Meta (Only on First Page)
                      if (isFirstPage) ...[
                        if (cleanAddress != null && cleanAddress.isNotEmpty) ...[
                          pw.Text(
                            cleanAddress,
                            style: const pw.TextStyle(fontSize: 8.5, color: cMuted),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 2),
                        ],
                        if (cleanPhone != null && cleanPhone.isNotEmpty) ...[
                          pw.Text(
                            useHindi ? 'संपर्क: $cleanPhone' : 'Phone: $cleanPhone',
                            style: const pw.TextStyle(fontSize: 8.5, color: cMuted),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 2),
                        ],
                        pw.Text(
                          useHindi
                              ? 'अवधि: ${is10Days ? "पिछले 10 दिन" : "आज"}  |  तैयार: $dateStr'
                              : 'Report Window: ${is10Days ? "Past 10 Days" : "Today"}  |  Generated: $dateStr',
                          style: const pw.TextStyle(fontSize: 8.5, color: cMuted),
                          textAlign: pw.TextAlign.center,
                        ),

                        pw.SizedBox(height: 10),

                        // 3. ROUNDED SUMMARY CALLOUT PILLS (Mandi Style)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                          decoration: pw.BoxDecoration(
                            color: cCardBg,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: cCardBorder, width: 0.8),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              useHindi
                                  ? 'कुल सकल बिक्री: ₹${totalRevenue.toStringAsFixed(2)}  |  $totalUnitsSold सामग्री  |  $totalBills बिल'
                                  : 'TOTAL GROSS SALES: Rs. ${totalRevenue.toStringAsFixed(2)}  |  $totalUnitsSold UNITS SOLD  |  $totalBills BILLS',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9.5,
                                color: cBlueAccent,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 14),
                          decoration: pw.BoxDecoration(
                            color: cCardBg,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: cCardBorder, width: 0.8),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              useHindi
                                  ? 'भुगतान विवरण:  नकद: ₹${cashRevenue.toStringAsFixed(0)}  |  यूपीआई: ₹${upiRevenue.toStringAsFixed(0)}  |  खाता (उधार): ₹${khataRevenue.toStringAsFixed(0)}'
                                  : 'PAYMENT BREAKDOWN:  Cash: Rs. ${cashRevenue.toStringAsFixed(0)}  |  UPI: Rs. ${upiRevenue.toStringAsFixed(0)}  |  Credit: Rs. ${khataRevenue.toStringAsFixed(0)}',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: cDark,
                              ),
                            ),
                          ),
                        ),

                        pw.SizedBox(height: 10),
                      ],

                      // 4. SALES ITEMS TABLE
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: cBorder, width: 0.6),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FixedColumnWidth(26), // #
                            1: const pw.FlexColumnWidth(5.0), // Item Description & SKU
                            2: const pw.FlexColumnWidth(1.6), // Qty
                            3: const pw.FlexColumnWidth(2.0), // Rate
                            4: const pw.FlexColumnWidth(2.2), // Total
                            5: const pw.FlexColumnWidth(2.8), // Pay Mode & Time
                          },
                          children: [
                            // Table Header Row (Deep Indigo)
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(color: cTblHeader),
                              children: [
                                _tableCell(useHindi ? 'क्र.' : '#', isHeader: true, align: pw.TextAlign.center),
                                _tableCell(useHindi ? 'सामग्री विवरण एवं SKU' : 'Item Description & SKU', isHeader: true),
                                _tableCell(useHindi ? 'मात्रा' : 'Qty', isHeader: true, align: pw.TextAlign.center),
                                _tableCell(useHindi ? 'दर' : 'Rate', isHeader: true, align: pw.TextAlign.right),
                                _tableCell(useHindi ? 'कुल योग' : 'Total', isHeader: true, align: pw.TextAlign.right),
                                _tableCell(useHindi ? 'भुगतान / समय' : 'Pay / Time', isHeader: true, align: pw.TextAlign.center),
                              ],
                            ),

                            // Empty Fallback
                            if (pageItems.isEmpty)
                              pw.TableRow(
                                children: [
                                  _tableCell('-', align: pw.TextAlign.center),
                                  _tableCell(
                                    useHindi
                                        ? 'इस अवधि के लिए कोई बिक्री दर्ज नहीं है।'
                                        : 'No sold items recorded for this reporting period.',
                                    isBold: true,
                                  ),
                                  _tableCell('-'),
                                  _tableCell('-'),
                                  _tableCell('-'),
                                  _tableCell('-'),
                                ],
                              )
                            else
                              ...List.generate(pageItems.length, (index) {
                                final item = pageItems[index];
                                final currentNumber = ++globalIndex;
                                final isAlt = index % 2 == 1;

                                final cleanName = item.productName.trim();
                                String itemTitle = cleanName.isNotEmpty ? cleanName : (useHindi ? 'उत्पाद' : 'Product');
                                if (item.productSku.isNotEmpty &&
                                    item.productSku.toLowerCase() != cleanName.toLowerCase()) {
                                  itemTitle = '$cleanName (${item.productSku})';
                                }

                                final rawPay = item.paymentMethod.isNotEmpty
                                    ? item.paymentMethod.toUpperCase()
                                    : 'PAID';
                                final payText = useHindi
                                    ? (rawPay == 'CASH'
                                        ? 'नकद'
                                        : (rawPay == 'UPI'
                                            ? 'यूपीआई'
                                            : (rawPay == 'KHATA'
                                                ? 'खाता'
                                                : rawPay)))
                                    : rawPay;
                                final timeText = DateFormat('dd/MM HH:mm').format(item.soldAt);

                                return pw.TableRow(
                                  decoration: pw.BoxDecoration(
                                    color: isAlt ? cAltRow : PdfColors.white,
                                  ),
                                  children: [
                                    _tableCell('$currentNumber', align: pw.TextAlign.center),
                                    _tableCell(itemTitle, isBold: true),
                                    _tableCell(
                                      '${item.quantity}',
                                      align: pw.TextAlign.center,
                                      isBold: true,
                                      color: cBlueAccent,
                                    ),
                                    _tableCell(
                                      'Rs. ${item.unitPrice.toStringAsFixed(1)}',
                                      align: pw.TextAlign.right,
                                    ),
                                    _tableCell(
                                      'Rs. ${item.totalPrice.toStringAsFixed(1)}',
                                      align: pw.TextAlign.right,
                                      isBold: true,
                                    ),
                                    _tableCell(
                                      '$payText $timeText',
                                      align: pw.TextAlign.center,
                                    ),
                                  ],
                                );
                              }),

                            // Table Summary Row on Last Page
                            if (isLastPage && items.isNotEmpty)
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: cCardBg),
                                children: [
                                  _tableCell('', align: pw.TextAlign.center),
                                  _tableCell(useHindi ? 'कुल योग' : 'TOTAL SUMMARY', isBold: true),
                                  _tableCell(
                                    '$totalUnitsSold',
                                    align: pw.TextAlign.center,
                                    isBold: true,
                                    color: cBlueAccent,
                                  ),
                                  _tableCell('-', align: pw.TextAlign.right),
                                  _tableCell(
                                    'Rs. ${totalRevenue.toStringAsFixed(2)}',
                                    align: pw.TextAlign.right,
                                    isBold: true,
                                    color: cBlueAccent,
                                  ),
                                  _tableCell(
                                    useHindi ? '${items.length} प्रविष्टियां' : '${items.length} Entries',
                                    align: pw.TextAlign.center,
                                    isBold: true,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // 5. FOOTER SECTION
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: pw.Column(
                    children: [
                      pw.Divider(thickness: 0.6, color: cBorder),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        useHindi
                            ? 'शॉपसाइलो रिटेल • बिक्री रजिस्टर • पृष्ठ ${pIdx + 1} / $totalPages'
                            : 'Notes: Verified point-of-sale transaction journal. Generated automatically by ShopSilo Retail OS. Page ${pIdx + 1} of $totalPages.',
                        style: const pw.TextStyle(fontSize: 7.8, color: cMuted),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    if (_salesPdfByteCache.length >= 20) {
      _salesPdfByteCache.remove(_salesPdfByteCache.keys.first);
    }
    _salesPdfByteCache[cacheKey] = bytes;
    return bytes;
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : (color ?? const PdfColor.fromInt(0xFF0F172A)),
          fontSize: isHeader ? 8.5 : 8.0,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Directly sends the generated A4 sales journal to the system print / PDF preview dialog.
  static Future<void> printSalesSheet({
    required String shopName,
    required List<SoldProductTimelineItem> items,
    required double totalRevenue,
    required int totalBills,
    required double cashRevenue,
    required double upiRevenue,
    required double khataRevenue,
    int windowDays = 1,
    String? shopAddress,
    String? shopPhone,
    bool? isHindi,
  }) async {
    final pdfBytes = await generateSalesPdf(
      shopName: shopName,
      items: items,
      totalRevenue: totalRevenue,
      totalBills: totalBills,
      cashRevenue: cashRevenue,
      upiRevenue: upiRevenue,
      khataRevenue: khataRevenue,
      windowDays: windowDays,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      isHindi: isHindi,
    );

    final safeName = windowDays > 1
        ? '${shopName.replaceAll(" ", "_")}_10Day_Sales_Journal.pdf'
        : '${shopName.replaceAll(" ", "_")}_Today_Sales_Report.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: safeName,
    );
  }

  /// Shares the generated sales sheet PDF via WhatsApp, Email, or File Share.
  static Future<void> shareSalesSheet({
    required String shopName,
    required List<SoldProductTimelineItem> items,
    required double totalRevenue,
    required int totalBills,
    required double cashRevenue,
    required double upiRevenue,
    required double khataRevenue,
    int windowDays = 1,
    String? shopAddress,
    String? shopPhone,
    bool? isHindi,
  }) async {
    final pdfBytes = await generateSalesPdf(
      shopName: shopName,
      items: items,
      totalRevenue: totalRevenue,
      totalBills: totalBills,
      cashRevenue: cashRevenue,
      upiRevenue: upiRevenue,
      khataRevenue: khataRevenue,
      windowDays: windowDays,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      isHindi: isHindi,
    );

    final safeShop = shopName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').trim();
    final cleanBase = safeShop.isNotEmpty && safeShop != '_' ? safeShop : 'ShopSilo';
    final safeName = windowDays > 1
        ? '${cleanBase}_10Day_Sales_Journal.pdf'
        : '${cleanBase}_Today_Sales_Report.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: safeName,
    );
  }
}
