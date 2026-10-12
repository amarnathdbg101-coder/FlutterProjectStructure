import 'dart:async';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

/// High-performance, 0ms Stale-While-Revalidate Expense Controller.
class ExpenseController extends BaseController {
  final ExpenseRepository _repo = ExpenseRepository();

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> get expenses => _expenses;

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  double get todayExpenses => _expenses
      .where((e) =>
          e.expenseDate.year == DateTime.now().year &&
          e.expenseDate.month == DateTime.now().month &&
          e.expenseDate.day == DateTime.now().day)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get monthlyExpenses => _expenses
      .where((e) =>
          e.expenseDate.year == DateTime.now().year &&
          e.expenseDate.month == DateTime.now().month)
      .fold(0.0, (sum, e) => sum + e.amount);

  StreamSubscription<AppCacheEvent>? _logoutSub;

  ExpenseController() {
    _hydrateFromLocalCache();
    loadExpenses();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _expenses = [];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    super.dispose();
  }

  void _hydrateFromLocalCache() {
    final cached = LocalCacheService.getExpenses();
    if (cached.isNotEmpty) {
      _expenses = cached;
      notifyListeners();
    }
  }

  Future<void> loadExpenses() async {
    if (_expenses.isEmpty) {
      setLoading(true);
    }
    clearError();

    final response = await _repo.listExpenses();
    setLoading(false);

    if (response.success && response.data != null) {
      _expenses = response.data!;
      await LocalCacheService.saveExpenses(_expenses);
      notifyListeners();
    } else {
      if (_expenses.isEmpty) {
        setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'खर्च लोड नहीं हो सके' : 'Failed to load expenses'));
      } else {
        notifyListeners();
      }
    }
  }

  Future<bool> addExpense({
    required String category,
    required double amount,
    String notes = '',
    String paymentMethod = 'cash',
  }) async {
    clearError();

    final tempId = 'exp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticExpense = ExpenseModel(
      id: tempId,
      category: category,
      amount: amount,
      notes: notes.trim(),
      paymentMethod: paymentMethod,
      expenseDate: DateTime.now(),
    );

    // 1. OPTIMISTIC 0ms LOCAL INSERT
    _expenses.insert(0, optimisticExpense);
    await LocalCacheService.saveExpenses(_expenses);
    notifyListeners();
    AppEventBus().emit(AppCacheEventType.expenseMutated);

    // 2. BACKGROUND SERVER SYNC
    final response = await _repo.createExpense({
      'category': category,
      'amount': amount,
      'notes': notes.trim(),
      'payment_method': paymentMethod,
      'expense_date': DateTime.now().toIso8601String(),
    });

    if (response.success && response.data != null) {
      final idx = _expenses.indexWhere((e) => e.id == tempId);
      if (idx >= 0) {
        _expenses[idx] = response.data!;
      } else {
        _expenses.insert(0, response.data!);
      }
      await LocalCacheService.saveExpenses(_expenses);
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.expenseMutated);
      return true;
    } else {
      // Keep optimistic item in local cache for offline usage
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteExpense(dynamic id) async {
    final targetId = id.toString();
    final index = _expenses.indexWhere((e) => e.id == id || e.id.toString() == targetId);

    ExpenseModel? removed;
    if (index >= 0) {
      removed = _expenses[index];
      _expenses.removeAt(index);
      await LocalCacheService.saveExpenses(_expenses);
      notifyListeners();
    }

    final response = await _repo.deleteExpense(id);
    if (response.success) {
      AppEventBus().emit(AppCacheEventType.expenseMutated);
      return true;
    } else {
      if (removed != null && index >= 0) {
        _expenses.insert(index, removed);
        await LocalCacheService.saveExpenses(_expenses);
        notifyListeners();
      }
      setError(response.error ?? (TokenStorage.getLanguage() == 'hi' ? 'खर्च हटाने में विफल' : 'Failed to delete expense'));
      return false;
    }
  }
}
