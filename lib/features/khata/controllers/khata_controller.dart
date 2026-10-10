import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../models/khata_model.dart';
import '../repositories/khata_repository.dart';

class KhataController extends BaseController {
  final KhataRepository _repo = KhataRepository();

  List<KhataCustomerModel> _customers = [];
  List<KhataCustomerModel> get customers => _customers;

  KhataSummaryModel? _summary;
  KhataSummaryModel? get summary => _summary;

  KhataAgingModel? _aging;
  KhataAgingModel? get aging => _aging;

  List<KhataTransactionModel> _currentCustomerStatement = [];
  List<KhataTransactionModel> get currentCustomerStatement => _currentCustomerStatement;

  bool _isStatementLoading = false;
  bool get isStatementLoading => _isStatementLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _activeFilter = 'all'; // 'all', 'dues', 'overdue', 'settled'
  String get activeFilter => _activeFilter;

  int get totalCount => _customers.length;

  int get debtorsCount => _summary?.totalDebtors ?? _customers.where((c) => c.balance > 0).length;

  int get overdueCount =>
      _summary?.overdueAccounts ?? _customers.where((c) => c.isOverdue && c.balance > 0).length;

  double get totalMarketDebt =>
      _summary?.totalReceivables ?? _customers.where((c) => c.balance > 0).fold(0.0, (sum, c) => sum + c.balance);

