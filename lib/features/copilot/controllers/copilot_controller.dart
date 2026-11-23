import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../models/copilot_model.dart';
import '../repositories/copilot_repository.dart';

class CopilotController extends BaseController {
  final CopilotRepository _repo = CopilotRepository();

  List<DailyPrescriptionModel> _prescriptions = [];
  DeadCapitalSummaryModel? _deadCapital;
  BargainEvaluationModel? _activeEvaluation;
  List<SubstituteRecommendationModel> _substitutes = [];

  bool _isEvaluatingBargain = false;
  bool _isSearchingSubstitutes = false;

  List<DailyPrescriptionModel> get prescriptions => List.unmodifiable(_prescriptions);
  DeadCapitalSummaryModel? get deadCapital => _deadCapital;
  BargainEvaluationModel? get activeEvaluation => _activeEvaluation;
  List<SubstituteRecommendationModel> get substitutes => List.unmodifiable(_substitutes);

  bool get isEvaluatingBargain => _isEvaluatingBargain;
  bool get isSearchingSubstitutes => _isSearchingSubstitutes;
  int get activePrescriptionsCount => _prescriptions.where((p) => !p.isExecuted).length;

  CopilotController() {
    _hydrateFromCache();
    fetchDailyPrescriptions(silent: true);
    fetchDeadCapitalSummary(silent: true);
  }

  void _hydrateFromCache() {
    _prescriptions = LocalCacheService.getDailyPrescriptions();
    _deadCapital = LocalCacheService.getDeadCapital();
  }

  /// Fetches the Morning 3-Action Brief prescriptions from backend
  Future<void> fetchDailyPrescriptions({bool silent = false}) async {
    if (!silent && _prescriptions.isEmpty) setLoading(true);
    try {
      final res = await _repo.getDailyPrescriptions();
      if (res.success && res.data != null) {
        _prescriptions = res.data!;
        await LocalCacheService.saveDailyPrescriptions(_prescriptions);
        clearError();
      }
    } catch (e) {
      debugPrint('[CopilotController] Error fetching prescriptions: $e');
    } finally {
      if (!silent) setLoading(false);
      notifyListeners();
    }
  }

  /// 1-Tap execution of an action card (e.g. launch clearance combo)
  Future<bool> executePrescription(String id) async {
    final index = _prescriptions.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final updated = _prescriptions[index].copyWith(
        isExecuted: true,
        executedAt: DateTime.now(),
      );
      _prescriptions[index] = updated;
      await LocalCacheService.saveDailyPrescriptions(_prescriptions);
      notifyListeners();
    }

    try {
      final res = await _repo.executePrescription(id);
      if (res.success) {
        return true;
      }
    } catch (e) {
      debugPrint('[CopilotController] Cloud execution sync failed: $e');
    }
    return true;
  }

  /// Fetches dead capital summary and monthly carrying cost
  Future<void> fetchDeadCapitalSummary({bool silent = false}) async {
    try {
      final res = await _repo.getDeadCapitalSummary();
      if (res.success && res.data != null) {
        _deadCapital = res.data!;
        await LocalCacheService.saveDeadCapital(_deadCapital!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CopilotController] Error fetching dead capital: $e');
    }
  }

  /// Evaluates customer bargaining in real-time at the counter
  Future<BargainEvaluationModel?> evaluateBargain({
    required String productId,
    required double offeredPrice,
    String customerPhone = '',
  }) async {
    _isEvaluatingBargain = true;
    notifyListeners();

    try {
      final res = await _repo.evaluateBargain(
        productId: productId,
        customerOfferedPrice: offeredPrice,
        customerPhone: customerPhone,
      );
      if (res.success && res.data != null) {
        _activeEvaluation = res.data!;
        clearError();
        return _activeEvaluation;
      } else {
        setError(res.error ?? 'Failed to evaluate bargain');
      }
    } catch (e) {
      setError('Evaluation failed. Please try again.');
    } finally {
      _isEvaluatingBargain = false;
      notifyListeners();
    }
    return null;
  }

  /// Clears active counter negotiation evaluation
  void clearEvaluation() {
    _activeEvaluation = null;
    notifyListeners();
  }

  /// Natural language search for domain-aware clothes & cosmetics substitutes
  Future<List<SubstituteRecommendationModel>> searchSubstitutes({
    required String query,
    String category = '',
    double maxPrice = 0.0,
    String skinType = '',
    String fabric = '',
    String occasion = '',
  }) async {
    _isSearchingSubstitutes = true;
    notifyListeners();

    try {
      final res = await _repo.searchSubstitutes(
        query: query,
        category: category,
        maxPrice: maxPrice,
        skinType: skinType,
        fabric: fabric,
        occasion: occasion,
      );
      if (res.success && res.data != null) {
        _substitutes = res.data!;
        clearError();
        return _substitutes;
      } else {
        _substitutes = [];
        setError(res.error ?? 'No substitutes found');
      }
    } catch (e) {
      _substitutes = [];
      setError('Failed to search substitutes.');
    } finally {
      _isSearchingSubstitutes = false;
      notifyListeners();
    }
    return [];
  }

  /// Clears search substitute results
  void clearSubstitutes() {
    _substitutes = [];
    notifyListeners();
  }

  /// Triggers on-demand recalculation of retail intelligence and refreshes brief
  Future<void> recalculateIntelligence() async {
    setLoading(true);
    try {
      final res = await _repo.triggerRecalculate();
      if (res.success) {
        await fetchDailyPrescriptions(silent: true);
        await fetchDeadCapitalSummary(silent: true);
      }
    } catch (e) {
      debugPrint('[CopilotController] Error recalculating: $e');
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }
}
