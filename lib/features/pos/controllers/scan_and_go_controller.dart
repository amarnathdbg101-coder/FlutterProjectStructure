import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/pos_features_model.dart';
import '../repositories/pos_advanced_repository.dart';

class ScanAndGoController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  ScanAndGoSession? _verifiedSession;
  ScanAndGoSession? get verifiedSession => _verifiedSession;

  bool _isConverting = false;
  bool get isConverting => _isConverting;

  Future<ScanAndGoSession?> verifyCode(String code) async {
    if (code.trim().isEmpty) {
      setError('Please enter a valid 6-digit verification code');
      return null;
    }

    setLoading(true);
    final res = await _repo.verifyScanAndGo(code.trim());
    setLoading(false);

    if (res.success && res.data != null) {
      _verifiedSession = res.data;
      notifyListeners();
      return _verifiedSession;
    } else {
      _verifiedSession = null;
      setError(res.error ?? 'Invalid or expired Scan & Go code');
      return null;
    }
  }

  Future<bool> convertToBill(String code) async {
    _isConverting = true;
    notifyListeners();

    final res = await _repo.convertScanAndGo(code.trim());
    _isConverting = false;

    if (res.success) {
      CustomSnackbar.showSuccess(null, 'Scan & Go basket converted to final sale bill!');
      _verifiedSession = null;
      notifyListeners();
      return true;
    } else {
      setError(res.error ?? 'Failed to convert session to bill');
      return false;
    }
  }

  void clearSession() {
    _verifiedSession = null;
    notifyListeners();
  }
}
