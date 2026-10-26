import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/category_model.dart';
import '../repositories/product_repository.dart';

class CategoryController extends BaseController {
  final ProductRepository _repo = ProductRepository();

  List<CategoryItemModel> _categories = [];
  List<CategoryItemModel> get categories => _categories;

  List<CategoryItemModel> get customCategories =>
      _categories.where((c) => c.isCustom).toList();

  List<String> get categoryNames {
    final names = _categories.map((c) => c.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
    if (names.isEmpty) {
      return ['General Store'];
    }
    return names;
  }

  StreamSubscription<AppCacheEvent>? _categorySub;

  CategoryController() {
    loadCategories(silent: true);
    _categorySub = AppEventBus().on(AppCacheEventType.categoriesMutated, (_) {
      loadCategories(silent: true);
    });
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    super.dispose();
  }

  /// Fetches global defaults and this shop's custom categories
  Future<void> loadCategories({bool silent = false}) async {
    if (!silent) setLoading(true);
    try {
      final res = await _repo.getShopCategories();
      if (res.success && res.data != null) {
        _categories = res.data!;
        clearError();
      } else if (!silent) {
        setError(res.error ?? 'Failed to load categories', showToast: false);
      }
    } catch (e) {
      if (!silent) setError(e.toString(), showToast: false);
    } finally {
      if (!silent) setLoading(false);
      notifyListeners();
    }
  }

  /// Creates a custom category specifically for this merchant's shop
  Future<CategoryItemModel?> createCategory({
    required String name,
    String icon = '📦',
    String description = '',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      CustomSnackbar.showError(null, 'Category name cannot be empty');
      return null;
    }

    setLoading(true);
    try {
      final res = await _repo.createShopCategory(
        name: cleanName,
        icon: icon.trim().isEmpty ? '📦' : icon.trim(),
        description: description.trim(),
      );

      if (res.success && res.data != null) {
        final newCategory = res.data!;
        // Place new category at the top of custom list
        _categories = [newCategory, ..._categories.where((c) => c.id != newCategory.id)];
        CustomSnackbar.showSuccess(null, 'Category "${newCategory.name}" created successfully!');
        notifyListeners();
        return newCategory;
      } else {
        CustomSnackbar.showError(null, res.error ?? 'Failed to create category');
        return null;
      }
    } catch (e) {
      CustomSnackbar.showError(null, 'Error creating category: $e');
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// Modifies an existing custom category
  Future<bool> updateCategory({
    required String id,
    required String name,
    String icon = '📦',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      CustomSnackbar.showError(null, 'Category name cannot be empty');
      return false;
    }

    setLoading(true);
    try {
      final res = await _repo.updateShopCategory(
        id: id,
        name: cleanName,
        icon: icon.trim().isEmpty ? '📦' : icon.trim(),
      );

      if (res.success && res.data != null) {
        final updated = res.data!;
        final index = _categories.indexWhere((c) => c.id == id);
        if (index != -1) {
          _categories[index] = updated;
        }
        CustomSnackbar.showSuccess(null, 'Category updated successfully');
        notifyListeners();
        return true;
      } else {
        CustomSnackbar.showError(null, res.error ?? 'Failed to update category');
        return false;
      }
    } catch (e) {
      CustomSnackbar.showError(null, 'Error updating category: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Deletes a custom category
  Future<bool> deleteCategory(String id) async {
    setLoading(true);
    try {
      final res = await _repo.deleteShopCategory(id);
      if (res.success) {
        _categories.removeWhere((c) => c.id == id);
        CustomSnackbar.showSuccess(null, 'Category deleted successfully');
        notifyListeners();
        return true;
      } else {
        CustomSnackbar.showError(null, res.error ?? 'Failed to delete category');
        return false;
      }
    } catch (e) {
      CustomSnackbar.showError(null, 'Error deleting category: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }
}
