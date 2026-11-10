import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/pos_features_model.dart';
import '../repositories/pos_advanced_repository.dart';

class DamageClaimController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  List<DamageClaim> _claims = [];
  List<DamageClaim> get claims => List.unmodifiable(_claims);

  DistributorClaimSummary? _distributorSummary;
  DistributorClaimSummary? get distributorSummary => _distributorSummary;

  List<ReturnLookupItem> _lookupResults = [];
  List<ReturnLookupItem> get lookupResults => List.unmodifiable(_lookupResults);

  bool _isLookingUpReturns = false;
  bool get isLookingUpReturns => _isLookingUpReturns;

  String _activeStatusFilter = 'ALL';
  String get activeStatusFilter => _activeStatusFilter;

  void setFilter(String filter) {
    _activeStatusFilter = filter;
    notifyListeners();
  }

  List<DamageClaim> get filteredClaims {
    if (_activeStatusFilter == 'ALL') return _claims;
    return _claims.where((c) => c.status.toUpperCase() == _activeStatusFilter.toUpperCase()).toList();
  }

  Future<void> loadClaims({String? distributor}) async {
    setLoading(true);
    final res = await _repo.listDamageClaims(
      status: _activeStatusFilter == 'ALL' ? null : _activeStatusFilter,
      distributor: distributor,
    );
    setLoading(false);

    if (res.success && res.data != null) {
      _claims = res.data!;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load damage claims');
    }
  }

  Future<bool> createClaim({
    required String distributorName,
    required String productId,
    required String productName,
    required String batchNumber,
    required double quantity,
    required double unitCost,
    required String reason,
  }) async {
    setLoading(true);
    final res = await _repo.createDamageClaim({
      'distributor_name': distributorName,
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'quantity': quantity,
      'unit_cost': unitCost,
      'reason': reason,
    });
    setLoading(false);

    if (res.success && res.data != null) {
      _claims.insert(0, res.data!);
      notifyListeners();
      CustomSnackbar.showSuccess(
        null,
        'Damage claim logged for ₹${res.data!.claimAmount.toStringAsFixed(2)} against $distributorName',
      );
      return true;
    } else {
      setError(res.error ?? 'Failed to create damage claim');
      return false;
    }
  }

  Future<bool> updateClaimStatus(String id, String status, {String note = ''}) async {
    final res = await _repo.updateDamageClaimStatus(id, status, note: note);
    if (res.success && res.data != null) {
      final index = _claims.indexWhere((c) => c.id == id);
      if (index != -1) {
        _claims[index] = res.data!;
        notifyListeners();
      }
      CustomSnackbar.showSuccess(null, 'Claim status updated to $status');
      return true;
    } else {
      setError(res.error ?? 'Failed to update claim status');
      return false;
    }
  }

  Future<void> loadDistributorSummary(String distributor) async {
    setLoading(true);
    final res = await _repo.getDistributorClaimSummary(distributor);
    setLoading(false);

    if (res.success && res.data != null) {
      _distributorSummary = res.data;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load distributor statement');
    }
  }

  // Receiptless Return Lookup (Search past bills by phone or barcode within 30 days)
  Future<void> lookupReturns({String? phone, String? barcode}) async {
    _isLookingUpReturns = true;
    _lookupResults = [];
    notifyListeners();

    final res = await _repo.lookupReturns(phone: phone, barcode: barcode);
    _isLookingUpReturns = false;

    if (res.success && res.data != null) {
      _lookupResults = res.data!;
      notifyListeners();
    } else {
      _lookupResults = [];
      setError(res.error ?? 'No past purchase records found for this customer or barcode');
    }
  }

  void clearLookup() {
    _lookupResults = [];
    notifyListeners();
  }
}
