import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../pos/models/pos_features_model.dart';
import '../../pos/repositories/pos_advanced_repository.dart';

class BatchExpiryController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  List<ProductBatch> _batches = [];
  List<ProductBatch> get batches => List.unmodifiable(_batches);

  MarkdownScanResult? _lastScanResult;
  MarkdownScanResult? get lastScanResult => _lastScanResult;

  int _selectedDaysWindow = 30;
  int get selectedDaysWindow => _selectedDaysWindow;

  bool _isScanningMarkdown = false;
  bool get isScanningMarkdown => _isScanningMarkdown;

  void setDaysWindow(int days) {
    _selectedDaysWindow = days;
    loadNearExpiry(days: days);
  }

  Future<void> loadNearExpiry({int? days}) async {
    final window = days ?? _selectedDaysWindow;
    setLoading(true);
    final res = await _repo.listNearExpiryBatches(days: window);
    setLoading(false);

    if (res.success && res.data != null) {
      _batches = res.data!;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load near-expiry lots');
    }
  }

  Future<bool> createBatch({
    required String productId,
    required String productName,
    required String batchNumber,
    required DateTime expiryDate,
    required double initialQuantity,
    required double purchaseCost,
    required double mrp,
  }) async {
    setLoading(true);
    final res = await _repo.createProductBatch({
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'initial_quantity': initialQuantity,
      'purchase_cost': purchaseCost,
      'mrp': mrp,
    });
    setLoading(false);

    if (res.success && res.data != null) {
      _batches.insert(0, res.data!);
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Batch #$batchNumber added to inventory radar');
      return true;
    } else {
      setError(res.error ?? 'Failed to register product batch');
      return false;
    }
  }

  Future<MarkdownScanResult?> runMarkdownScan() async {
    _isScanningMarkdown = true;
    notifyListeners();

    final res = await _repo.runMarkdownScan();
    _isScanningMarkdown = false;

    if (res.success && res.data != null) {
      _lastScanResult = res.data;
      await loadNearExpiry();
      CustomSnackbar.showSuccess(
        null,
        'Markdown scan applied to ${_lastScanResult!.markdownsApplied} near-expiry batches!',
      );
      return _lastScanResult;
    } else {
      setError(res.error ?? 'Failed to execute markdown scan');
      return null;
    }
  }
}
