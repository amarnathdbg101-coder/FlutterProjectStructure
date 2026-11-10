import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/pos_features_model.dart';
import '../repositories/pos_advanced_repository.dart';

class CashDrawerController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  CashDrawerSession? _currentSession;
  CashDrawerSession? get currentSession => _currentSession;

  List<CashDrawerSession> _history = [];
  List<CashDrawerSession> get history => List.unmodifiable(_history);

  bool get isDrawerOpen => _currentSession != null && _currentSession!.isOpen;

  double get currentDrawerCash => _currentSession?.currentCashInDrawer ?? 0.0;

  bool get requiresSafeDrop =>
      _currentSession?.requiresSafeDrop == true || (_currentSession != null && currentDrawerCash >= 10000.0);

  Future<void> fetchCurrentStatus() async {
    setLoading(true);
    final res = await _repo.getCurrentDrawerStatus();
    setLoading(false);

    if (res.success && res.data != null) {
      _currentSession = res.data;
      notifyListeners();
    } else {
      // If no active session or 404, session is closed
      _currentSession = null;
      notifyListeners();
    }
  }

  Future<bool> openSession({required double openingCash, String notes = ''}) async {
    setLoading(true);
    final res = await _repo.openDrawerSession(openingCash: openingCash, notes: notes);
    setLoading(false);

    if (res.success && res.data != null) {
      _currentSession = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Cash drawer shift opened successfully (₹${openingCash.toStringAsFixed(2)})');
      return true;
    } else {
      setError(res.error ?? 'Failed to open cash drawer shift');
      return false;
    }
  }

  Future<bool> closeSession({required double closingCash, String notes = ''}) async {
    setLoading(true);
    final res = await _repo.closeDrawerSession(closingCash: closingCash, notes: notes);
    setLoading(false);

    if (res.success && res.data != null) {
      _currentSession = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(
        null,
        'Cash drawer shift closed. Discrepancy: ₹${_currentSession!.discrepancy.toStringAsFixed(2)}',
      );
      return true;
    } else {
      setError(res.error ?? 'Failed to close cash drawer shift');
      return false;
    }
  }

  Future<bool> recordSafeDrop({required double amount, String notes = '', String envelopeNumber = ''}) async {
    setLoading(true);
    final res = await _repo.recordSafeDrop(amount: amount, notes: notes, envelopeNumber: envelopeNumber);
    setLoading(false);

    if (res.success && res.data != null) {
      _currentSession = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Safe drop of ₹${amount.toStringAsFixed(2)} recorded into store locker');
      return true;
    } else {
      setError(res.error ?? 'Failed to record safe drop');
      return false;
    }
  }

  Future<bool> recordPettyExpense({required double amount, required String category, String notes = ''}) async {
    setLoading(true);
    final res = await _repo.recordPettyExpense(amount: amount, category: category, notes: notes);
    setLoading(false);

    if (res.success && res.data != null) {
      _currentSession = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Petty expense of ₹${amount.toStringAsFixed(2)} logged from cash drawer');
      return true;
    } else {
      setError(res.error ?? 'Failed to log petty expense');
      return false;
    }
  }

  Future<void> fetchHistory() async {
    setLoading(true);
    final res = await _repo.getDrawerHistory();
    setLoading(false);

    if (res.success && res.data != null) {
      _history = res.data!;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load drawer shift history');
    }
  }
}
