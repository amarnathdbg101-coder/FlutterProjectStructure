import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/pos_features_model.dart';
import '../repositories/pos_advanced_repository.dart';

class HotkeyController extends BaseController {
  final PosAdvancedRepository _repo = PosAdvancedRepository();

  List<HotkeyItem> _hotkeys = [];
  List<HotkeyItem> get hotkeys => List.unmodifiable(_hotkeys);

  Future<void> loadHotkeys() async {
    setLoading(true);
    final res = await _repo.getHotkeys();
    setLoading(false);

    if (res.success && res.data != null) {
      _hotkeys = res.data!;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load counter hotkeys');
    }
  }

  Future<void> autoPopulate() async {
    setLoading(true);
    final res = await _repo.autoPopulateHotkeys();
    setLoading(false);

    if (res.success && res.data != null) {
      _hotkeys = res.data!;
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Top selling items auto-assigned to counter touch hotkeys');
    } else {
      setError(res.error ?? 'Failed to auto-populate hotkeys');
    }
  }

  Future<bool> createHotkey({
    required String productId,
    required String label,
    required String colorCode,
    required int position,
    double quickQuantity = 1.0,
  }) async {
    setLoading(true);
    final res = await _repo.createHotkey({
      'product_id': productId,
      'label': label,
      'color_code': colorCode,
      'position': position,
      'quick_quantity': quickQuantity,
    });
    setLoading(false);

    if (res.success && res.data != null) {
      _hotkeys.removeWhere((e) => e.position == position || e.id == res.data!.id);
      _hotkeys.add(res.data!);
      _hotkeys.sort((a, b) => a.position.compareTo(b.position));
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Hotkey "$label" pinned to counter position $position');
      return true;
    } else {
      setError(res.error ?? 'Failed to save hotkey');
      return false;
    }
  }

  Future<bool> deleteHotkey(String id) async {
    final res = await _repo.deleteHotkey(id);
    if (res.success) {
      _hotkeys.removeWhere((e) => e.id == id);
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Hotkey removed');
      return true;
    } else {
      setError(res.error ?? 'Failed to delete hotkey');
      return false;
    }
  }
}
