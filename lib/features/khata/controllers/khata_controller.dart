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
import '../services/khata_pdf_service.dart';
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
    final cleanPhone = KhataRepository.normalizePhone(mobile);

    // 1. Tier 3 Stale-While-Revalidate: Instant 0ms cached statement load
    final cached = LocalCacheService.getCustomerStatement(cleanPhone);
    if (cached.isNotEmpty) {
      _currentCustomerStatement = List<KhataTransactionModel>.from(cached);
      _isStatementLoading = false;
      notifyListeners();
    } else {
      _isStatementLoading = true;
      _currentCustomerStatement = [];
      notifyListeners();
    }

    // 2. Revalidate over network in background
    final response = await _repo.getCustomerStatement(mobile);
    _isStatementLoading = false;

    if (response.success && response.data != null) {
      _currentCustomerStatement = response.data!;
      await LocalCacheService.saveCustomerStatement(cleanPhone, response.data!);

      // Sync customer balance with the latest transaction's balanceAfter if available
      if (_currentCustomerStatement.isNotEmpty) {
        final latestTx = _currentCustomerStatement.first;
        final idx = _customers.indexWhere((c) => c.mobile == cleanPhone || c.mobile == mobile);
        if (idx != -1 && latestTx.balanceAfter >= 0) {
          _customers[idx] = _customers[idx].copyWith(
            balance: latestTx.balanceAfter,
            lastTransactionAt: latestTx.createdAt,
          );
          LocalCacheService.saveKhataCustomers(_customers);
        }
      }
    } else if (cached.isEmpty) {
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

  Future<bool> updateTransaction({
    required String khataId,
    required String txId,
    required String customerMobile,
    required double amount,
    String notes = '',
    String billNumber = '',
    required String reason,
    String securityPin = '',
    String password = '',
  }) async {
    clearError();
    if (amount <= 0) {
      setError('Please enter a valid amount (> 0)');
      return false;
    }
    if (reason.trim().length < 3) {
      setError('Audit reason must be at least 3 characters');
      return false;
    }
    final response = await _repo.updateKhataTransaction(
      khataId: khataId,
      txId: txId,
      amount: amount,
      notes: notes,
      billNumber: billNumber,
      reason: reason,
      securityPin: securityPin,
      password: password,
    );
    if (response.success) {
      await loadStatement(customerMobile);
      await loadCustomers(silent: true);
      AppEventBus().emit(AppCacheEventType.khataMutated);
      return true;
    } else {
      setError(response.error ?? 'Failed to update transaction');
      return false;
    }
  }

  Future<bool> deleteTransaction(
    String khataId,
    String txId,
    String customerMobile, {
    required String reason,
    String securityPin = '',
    String password = '',
  }) async {
    clearError();
    if (reason.trim().length < 3) {
      setError('Audit reason must be at least 3 characters');
      return false;
    }
    final response = await _repo.deleteKhataTransaction(
      khataId,
      txId,
      reason: reason,
      securityPin: securityPin,
      password: password,
    );
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

    // Use passed transactions, currently loaded customer statement, or local cache for 0ms preview
    final txs = transactions ??
        (_currentCustomerStatement.isNotEmpty
            ? _currentCustomerStatement
            : LocalCacheService.getCustomerStatement(cleanPhone));

    // Open interactive bottom sheet / modal for transparent preview, UPI link, and 1-tap WhatsApp sharing
    await showSmartPaymentReminderSheet(context, customer, transactions: txs);
  }

  // --- Download / Share / Print Statement PDF ---
  Future<void> openStatementPdf(BuildContext context, String mobile, {KhataCustomerModel? customer}) async {
    await shareStatementPdf(context, mobile, customer: customer);
  }

  /// 📤 Direct 1-Tap Native Share Sheet (Bluetooth, WhatsApp, Instagram, Quick Share, etc.)
  Future<void> shareStatementPdf(BuildContext context, String mobile, {KhataCustomerModel? customer}) async {
    clearError();
    try {
      final shop = LocalCacheService.getShop();
      final shopName = shop?.name.isNotEmpty == true ? shop!.name : 'ShopSilo Partner Store';
      final custName = customer?.name ?? 'Customer';
      final balance = customer?.balance ?? 0.0;
      final shopPhone = (shop?.phone.isNotEmpty == true) ? shop!.phone : shop?.whatsappNumber;

      await KhataPdfService.shareStatement(
        shopName: shopName,
        shopAddress: shop?.address,
        shopPhone: shopPhone,
        upiId: shop?.upiId,
        customerName: custName,
        customerMobile: mobile,
        balance: balance,
        transactions: _currentCustomerStatement,
      );
    } catch (e) {
      debugPrint('[KhataController] Share Statement error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.isHindi ? 'लेजर शेयर करने में विफल: $e' : 'Failed to share statement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
