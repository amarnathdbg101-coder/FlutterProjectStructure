import '../../../core/network/base_controller.dart';
import '../models/__LOWER___model.dart';
import '../repositories/__LOWER___repository.dart';

class __PASCAL__Controller extends BaseController {
  final __PASCAL__Repository _repo = __PASCAL__Repository();

  List<__PASCAL__Model> _items = [];
  List<__PASCAL__Model> get items => _items;

  Future<void> fetchAll() async {
    setLoading(true);
    clearError();

    final res = await _repo.getAll();
    setLoading(false);

    if (res.success && res.data != null) {
      _items = res.data!;
    } else {
      setError(res.error ?? 'Failed to load items');
    }
    notifyListeners();
  }

  Future<bool> createItem(String title, String description) async {
    setLoading(true);

    final res = await _repo.create(title, description);
    setLoading(false);

    if (res.success && res.data != null) {
      _items.insert(0, res.data!);
      notifyListeners();
      return true;
    }

    setError(res.error ?? 'Failed to create item');
    return false;
  }

  Future<bool> deleteItem(dynamic id) async {
    final res = await _repo.delete(id);
    if (res.success) {
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    }
    return false;
  }
}
