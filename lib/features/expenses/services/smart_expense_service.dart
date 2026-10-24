import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../models/expense_model.dart';

class DailyProfitSummary {
  final double todaySales;
  final double todayExpenses;
  final double netProfit;
  final double netProfitMarginPct;

  const DailyProfitSummary({
    required this.todaySales,
    required this.todayExpenses,
    required this.netProfit,
    required this.netProfitMarginPct,
  });

  bool get isProfitable => netProfit > 0;
  bool get isLoss => netProfit < 0;
}

/// Service managing instant expense presets, quick amount chips,
/// daily net profit calculation, and partner expense reports.
class SmartExpenseService {
  /// Quick petty cash note denominations for 1-tap expense entry
  static const List<double> quickAmountPresets = [20, 50, 100, 200, 500, 1000, 2000];

  /// Standard retail store expense categories with icons and defaults
  static const List<Map<String, dynamic>> categories = [
    {
      'key': 'chai_nashta',
      'icon': Icons.coffee_rounded,
      'translationKey': 'exp_cat_tea',
      'defaultAmount': 20.0,
      'defaultNotes': 'Staff Tea & Snacks',
    },
    {
      'key': 'transport',
      'icon': Icons.local_shipping_outlined,
      'translationKey': 'exp_cat_transport',
      'defaultAmount': 100.0,
      'defaultNotes': 'Goods Loading & Auto Fare',
    },
    {
      'key': 'electricity',
      'icon': Icons.bolt_rounded,
      'translationKey': 'exp_cat_electricity',
      'defaultAmount': 1000.0,
      'defaultNotes': 'Electricity Bill',
    },
    {
      'key': 'rent',
      'icon': Icons.storefront_rounded,
      'translationKey': 'exp_cat_rent',
      'defaultAmount': 5000.0,
      'defaultNotes': 'Monthly Shop Rent',
    },
    {
      'key': 'salary',
      'icon': Icons.badge_outlined,
      'translationKey': 'exp_cat_salary',
      'defaultAmount': 500.0,
      'defaultNotes': 'Staff Salary Advance',
    },
    {
      'key': 'packaging',
      'icon': Icons.shopping_bag_outlined,
      'translationKey': 'exp_cat_packaging',
      'defaultAmount': 500.0,
      'defaultNotes': 'Carry Bags & Packaging',
    },
    {
      'key': 'maintenance',
      'icon': Icons.cleaning_services_rounded,
      'translationKey': 'exp_cat_maintenance',
      'defaultAmount': 200.0,
      'defaultNotes': 'Store Repair & Cleaning',
    },
    {
      'key': 'other',
      'icon': Icons.receipt_long_rounded,
      'translationKey': 'exp_cat_other',
      'defaultAmount': 100.0,
      'defaultNotes': 'General Miscellaneous',
    },
  ];

  /// Computes today's net profit from sales and recorded expenses
  static DailyProfitSummary calculateDailyProfit({
    required double todaySales,
    required double todayExpenses,
  }) {
    final net = todaySales - todayExpenses;
    final margin = todaySales > 0 ? (net / todaySales) * 100 : 0.0;
    return DailyProfitSummary(
      todaySales: todaySales,
      todayExpenses: todayExpenses,
      netProfit: net,
      netProfitMarginPct: margin,
    );
  }

  /// Format an executive daily expense & profit statement for WhatsApp sharing
  static String formatDailyExpenseSummary({
    required String shopName,
    required double todaySales,
    required double todayExpenses,
    required List<ExpenseModel> todayExpensesList,
    required bool isHindi,
  }) {
    final cleanShop = shopName.trim().isNotEmpty ? shopName.trim() : 'ShopSilo Partner Store';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final netProfit = todaySales - todayExpenses;

    final buffer = StringBuffer();

    if (isHindi) {
      buffer.writeln('📊 *दैनिक खर्च एवं लाभ विवरण (Daily Expense & Profit)*');
      buffer.writeln('दुकान: *$cleanShop*');
      buffer.writeln('दिनांक: $dateStr');
      buffer.writeln('----------------------------------');
      buffer.writeln('💰 आज की कुल बिक्री: *₹${todaySales.toStringAsFixed(0)}*');
      buffer.writeln('📉 आज के कुल खर्चे: *₹${todayExpenses.toStringAsFixed(0)}*');
      buffer.writeln('💵 शुद्ध नकद बचत (Net In-Hand): *₹${netProfit.toStringAsFixed(0)}*');
      buffer.writeln('----------------------------------');
      buffer.writeln();

      if (todayExpensesList.isNotEmpty) {
        buffer.writeln('*आज के दर्ज खर्च:*');
        for (int i = 0; i < todayExpensesList.length; i++) {
          final exp = todayExpensesList[i];
          final notesStr = exp.notes.isNotEmpty ? ' (${exp.notes})' : '';
          buffer.writeln('${i + 1}. ₹${exp.amount.toStringAsFixed(0)} - ${exp.category.toUpperCase()}$notesStr');
        }
        buffer.writeln();
      }

      buffer.writeln('दैनिक रिकॉर्ड ShopSilo मर्चेंट ऐप द्वारा जनरेट किया गया।');
    } else {
      buffer.writeln('📊 *DAILY EXPENSE & NET PROFIT STATEMENT*');
      buffer.writeln('Store: *$cleanShop*');
      buffer.writeln('Date: $dateStr');
      buffer.writeln('----------------------------------');
      buffer.writeln('💰 Total Sales Today: *₹${todaySales.toStringAsFixed(0)}*');
      buffer.writeln('📉 Total Expenses Today: *₹${todayExpenses.toStringAsFixed(0)}*');
      buffer.writeln('💵 Net In-Hand Balance: *₹${netProfit.toStringAsFixed(0)}*');
      buffer.writeln('----------------------------------');
      buffer.writeln();

      if (todayExpensesList.isNotEmpty) {
        buffer.writeln('*Itemized Expenses Today:*');
        for (int i = 0; i < todayExpensesList.length; i++) {
          final exp = todayExpensesList[i];
          final notesStr = exp.notes.isNotEmpty ? ' (${exp.notes})' : '';
          buffer.writeln('${i + 1}. ₹${exp.amount.toStringAsFixed(0)} - ${exp.category.toUpperCase()}$notesStr');
        }
        buffer.writeln();
      }

      buffer.writeln('Report generated via ShopSilo Merchant Partner App.');
    }

    return buffer.toString().trim();
  }

  /// Launch WhatsApp with daily statement or fallback to clipboard
  static Future<void> shareExpenseSummaryOnWhatsApp({
    required BuildContext context,
    required String message,
    String? targetPhone,
  }) async {
    final cleanPhone = targetPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final formattedPhone = cleanPhone.isNotEmpty
        ? (cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone)
        : '';

    final urlString = formattedPhone.isNotEmpty
        ? 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(message)}';

    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isHindi
                ? 'दैनिक विवरण क्लिपबोर्ड पर कॉपी हो गया!'
                : 'Daily statement copied to clipboard!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}
