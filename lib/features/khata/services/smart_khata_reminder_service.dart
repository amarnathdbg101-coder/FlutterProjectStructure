import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../models/khata_model.dart';

/// Service for generating rich, transparent Khata payment reminders and WhatsApp statements
class SmartKhataReminderService {
  /// Generate a valid, standard UPI deep-link URI (compatible with GPay, PhonePe, Paytm, BHIM)
  static String generateUpiPayUri({
    required String upiId,
    required String payeeName,
    required double amount,
  }) {
    final cleanUpi = upiId.trim();
    final cleanName = payeeName.trim().replaceAll('&', 'and');
    final formattedAmount = amount > 0 ? amount.toStringAsFixed(2) : '0.00';
    final encodedName = Uri.encodeComponent(cleanName);
    return 'upi://pay?pa=$cleanUpi&pn=$encodedName&am=$formattedAmount&cu=INR';
  }

  /// Format a courteous, transparent payment reminder and ledger statement
  static String formatReminderMessage({
    required KhataCustomerModel customer,
    required String shopName,
    String? shopUpiId,
    List<KhataTransactionModel>? recentTransactions,
    bool includeRecentHistory = true,
    bool includeUpiLink = true,
    required bool isHindi,
  }) {
    final cleanShopName = shopName.trim().isNotEmpty ? shopName.trim() : 'ShopSilo Partner Store';
    final cleanCustName = customer.name.trim().isNotEmpty ? customer.name.trim() : 'Customer';
    final amount = customer.balance;
    final amountStr = amount.abs().toStringAsFixed(0);

    // If customer has no dues
    if (amount <= 0) {
      if (isHindi) {
        return 'नमस्ते $cleanCustName जी,\n\n'
            '$cleanShopName में आपका खाता पूर्णतः चुकता है। कोई बकाया राशि नहीं है।\n\n'
            'धन्यवाद!\n$cleanShopName';
      } else {
        return 'Dear $cleanCustName,\n\n'
            'Your account at $cleanShopName is fully settled with zero pending dues.\n\n'
            'Thank you!\n$cleanShopName';
      }
    }

    final buffer = StringBuffer();

    // 1. Greeting & Shop Header
    if (isHindi) {
      buffer.writeln('नमस्ते $cleanCustName जी,');
      buffer.writeln();
      buffer.writeln('📖 *$cleanShopName* से आपके खाते का विवरण:');
      buffer.writeln('💰 *कुल बकाया राशि: ₹$amountStr*');
    } else {
      buffer.writeln('Dear $cleanCustName,');
      buffer.writeln();
      buffer.writeln('📖 Account statement from *$cleanShopName*:');
      buffer.writeln('💰 *Total Pending Dues: ₹$amountStr*');
    }

    // 2. Promise Date / Overdue Status (if applicable)
    if (customer.promiseDate != null) {
      final pDate = customer.promiseDate!;
      final dateStr = '${pDate.day.toString().padLeft(2, '0')}/${pDate.month.toString().padLeft(2, '0')}/${pDate.year}';
      if (isHindi) {
        buffer.writeln('📅 भुगतान वादा तारीख: $dateStr');
      } else {
        buffer.writeln('📅 Promised Payment Date: $dateStr');
      }
    }
    if (customer.overdueDays > 0) {
      if (isHindi) {
        buffer.writeln('⚠️ विलंबित अवधि: ${customer.overdueDays} दिन');
      } else {
        buffer.writeln('⚠️ Overdue by: ${customer.overdueDays} days');
      }
    }

    // 3. Recent Transactions Activity (Last 3 entries for transparency)
    if (includeRecentHistory && recentTransactions != null && recentTransactions.isNotEmpty) {
      final slice = recentTransactions.take(3).toList();
      buffer.writeln();
      if (isHindi) {
        buffer.writeln('📋 *हालिया लेन-देन विवरण (Recent Activity):*');
      } else {
        buffer.writeln('📋 *Recent Account Activity:*');
      }

      for (final tx in slice) {
        final txDate = '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}';
        final txType = tx.isCredit
            ? (isHindi ? 'उधार लिया (-)' : 'Credit Given (-)')
            : (isHindi ? 'जमा किया (+)' : 'Payment Received (+)');
        final txAmt = '₹${tx.amount.toStringAsFixed(0)}';

        final extra = <String>[];
        if (tx.billNumber != null && tx.billNumber!.trim().isNotEmpty) {
          extra.add('#${tx.billNumber!.trim()}');
        }
        if (tx.notes.trim().isNotEmpty) {
          extra.add(tx.notes.trim());
        }

        final noteSuffix = extra.isNotEmpty ? ' (${extra.join(", ")})' : '';
        buffer.writeln('• $txDate: $txType $txAmt$noteSuffix');
      }
    }

    // 4. Instant 1-Tap UPI Payment Link
    final hasUpi = shopUpiId != null && shopUpiId.trim().isNotEmpty;
    if (includeUpiLink && hasUpi) {
      final upiUri = generateUpiPayUri(
        upiId: shopUpiId,
        payeeName: cleanShopName,
        amount: amount,
      );
      buffer.writeln();
      if (isHindi) {
        buffer.writeln('📱 *1-टैप ऑनलाइन भुगतान (PhonePe / GPay / Paytm):*');
        buffer.writeln(upiUri);
        buffer.writeln('UPI ID: ${shopUpiId.trim()}');
      } else {
        buffer.writeln('📱 *1-Tap Online Payment (PhonePe / GPay / Paytm):*');
        buffer.writeln(upiUri);
        buffer.writeln('UPI ID: ${shopUpiId.trim()}');
      }
    }

    // 5. Polite Sign-off
    buffer.writeln();
    if (isHindi) {
      buffer.writeln('कृपया यथाशीघ्र शेष राशि का भुगतान करें।');
      buffer.writeln('धन्यवाद!\n*$cleanShopName*');
    } else {
      buffer.writeln('Kindly clear the pending balance at your earliest convenience.');
      buffer.writeln('Thank you!\n*$cleanShopName*');
    }

    return buffer.toString().trim();
  }

  /// Open WhatsApp with pre-filled message, with graceful clipboard fallback
  static Future<bool> openWhatsApp({
    required BuildContext context,
    required String mobile,
    required String message,
  }) async {
    final cleanPhone = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('khata_no_phone'))),
        );
      }
      return false;
    }

    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final urlString = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // Fallback: Copy to clipboard and notify
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('khata_whatsapp_not_installed')} - ${context.tr('khata_reminder_toast_copied')}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  /// Copy reminder statement text to clipboard
  static Future<void> copyMessageToClipboard({
    required BuildContext context,
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('khata_reminder_toast_copied')),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Copy UPI Pay Link to clipboard
  static Future<void> copyUpiLinkToClipboard({
    required BuildContext context,
    required String upiId,
    required String shopName,
    required double amount,
  }) async {
    final upiUri = generateUpiPayUri(
      upiId: upiId,
      payeeName: shopName,
      amount: amount,
    );
    await Clipboard.setData(ClipboardData(text: upiUri));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('khata_reminder_upi_copied')),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
