import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../models/khata_model.dart';
import '../repositories/khata_repository.dart';
import '../widgets/smart_payment_reminder_sheet.dart';
import '../../pos/models/pos_model.dart';

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

  int get debtorsCount {
    if (_customers.isNotEmpty) {
      return _customers.where((c) => c.balance > 0).length;
    }
    return _summary?.totalDebtors ?? 0;
  }

  int get overdueCount {
    if (_customers.isNotEmpty) {
      return _customers.where((c) => c.isOverdue && c.balance > 0).length;
    }
    return _summary?.overdueAccounts ?? 0;
  }

  double get totalMarketDebt {
    if (_customers.isNotEmpty) {
      return _customers.where((c) => c.balance > 0).fold(0.0, (sum, c) => sum + c.balance);
    }
    return _summary?.totalReceivables ?? 0.0;
  }

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

  StreamSubscription<AppCacheEvent>? _posSaleSub;
  StreamSubscription<AppCacheEvent>? _khataSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  KhataController() {
    _hydrateFromLocalCache();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _khataSub = AppEventBus().on(AppCacheEventType.khataMutated, (_) {
      loadCustomers(silent: true);
    });
    _posSaleSub = AppEventBus().on(AppCacheEventType.posSaleCompleted, (event) {
      if (event.payload is SaleModel) {
        final sale = event.payload as SaleModel;
        if (sale.paymentMethod == 'khata' || sale.paymentMethod == 'credit') {
          final cleanPhone = KhataRepository.normalizePhone(sale.customerPhone);
          final idx = _customers.indexWhere((c) => c.mobile == cleanPhone || c.mobile == sale.customerPhone);
          if (idx != -1) {
            final cur = _customers[idx];
            _customers[idx] = cur.copyWith(balance: cur.balance + sale.totalAmount);
          }
          if (_summary != null) {
            _summary = _summary!.copyWith(totalReceivables: _summary!.totalReceivables + sale.totalAmount);
            LocalCacheService.saveKhataSummary(_summary!);
          }
          LocalCacheService.saveKhataCustomers(_customers);
          notifyListeners();
        }
      }
      loadCustomers(silent: true);
    });
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _customers = [];
      _summary = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _khataSub?.cancel();
    _posSaleSub?.cancel();
    _logoutSub?.cancel();
    super.dispose();
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

  double getCustomerBalance(String mobile) {
    final clean = KhataRepository.normalizePhone(mobile);
    for (final c in _customers) {
      if (c.mobile == clean || c.mobile == mobile) {
        return c.balance;
      }
    }
    return 0.0;
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
          setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'खाता रिकॉर्ड लोड नहीं हो सके' : 'Failed to load khata records'));
        }
      }
    } catch (e) {
      if (!silent) {
        setLoading(false);
        if (_customers.isEmpty) setError(ApiClient.handleError(e));
      }
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
      // Sync customer balance with the latest transaction's balanceAfter if available
      if (_currentCustomerStatement.isNotEmpty) {
        final latestTx = _currentCustomerStatement.first;
        final cleanPhone = KhataRepository.normalizePhone(mobile);
        final idx = _customers.indexWhere((c) => c.mobile == cleanPhone || c.mobile == mobile);
        if (idx != -1 && latestTx.balanceAfter >= 0) {
          _customers[idx] = _customers[idx].copyWith(
            balance: latestTx.balanceAfter,
            lastTransactionAt: latestTx.createdAt,
          );
          LocalCacheService.saveKhataCustomers(_customers);
        }
      }
    } else {
      setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'पासबुक विवरण लोड नहीं हो सका' : 'Failed to load passbook statement'));
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
    final cleanPhone = KhataRepository.normalizePhone(mobile);
    final previousCustomers = List<KhataCustomerModel>.from(_customers);
    final previousSummary = _summary;

    // 1. Optimistic Update (0ms instant UI reflection)
    final existingIdx = _customers.indexWhere((c) => c.mobile == cleanPhone || c.mobile == mobile);
    if (existingIdx != -1) {
      final cur = _customers[existingIdx];
      _customers[existingIdx] = cur.copyWith(
        balance: cur.balance + amount,
        name: customerName.isNotEmpty ? customerName : cur.name,
        lastTransactionAt: DateTime.now(),
      );
    } else {
      _customers.insert(
        0,
        KhataCustomerModel(
          id: cleanPhone,
          name: customerName.trim().isNotEmpty ? customerName.trim() : 'Customer $cleanPhone',
          mobile: cleanPhone,
          balance: amount,
          lastTransactionAt: DateTime.now(),
        ),
      );
    }

    if (_summary != null) {
      _summary = _summary!.copyWith(
        totalReceivables: _summary!.totalReceivables + amount,
        totalDebtors: _customers.where((c) => c.balance > 0).length,
      );
      LocalCacheService.saveKhataSummary(_summary!);
    }
    await LocalCacheService.saveKhataCustomers(_customers);
    notifyListeners();

    // 2. Network Sync
    final response = await _repo.recordCredit(
      customerName: customerName,
      mobile: cleanPhone,
      amount: amount,
      notes: notes,
      billNumber: billNumber,
    );

    if (response.success) {
      await loadCustomers(silent: true);
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      // Revert optimistic update on failure
      _customers = previousCustomers;
      _summary = previousSummary;
      await LocalCacheService.saveKhataCustomers(_customers);
      if (_summary != null) await LocalCacheService.saveKhataSummary(_summary!);
      setError(response.error ?? 'Failed to record credit entry');
      notifyListeners();
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
    final cleanPhone = KhataRepository.normalizePhone(mobile);
    final previousCustomers = List<KhataCustomerModel>.from(_customers);
    final previousSummary = _summary;

    // 1. Optimistic Update (0ms instant UI reflection)
    final existingIdx = _customers.indexWhere((c) => c.mobile == cleanPhone || c.mobile == mobile);
    if (existingIdx != -1) {
      final cur = _customers[existingIdx];
      final newBal = cur.balance - amount;
      _customers[existingIdx] = cur.copyWith(
        balance: newBal < 0 ? 0.0 : newBal,
        name: customerName.isNotEmpty ? customerName : cur.name,
        lastTransactionAt: DateTime.now(),
      );
    }

    if (_summary != null) {
      final newTotal = (_summary!.totalReceivables - amount).clamp(0.0, double.infinity);
      _summary = _summary!.copyWith(
        totalReceivables: newTotal,
        totalDebtors: _customers.where((c) => c.balance > 0).length,
      );
      LocalCacheService.saveKhataSummary(_summary!);
    }
    await LocalCacheService.saveKhataCustomers(_customers);
    notifyListeners();

    // 2. Network Sync
    final response = await _repo.recordPayment(
      mobile: cleanPhone,
      customerName: customerName,
      amount: amount,
      paymentMode: paymentMode,
      notes: notes,
    );

    if (response.success) {
      await loadCustomers(silent: true);
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      // Revert optimistic update on failure
      _customers = previousCustomers;
      _summary = previousSummary;
      await LocalCacheService.saveKhataCustomers(_customers);
      if (_summary != null) await LocalCacheService.saveKhataSummary(_summary!);
      setError(response.error ?? 'Failed to record payment');
      notifyListeners();
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
        AppEventBus().emit(AppCacheEventType.khataMutated);
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
        AppEventBus().emit(AppCacheEventType.khataMutated);
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
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      setError(response.error ?? 'Failed to reverse transaction');
      return false;
    }
  }

  // --- Permanent Hard Deletion ---
  Future<bool> deleteCustomer(String khataId, String mobile) async {
    clearError();
    final response = await _repo.deleteCustomerKhata(khataId);
    if (response.success) {
      _customers.removeWhere((c) => c.id.toString() == khataId || c.mobile == mobile);
      await LocalCacheService.saveKhataCustomers(_customers);
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      setError(response.error ?? 'Failed to delete customer khata account');
      return false;
    }
  }

  Future<bool> deleteTransaction(String khataId, String txId, String customerMobile) async {
    clearError();
    final response = await _repo.deleteKhataTransaction(khataId, txId);
    if (response.success) {
      await loadStatement(customerMobile);
      await loadCustomers(silent: true);
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      setError(response.error ?? 'Failed to delete transaction');
      return false;
    }
  }

  // --- 1-Tap Smart Payment Reminder & WhatsApp Statement ---
  Future<void> sendWhatsAppReminder(
    BuildContext context,
    KhataCustomerModel customer, {
    List<KhataTransactionModel>? transactions,
  }) async {
    final cleanPhone = customer.mobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('khata_no_phone'))),
        );
      }
      return;
    }

    // Use passed transactions or existing loaded customer statement
    final txs = transactions ?? (_currentCustomerStatement.isNotEmpty ? _currentCustomerStatement : null);

    // Open interactive bottom sheet / modal for transparent preview, UPI link, and 1-tap WhatsApp sharing
    await showSmartPaymentReminderSheet(context, customer, transactions: txs);
  }

  // --- Download / Open Statement PDF ---
  Future<void> openStatementPdf(BuildContext context, String mobile, {KhataCustomerModel? customer}) async {
    clearError();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('khata_opening_pdf'))),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final res = await _repo.getStatementPdfUrl(mobile);
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      final uri = Uri.parse(res.data!);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (e) {
        debugPrint('Direct PDF launch warning: $e');
      }
    }

    // Clean HTML Print-Ready Passbook Statement Fallback
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
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; padding: 24px; color: #0f172a; max-width: 800px; margin: 0 auto; }
        .header { text-align: center; border-bottom: 2px solid #0f172a; padding-bottom: 14px; margin-bottom: 20px; }
        .header h1 { margin: 0; color: #0f172a; font-size: 22px; }
        .header p { margin: 6px 0 0 0; color: #475569; font-size: 13px; }
        .summary-box { background: #f8fafc; border: 1px solid #cbd5e1; padding: 16px; border-radius: 8px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
        .balance-value { font-size: 20px; font-weight: bold; color: ${balance > 0 ? '#dc2626' : '#16a34a'}; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border: 1px solid #cbd5e1; padding: 10px; text-align: left; font-size: 13px; }
        th { background-color: #f1f5f9; font-weight: bold; }
        .credit { color: #dc2626; font-weight: bold; }
        .payment { color: #16a34a; font-weight: bold; }
        @media print { .no-print { display: none; } body { padding: 0; } }
      </style>
    </head>
    <body>
      <div class="no-print" style="margin-bottom: 16px; display: flex; gap: 10px;">
        <button onclick="window.print()" style="background:#0f172a;color:white;border:none;padding:10px 18px;border-radius:6px;font-weight:bold;cursor:pointer;">🖨️ Print / Save Statement PDF</button>
      </div>
      <div class="header">
        <h1>📖 $shopName</h1>
        <p>Official Customer Khata Passbook & Account Statement</p>
        <p><strong>Customer:</strong> $custName ($mobile) • <strong>Date:</strong> $dateStr</p>
      </div>
      <div class="summary-box">
        <span><strong>CURRENT OUTSTANDING BALANCE</strong></span>
        <span class="balance-value">₹${balance.abs().toStringAsFixed(0)} ${balance > 0 ? '(Pending Dues)' : '(Settled)'}</span>
      </div>
      <table>
        <thead>
          <tr>
            <th>Date & Time</th>
            <th>Type</th>
            <th>Amount (₹)</th>
            <th>Balance After (₹)</th>
            <th>Notes / Bill</th>
          </tr>
        </thead>
        <tbody>
    ''';

    for (final tx in _currentCustomerStatement) {
      final txDate = '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}';
      final billNote = [
        if (tx.billNumber != null && tx.billNumber!.isNotEmpty) 'Bill: ${tx.billNumber}',
        if (tx.notes.isNotEmpty) tx.notes,
      ].join(' • ');

      htmlContent += '''
        <tr>
          <td>$txDate</td>
          <td class="${tx.isCredit ? 'credit' : 'payment'}">${tx.isCredit ? 'UDHAR DIYA (-)' : 'JAMA KIYA (+)'}</td>
          <td class="${tx.isCredit ? 'credit' : 'payment'}">₹${tx.amount.toStringAsFixed(0)}</td>
          <td><strong>₹${tx.balanceAfter.toStringAsFixed(0)}</strong></td>
          <td>${billNote.isNotEmpty ? billNote : '-'}</td>
        </tr>
      ''';
    }

    htmlContent += '''
        </tbody>
      </table>
    </body>
    </html>
    ''';

    try {
      final uri = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: Encoding.getByName('utf-8'));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('khata_pdf_error')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // --- 1-Tap Broadcast WhatsApp Reminders to All Overdue Debtors ---
  Future<void> broadcastWhatsAppOverdueReminders(BuildContext context) async {
    final overdue = _customers.where((c) => c.balance > 0).toList();
    if (overdue.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.isHindi ? 'कोई अतिदेय बकाया ग्राहक नहीं मिला!' : 'No customers with pending overdue balance found!')),
        );
      }
      return;
    }

    final shop = LocalCacheService.getShop();
    final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
    final isHindi = context.isHindi;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    String text;
    if (isHindi) {
      text = '📢 *दुकान बकाया उधारी सारांश (प्रसारण)*\n';
      text += 'दुकान: *$shopName*\n';
      text += 'दिनांक: $dateStr\n';
      text += '------------------------------------\n\n';
      text += 'कुल बकायादार ग्राहक: *${overdue.length}*\n\n';
      for (int i = 0; i < overdue.length; i++) {
        final c = overdue[i];
        text += '${i + 1}. *${c.name}* (${c.mobile}) — कुल बकाया: *₹${c.balance.toStringAsFixed(0)}*\n';
      }
      text += '\nकृपया समयानुसार अपनी बकाया उधारी का भुगतान करें।\nधन्यवाद!\n*$shopName*';
    } else {
      text = '📢 *STORE OUTSTANDING CREDIT SUMMARY*\n';
      text += 'Store: *$shopName*\n';
      text += 'Date: $dateStr\n';
      text += '------------------------------------\n\n';
      text += 'Total Debtors: *${overdue.length}*\n\n';
      for (int i = 0; i < overdue.length; i++) {
        final c = overdue[i];
        text += '${i + 1}. *${c.name}* (${c.mobile}) — Pending Dues: *₹${c.balance.toStringAsFixed(0)}*\n';
      }
      text += '\nKindly clear your pending balance at your earliest convenience.\nThank you!\n*$shopName*';
    }

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('khata_reminder_toast_copied')),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('khata_reminder_toast_copied')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }
}
