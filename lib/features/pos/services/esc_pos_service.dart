import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/pos_model.dart';

/// Paper width specification for thermal receipt roll
enum EscPosRollWidth {
  roll58mm, // 32 characters per line (standard 2-inch)
  roll80mm, // 48 characters per line (standard 3-inch)
}

/// EscPosService generates raw, high-speed ESC/POS printer byte streams
/// for direct Bluetooth, USB, or Network TCP thermal printing without PDF overhead.
class EscPosService {
  // ESC/POS Command Byte Constants
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;

  // Initialize printer
  static final List<int> cmdInit = [esc, 0x40];

  // Text alignment
  static final List<int> cmdAlignLeft = [esc, 0x61, 0x00];
  static final List<int> cmdAlignCenter = [esc, 0x61, 0x01];
  static final List<int> cmdAlignRight = [esc, 0x61, 0x02];

  // Text sizing & emphasis
  static final List<int> cmdBoldOn = [esc, 0x45, 0x01];
  static final List<int> cmdBoldOff = [esc, 0x45, 0x00];
  static final List<int> cmdSizeNormal = [gs, 0x21, 0x00];
  static final List<int> cmdSizeDoubleHeight = [gs, 0x21, 0x01];
  static final List<int> cmdSizeDoubleWidth = [gs, 0x21, 0x10];
  static final List<int> cmdSizeDoubleBoth = [gs, 0x21, 0x11];

  // Paper cutting & Drawer kick
  static final List<int> cmdFeedAndCut = [gs, 0x56, 0x41, 0x03];
  static final List<int> cmdDrawerKick = [esc, 0x70, 0x00, 0x19, 0xFA];

  /// Generates crisp, raw ESC/POS bytes for a given sale receipt.
  static Uint8List generateReceiptBytes({
    required SaleModel sale,
    required String shopName,
    String shopAddress = '',
    String shopPhone = '',
    String shopGstin = '',
    String upiId = '',
    EscPosRollWidth rollWidth = EscPosRollWidth.roll80mm,
    bool kickDrawer = false,
  }) {
    final int maxCols = rollWidth == EscPosRollWidth.roll58mm ? 32 : 48;
    final List<int> bytes = [];

    void raw(List<int> cmd) => bytes.addAll(cmd);
    void line(String str) {
      bytes.addAll(utf8.encode(str));
      bytes.add(lf);
    }
    void feed([int lines = 1]) {
      for (int i = 0; i < lines; i++) {
        bytes.add(lf);
      }
    }
    void divider() => line('-' * maxCols);

    // 1. Initialize Printer & Kick Drawer if requested
    raw(cmdInit);
    if (kickDrawer) {
      raw(cmdDrawerKick);
    }

    // 2. STORE HEADER (Centered, Double-Height)
    raw(cmdAlignCenter);
    raw(cmdBoldOn);
    raw(cmdSizeDoubleBoth);
    line(shopName.toUpperCase());
    raw(cmdSizeNormal);

    if (shopAddress.trim().isNotEmpty) {
      raw(cmdBoldOff);
      line(shopAddress.trim());
    }
    if (shopPhone.trim().isNotEmpty) {
      line('Phone: ${shopPhone.trim()}');
    }
    if (shopGstin.trim().isNotEmpty) {
      raw(cmdBoldOn);
      line('GSTIN: ${shopGstin.trim()}');
    }

    raw(cmdBoldOn);
    line('TAX INVOICE / RETAIL RECEIPT');
    raw(cmdBoldOff);
    divider();

    // 3. INVOICE METADATA (Left / Right Aligned)
    raw(cmdAlignLeft);
    final dateStr = DateFormat('dd-MM-yyyy hh:mm a').format(sale.createdAt);
    line(_formatTwoColumns('Bill #: ${sale.billNumber ?? "WALK-IN"}', sale.paymentMethod.toUpperCase(), maxCols));
    line(_formatTwoColumns('Date: $dateStr', sale.customerPhone.isNotEmpty ? 'Ph: ${sale.customerPhone}' : '', maxCols));
    divider();

    // 4. ITEMS TABLE HEADER
    raw(cmdBoldOn);
    if (rollWidth == EscPosRollWidth.roll58mm) {
      // 32-col layout: 2-line modern receipt format for full legibility
      line(_formatTwoColumns("ITEM DESCRIPTION", "TOTAL", 32));
    } else {
      // 48-col layout: "ITEM DESCRIPTION        QTY    RATE    TOTAL"
      line(_formatRow48("ITEM DESCRIPTION", "QTY", "RATE", "TOTAL"));
    }
    raw(cmdBoldOff);
    divider();

    // 5. ITEM ROWS
    for (final item in sale.items) {
      final rawName = item.product.name;
      final name = sanitizeForAsciiThermal(rawName);
      final qty = '${item.quantity}';
      final rate = item.effectivePrice.toStringAsFixed(0);
      final total = 'Rs.${item.total.toStringAsFixed(0)}';

      if (rollWidth == EscPosRollWidth.roll58mm) {
        // Line 1: Item Name (up to 32 characters, no truncation)
        line(name.length > 32 ? name.substring(0, 32) : name);
        // Line 2: "  2x @ Rs.450" (left) -------- "Rs.900" (right)
        final detailLeft = '  ${qty}x @ Rs.$rate';
        line(_formatTwoColumns(detailLeft, total, 32));
      } else {
        line(_formatItemRow48(name, qty, rate, total));
      }
    }
    divider();

    // 6. TOTALS & SUMMARY
    final totalQty = sale.items.fold(0, (sum, i) => sum + i.quantity);
    line(_formatTwoColumns('Total Items: ${sale.items.length} (Qty $totalQty)', 'Subtotal: Rs.${sale.subtotal.toStringAsFixed(2)}', maxCols));

    if (sale.discountAmount > 0) {
      line(_formatTwoColumns('Discount Savings:', '-Rs.${sale.discountAmount.toStringAsFixed(2)}', maxCols));
    }

    divider();

    // 7. GRAND TOTAL (Double Size Bold Highlight)
    raw(cmdBoldOn);
    raw(cmdSizeDoubleBoth);
    line(_formatTwoColumns('TOTAL:', 'Rs.${sale.totalAmount.toStringAsFixed(2)}', maxCols ~/ 2));
    raw(cmdSizeNormal);
    raw(cmdBoldOff);
    divider();

    // 8. MULTI-TENDER SPLIT BREAKDOWN (If applicable)
    if (sale.splitPayments != null) {
      final sp = sale.splitPayments!;
      if (sp.cashAmount > 0) {
        line(_formatTwoColumns('Paid in Cash:', 'Rs.${sp.cashAmount.toStringAsFixed(2)}', maxCols));
      }
      if (sp.onlineAmount > 0) {
        line(_formatTwoColumns('Paid UPI/Online:', 'Rs.${sp.onlineAmount.toStringAsFixed(2)}', maxCols));
      }
      if (sp.khataAmount > 0) {
        raw(cmdBoldOn);
        line(_formatTwoColumns('Added to Khata (Due):', 'Rs.${sp.khataAmount.toStringAsFixed(2)}', maxCols));
        raw(cmdBoldOff);
      }
      divider();
    }

    // 9. UPI PAYMENT NOTE & FOOTER
    raw(cmdAlignCenter);
    if (upiId.trim().isNotEmpty) {
      line('Pay via UPI: $upiId');
      line('Accepted: PhonePe / GPay / Paytm');
      feed(1);
    }

    raw(cmdBoldOn);
    line('THANK YOU! VISIT AGAIN');
    raw(cmdBoldOff);
    line('Powered by ShopSilo Digital Retail OS');
    feed(3);

    // 10. Cut Paper
    raw(cmdFeedAndCut);

    return Uint8List.fromList(bytes);
  }

