import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../pos/models/pos_features_model.dart';
import '../repositories/khata_micro_plan_repository.dart';

class MicroPlanController extends BaseController {
  final KhataMicroPlanRepository _repo = KhataMicroPlanRepository();

  List<KhataMicroPlan> _plans = [];
  List<KhataMicroPlan> get plans => List.unmodifiable(_plans);

  KhataMicroPlan? _activePlan;
  KhataMicroPlan? get activePlan => _activePlan;

  bool _isPaying = false;
  bool get isPaying => _isPaying;

  Future<void> loadPlans({String? customerPhone}) async {
    setLoading(true);
    final res = await _repo.listPlans(customerPhone: customerPhone);
    setLoading(false);

    if (res.success && res.data != null) {
      _plans = res.data!;
      if (customerPhone != null && _plans.isNotEmpty) {
        _activePlan = _plans.first;
      }
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load micro-installment plans');
    }
  }

  Future<KhataMicroPlan?> getPlanForCustomer(String customerPhone) async {
    final res = await _repo.listPlans(customerPhone: customerPhone);
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      _activePlan = res.data!.first;
      notifyListeners();
      return _activePlan;
    }
    _activePlan = null;
    notifyListeners();
    return null;
  }

  Future<bool> createPlan({
    required String customerPhone,
    required String customerName,
    required double totalDebt,
    required double dailyAmount,
    int targetDays = 30,
  }) async {
    setLoading(true);
    final res = await _repo.createMicroPlan(
      customerPhone: customerPhone,
      customerName: customerName,
      totalDebt: totalDebt,
      dailyAmount: dailyAmount,
      targetDays: targetDays,
    );
    setLoading(false);

    if (res.success && res.data != null) {
      _plans.insert(0, res.data!);
      _activePlan = res.data!;
      notifyListeners();
      CustomSnackbar.showSuccess(
        null,
        'Daily micro-plan started: ₹${dailyAmount.toStringAsFixed(0)}/day for $targetDays days',
      );
      return true;
    } else {
      setError(res.error ?? 'Failed to initiate micro-installment plan');
      return false;
    }
  }

  Future<bool> recordPayment({
    required String planId,
    required double amount,
    String paymentMethod = 'CASH',
    String notes = '',
  }) async {
    _isPaying = true;
    notifyListeners();

    final res = await _repo.recordPayment(
      planId: planId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
    _isPaying = false;

    if (res.success && res.data != null) {
      final updated = res.data!;
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = updated;
      }
      if (_activePlan?.id == planId) {
        _activePlan = updated;
      }
      notifyListeners();
      CustomSnackbar.showSuccess(
        null,
        'Micro-payment of ₹${amount.toStringAsFixed(0)} logged! Streak: ${updated.currentStreak} days 🔥',
      );
      return true;
    } else {
      setError(res.error ?? 'Failed to record micro-payment');
      return false;
    }
  }
}