  List<KhataCustomerModel> get filteredCustomers {
    return _customers.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.mobile.contains(_searchQuery);

      if (!matchesSearch) return false;

      switch (_activeFilter) {
        case 'dues':
          return c.balance > 0;
        case 'overdue':
          return c.isOverdue && c.balance > 0;
        case 'settled':
          return c.balance <= 0;
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  KhataController() {
    _hydrateFromLocalCache();
  }

  void _hydrateFromLocalCache() {
    final cachedCustomers = LocalCacheService.getKhataCustomers();
    if (cachedCustomers.isNotEmpty) {
      _customers = cachedCustomers;
    }
    final cachedSummary = LocalCacheService.getKhataSummary();
    if (cachedSummary != null) {
      _summary = cachedSummary;
    }
    if (_customers.isNotEmpty || _summary != null) {
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setActiveFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> loadCustomers({bool silent = false}) async {
    if (!silent && _customers.isEmpty) {
      setLoading(true);
    }
    clearError();

    try {
      final response = await _repo.getCustomers();
      if (!silent) setLoading(false);

      if (response.success && response.data != null) {
        _customers = response.data!;
        await LocalCacheService.saveKhataCustomers(_customers);
        notifyListeners();
      } else {
        if (!silent && _customers.isEmpty) {
          setError(response.error ?? 'Khata record load nahi ho sake');
        }
      }
    } catch (_) {
      if (!silent) setLoading(false);
    }

    // Concurrently update summary and aging metrics
    _loadSummaryAndAging();
  }

  Future<void> _loadSummaryAndAging() async {
    try {
      final summaryRes = await _repo.getSummary();
      if (summaryRes.success && summaryRes.data != null) {
        _summary = KhataSummaryModel.fromJson(summaryRes.data!);
        await LocalCacheService.saveKhataSummary(_summary!);
      }

      final agingRes = await _repo.getAgingReport();
      if (agingRes.success && agingRes.data != null) {
        _aging = KhataAgingModel.fromJson(agingRes.data!);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadStatement(String mobile) async {
    _isStatementLoading = true;
    _currentCustomerStatement = [];
    notifyListeners();

    final response = await _repo.getCustomerStatement(mobile);
    _isStatementLoading = false;

    if (response.success && response.data != null) {
      _currentCustomerStatement = response.data!;
    } else {
      setError(response.error ?? 'Passbook statement load nahi ho saka');
    }
    notifyListeners();
  }

  Future<bool> addCredit({
    required String customerName,
    required String mobile,
    required double amount,
    String notes = '',
    String billNumber = '',
  }) async {
    clearError();

    final response = await _repo.recordCredit(
      customerName: customerName,
      mobile: mobile,
      amount: amount,
      notes: notes,
      billNumber: billNumber,
    );

    if (response.success) {
      await loadCustomers(silent: true);
      return true;
    } else {
      setError(response.error ?? 'Failed to record credit entry');
      return false;
    }
  }

  Future<bool> addPayment({
    required String mobile,
    required String customerName,
    required double amount,
    String paymentMode = 'cash',
    String notes = '',
  }) async {
    clearError();

    final response = await _repo.recordPayment(
      mobile: mobile,
      customerName: customerName,
      amount: amount,
      paymentMode: paymentMode,
      notes: notes,
    );

    if (response.success) {
      await loadCustomers(silent: true);
      return true;
    } else {
      setError(response.error ?? 'Failed to record payment');
      return false;
    }
  }

  // --- Credit Limit Management ---
  Future<bool> updateCreditLimit(String mobile, double creditLimit) async {
    clearError();
    final response = await _repo.updateCreditLimit(mobile, creditLimit);
    if (response.success) {
      // Optimistically update locally
      final idx = _customers.indexWhere((c) => c.mobile == mobile);
      if (idx >= 0) {
        final old = _customers[idx];
        _customers[idx] = KhataCustomerModel(
          id: old.id,
          name: old.name,
          mobile: old.mobile,
          balance: old.balance,
          creditLimit: creditLimit,
          lastTransactionAt: old.lastTransactionAt,
          trustScore: old.trustScore,
          promiseDate: old.promiseDate,
          overdueDays: old.overdueDays,
        );
        LocalCacheService.saveKhataCustomers(_customers);
        notifyListeners();
      }
      return true;
    } else {
      setError(response.error ?? 'Failed to update credit limit');
      return false;
    }
  }

  // --- Promise-to-Pay Date ---
  Future<bool> setPromiseDate(String khataId, DateTime promiseDate, String mobile) async {
    clearError();
    final response = await _repo.setPromiseToPay(khataId, promiseDate.toIso8601String());
    if (response.success) {
      final idx = _customers.indexWhere((c) => c.mobile == mobile || c.id.toString() == khataId);
      if (idx >= 0) {
        final old = _customers[idx];
        _customers[idx] = KhataCustomerModel(
          id: old.id,
          name: old.name,
          mobile: old.mobile,
          balance: old.balance,
          creditLimit: old.creditLimit,
          lastTransactionAt: old.lastTransactionAt,
          trustScore: old.trustScore,
          promiseDate: promiseDate,
          overdueDays: 0,
        );
        LocalCacheService.saveKhataCustomers(_customers);
        notifyListeners();
      }
      return true;
    } else {
      setError(response.error ?? 'Failed to set payment promise date');
      return false;
    }
  }

  // --- Reverse Transaction ---
  Future<bool> reverseTransaction(
    String khataId,
    String txId,
    String customerMobile, {
    String reason = '',
  }) async {
    clearError();
    final response = await _repo.reverseTransaction(khataId, txId, reason: reason);
    if (response.success) {
      await loadStatement(customerMobile);
      await loadCustomers(silent: true);
      return true;
    } else {
      setError(response.error ?? 'Failed to reverse transaction');
      return false;
    }
  }

  // --- 1-Tap WhatsApp Reminder ---
  Future<void> sendWhatsAppReminder(BuildContext context, KhataCustomerModel customer) async {
    final cleanPhone = customer.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('khata_no_phone'))),
      );
      return;
    }

    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final shop = LocalCacheService.getShop();
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
    final amountStr = customer.balance.toStringAsFixed(0);

    // Fetch custom backend reminder text if available
    String reminderText = '';
    try {
      final res = await _repo.getPaymentReminder(customer.mobile);
      if (res.success && res.data != null) {
        reminderText = res.data!['message']?.toString() ??
            res.data!['reminder_text']?.toString() ??
            '';
      }
    } catch (_) {}

    if (reminderText.isEmpty) {
      // Courteous bilingual formatted message
      final isHindi = TokenStorage.getLanguage() == 'hi';
      if (isHindi) {
        reminderText =
            'नमस्ते ${customer.name} जी,\n\n'
            '$shopName से आपका कुल बकाया ₹$amountStr शेष है।\n'
            'कृपया इसे यथाशीघ्र चुकाने की कृपा करें।\n\n'
            'धन्यवाद!\n$shopName';
      } else {
        reminderText =
            'Dear ${customer.name},\n\n'
            'This is a polite reminder from $shopName. '
            'Your pending credit balance is ₹$amountStr. '
            'Kindly clear the dues at your earliest convenience.\n\n'
            'Thank you!\n$shopName';
      }
    }

    final urlString = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(reminderText)}';
    final uri = Uri.parse(urlString);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('khata_whatsapp_not_installed'))),
        );
      }
    }
  }

  // --- Download / Open Statement PDF ---
  Future<void> openStatementPdf(BuildContext context, String mobile, {KhataCustomerModel? customer}) async {
    clearError();
    final res = await _repo.getStatementPdfUrl(mobile);
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      final uri = Uri.parse(res.data!);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    // Clean HTML Print-Ready Passbook Statement Engine
    final shop = LocalCacheService.getShop();
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
    final custName = customer?.name ?? 'Customer';
    final balance = customer?.balance ?? 0.0;
    final dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    String htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Khata Passbook Statement - $custName</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; color: #0f172a; }
        .header { text-align: center; border-bottom: 2px solid #dc2626; padding-bottom: 12px; margin-bottom: 20px; }
        .header h1 { margin: 0; color: #dc2626; font-size: 22px; }
        .header p { margin: 4px 0 0 0; color: #64748b; font-size: 13px; }
        .summary-box { background: #fef2f2; border: 1px solid #fca5a5; padding: 14px; border-radius: 8px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border: 1px solid #cbd5e1; padding: 10px; text-align: left; font-size: 13px; }
        th { background-color: #f1f5f9; font-weight: bold; }
        .credit { color: #dc2626; font-weight: bold; }
        .payment { color: #16a34a; font-weight: bold; }
        @media print { .no-print { display: none; } }
      </style>
    </head>
    <body>
      <div class="no-print" style="margin-bottom: 16px;">
        <button onclick="window.print()" style="background:#dc2626;color:white;border:none;padding:10px 18px;border-radius:6px;font-weight:bold;cursor:pointer;">🖨️ Print / Save Statement PDF</button>
      </div>
      <div class="header">
        <h1>📖 $shopName - Customer Khata Passbook Statement</h1>
        <p>Date: $dateStr • Customer: $custName ($mobile)</p>
      </div>
      <div class="summary-box">
        <strong>TOTAL PENDING CREDIT BALANCE: ₹${balance.abs().toStringAsFixed(0)}</strong>
      </div>
      <table>
        <thead>
          <tr>
            <th>Date & Time</th>
            <th>Type</th>
            <th>Amount (₹)</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
    ''';

    for (final tx in _currentCustomerStatement) {
      final txDate = '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}';
      htmlContent += '''
        <tr>
          <td>$txDate</td>
          <td class="${tx.isCredit ? 'credit' : 'payment'}">${tx.isCredit ? 'UDHAR DIYA (-)' : 'JAMA KIYA (+)'}</td>
          <td class="${tx.isCredit ? 'credit' : 'payment'}">₹${tx.amount.toStringAsFixed(0)}</td>
          <td>${tx.notes.isNotEmpty ? tx.notes : '-'}</td>
        </tr>
      ''';
    }

    htmlContent += '''
        </tbody>
      </table>
    </body>
    </html>
    ''';

    final uri = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: Encoding.getByName('utf-8'));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // --- 1-Tap Broadcast WhatsApp Reminders to All Overdue Debtors ---
  Future<void> broadcastWhatsAppOverdueReminders(BuildContext context) async {
    final overdue = _customers.where((c) => c.balance > 0).toList();
    if (overdue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers with pending overdue balance found!')),
      );
      return;
    }

    final shop = LocalCacheService.getShop();
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';

    String text = '📢 *SHOP PAYMENT REMINDER BROADCAST*\n';
    text += 'Dukan: *$shopName*\n';
    text += 'Tareekh: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n';
    text += '------------------------------------\n\n';
    text += 'Total Overdue Debtors: *${overdue.length}*\n\n';

    for (int i = 0; i < overdue.length; i++) {
      final c = overdue[i];
      text += '${i + 1}. *${c.name}* (${c.mobile}) — Pending: *₹${c.balance.toStringAsFixed(0)}*\n';
    }

    text += '\nKripya samay par apna bakaya udhar bhuktan karein. Dhanyawad!';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