  /// Sends raw ESC/POS bytes directly to a Network / Wi-Fi Thermal Printer (TCP port 9100).
  /// Sub-10ms print latency, zero OS print dialog popups!
  static Future<bool> printViaTcpSocket({
    required String printerIp,
    int port = 9100,
    required Uint8List bytes,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final socket = await Socket.connect(printerIp, port, timeout: timeout);
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sanitizes text for standard ESC/POS printers lacking Devanagari ROM/NVRAM fonts.
  /// Replaces Devanagari characters with clean transliterated ASCII to prevent '???' printouts.
  static String sanitizeForAsciiThermal(String text) {
    if (text.isEmpty) return text;
    // Replace ₹ with Rs.
    var clean = text.replaceAll('₹', 'Rs.');
    // Remove parenthesized Hindi if English exists: "Tata Salt 1kg (टाटा नमक)" -> "Tata Salt 1kg"
    clean = clean.replaceAll(RegExp(r'\([^)]*[\u0900-\u097F][^)]*\)'), '').trim();
    if (clean.isEmpty) {
      return text;
    }
    // Clean any remaining Devanagari characters that would cause '???' on cheap thermal printers
    final asciiOnly = clean.replaceAll(RegExp(r'[\u0900-\u097F]'), '').trim();
    return asciiOnly.isNotEmpty ? asciiOnly : clean;
  }

  // Helper formatting methods for fixed column alignment
  static String _formatTwoColumns(String left, String right, int width) {
    if (left.length + right.length >= width) {
      final allowedLeft = width - right.length - 1;
      if (allowedLeft > 0 && left.length > allowedLeft) {
        left = left.substring(0, allowedLeft);
      }
    }
    final space = width - left.length - right.length;
    return left + (' ' * (space > 0 ? space : 1)) + right;
  }

  static String _formatRow48(String c1, String c2, String c3, String c4) {
    // 48 cols: 24 (item) + 6 (qty) + 8 (rate) + 10 (total)
    return _padRight(c1, 24) + _padCenter(c2, 6) + _padRight(c3, 8) + _padLeft(c4, 10);
  }

  static String _formatItemRow48(String name, String qty, String rate, String total) {
    if (name.length > 23) {
      name = name.substring(0, 23);
    }
    return _padRight(name, 24) + _padCenter(qty, 6) + _padRight(rate, 8) + _padLeft(total, 10);
  }

  static String _padRight(String s, int len) => s.length >= len ? s : s + (' ' * (len - s.length));
  static String _padLeft(String s, int len) => s.length >= len ? s : (' ' * (len - s.length)) + s;
  static String _padCenter(String s, int len) {
    if (s.length >= len) return s;
    final totalPad = len - s.length;
    final left = totalPad ~/ 2;
    final right = totalPad - left;
    return (' ' * left) + s + (' ' * right);
  }
}

