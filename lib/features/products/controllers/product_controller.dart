import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/image_utils.dart';
import '../models/bulk_import_result.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';
import '../../pos/models/pos_model.dart';

/// High-performance, offline-first Product Controller with 0ms load speed.
/// Uses Stale-While-Revalidate caching, optimistic local updates, and silent background sync.
class ProductController extends BaseController {
  final ProductRepository _repo = ProductRepository();

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  @visibleForTesting
  void setProductsForTesting(List<ProductModel> list) {
    _products = List.from(list);
    notifyListeners();
  }

  String _searchQuery = '';
  String _selectedCategory = '';

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _showProfitMargins = TokenStorage.getShowProfitMargins();
  bool get showProfitMargins => _showProfitMargins;

  Future<void> setShowProfitMargins(bool value) async {
    _showProfitMargins = value;
    await TokenStorage.saveShowProfitMargins(value);
    notifyListeners();
  }

  StreamSubscription<AppCacheEvent>? _posSaleSub;
  StreamSubscription<AppCacheEvent>? _inventorySub;
  StreamSubscription<AppCacheEvent>? _reservationSub;
  StreamSubscription<AppCacheEvent>? _productsMutatedSub;
  StreamSubscription<AppCacheEvent>? _logoutSub;

  ProductController() {
    _hydrateFromLocalCache();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _posSaleSub = AppEventBus().on(AppCacheEventType.posSaleCompleted, (event) {
      if (event.payload is SaleModel) {
        final sale = event.payload as SaleModel;
        bool changed = false;
        for (final item in sale.items) {
          if (item.product.id.isNotEmpty) {
            final idx = _products.indexWhere((p) => p.id == item.product.id);
            if (idx != -1) {
              final cur = _products[idx];
              final newStock = (cur.stock - item.quantity).clamp(0, 999999);
              _products[idx] = cur.copyWith(stock: newStock);
              changed = true;
            }
          }
        }
        if (changed) {
          LocalCacheService.saveProducts(_products);
          notifyListeners();
        }
      }
      loadProducts(silent: true);
    });
    _inventorySub = AppEventBus().on(AppCacheEventType.inventoryMutated, (_) {
      _hydrateFromLocalCache();
      loadProducts(silent: true);
    });
    _productsMutatedSub = AppEventBus().on(AppCacheEventType.productsMutated, (_) {
      _hydrateFromLocalCache();
      loadProducts(silent: true);
    });
    _reservationSub = AppEventBus().on(AppCacheEventType.reservationMutated, (_) {
      loadProducts(silent: true);
    });
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _products = [];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _posSaleSub?.cancel();
    _inventorySub?.cancel();
    _productsMutatedSub?.cancel();
    _reservationSub?.cancel();
    _logoutSub?.cancel();
    super.dispose();
  }

  /// Instantaneous 0ms hydration from local persistent storage on startup
  void _hydrateFromLocalCache() {
    final cached = LocalCacheService.getProducts();
    if (cached.isNotEmpty) {
      _products = cached;
      notifyListeners();
    }
  }

  /// Load products with Stale-While-Revalidate:
  /// Renders cached products in 0ms, then silently updates from server in background
  Future<void> loadProducts({
    String? search,
    String? category,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (search != null) _searchQuery = search;
    if (category != null) _selectedCategory = category;

    final isDefaultView = _searchQuery.isEmpty && _selectedCategory.isEmpty;

    // 1. ALWAYS FIRST LOOK LOCALLY (0ms instant display from local storage/memory)
    if (_products.isEmpty || (isDefaultView && !forceRefresh)) {
      final cached = LocalCacheService.getProducts();
      if (cached.isNotEmpty) {
        _products = cached;
      }
    }

    // Only show a blocking spinner if there is completely NO data to display locally
    if (_products.isEmpty && !silent) {
      setLoading(true);
    } else {
      _isSyncing = true;
      // Do not force UI flash if data is already visible
    }

    clearError();

    final response = await _repo.getMyProducts(
      search: _searchQuery,
      category: _selectedCategory,
    );

    setLoading(false);
    _isSyncing = false;

    if (response.success && response.data != null) {
      final newProds = response.data!;

      // Check if data actually changed to avoid unnecessary UI rebuilds & image reloads
      bool hasChanged = _products.length != newProds.length;
      if (!hasChanged) {
        for (int i = 0; i < _products.length; i++) {
          if (_products[i].id != newProds[i].id ||
              _products[i].price != newProds[i].price ||
              _products[i].stock != newProds[i].stock ||
              _products[i].name != newProds[i].name) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged || _products.isEmpty) {
        _products = newProds;
        if (isDefaultView) {
          await LocalCacheService.saveProducts(_products);
        }
        notifyListeners();
      }
    } else {
      // If network fails but we have cached products, keep them visible for offline usability!
      if (_products.isEmpty) {
        setError(response.error ?? 'Failed to load products');
      } else {
        notifyListeners();
      }
    }
  }

  Future<List<String>> uploadProductImages(List<XFile> xFiles) async {
    if (xFiles.isEmpty) return [];
    final response = await _repo.uploadProductXFiles(xFiles);
    if (response.success && response.data != null) {
      return response.data!;
    }
    setError(response.error ?? 'Failed to upload images');
    return [];
  }

  /// Add product with 0ms Optimistic UI & Local Storage update, then syncs with database in background
  Future<bool> addProduct({
    required String name,
    required double price,
    double costPrice = 0.0,
    double comparePrice = 0.0,
    required int stock,
    String unit = 'piece',
    String category = 'General Store',
    String barcode = '',
    int lowStockThreshold = 5,
    String description = '',
    double weight = 0.0,
    bool isFeatured = false,
    bool isPricePublic = true,
    List<String> images = const [],
    List<XFile> localImageFiles = const [],
    Map<String, dynamic> attributes = const {},
  }) async {
    clearError();

    // Enforce non-negative numeric bounds sanitization
    final safePrice = price.clamp(0.0, 9999999.0);
    final safeCostPrice = costPrice.clamp(0.0, 9999999.0);
    final safeComparePrice = comparePrice.clamp(0.0, 9999999.0);
    final safeStock = stock.clamp(0, 999999);

    final generatedSku = barcode.trim().isNotEmpty
        ? barcode.trim()
        : 'SKU${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final cleanCategory = formatCategoryName(category);
    final catSlug = getCategorySlug(cleanCategory);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Embed category_name, unit, and is_price_public into attributes JSONB so PostgreSQL preserves them forever
    final mergedAttributes = Map<String, dynamic>.from(attributes);
    mergedAttributes['category_name'] = cleanCategory;
    mergedAttributes['category'] = cleanCategory;
    mergedAttributes['unit'] = unit;
    mergedAttributes['is_price_public'] = isPricePublic;

    // 1. OPTIMISTIC 0ms LOCAL CREATION (User sees product in catalog immediately)
    final optimisticProduct = ProductModel(
      id: tempId,
      name: name.trim(),
      description: description.trim(),
      sku: generatedSku,
      barcode: barcode.trim().isNotEmpty ? barcode.trim() : generatedSku,
      price: safePrice,
      costPrice: safeCostPrice,
      comparePrice: safeComparePrice,
      stock: safeStock,
      lowStockThreshold: lowStockThreshold,
      unit: unit,
      category: cleanCategory,
      weight: weight,
      images: images.isNotEmpty ? images : const [],
      isActive: true,
      isFeatured: isFeatured,
      isPricePublic: isPricePublic,
      attributes: mergedAttributes,
    );

    // Immediately insert in memory & write to device storage
    _products.insert(0, optimisticProduct);
    await LocalCacheService.saveProducts(_products);
    notifyListeners();

    // 2. BACKGROUND SERVER SYNC (Silent, non-blocking)
    try {
      final validServerImages = images
          .where((img) => isServerImageUrl(img))
          .take(10)
          .toList();

      if (localImageFiles.isNotEmpty) {
        try {
          final uploadRes = await _repo.uploadProductXFiles(localImageFiles);
          if (uploadRes.success && uploadRes.data != null) {
            for (final u in uploadRes.data!) {
              if (validServerImages.length < 10 && !validServerImages.contains(u)) {
                validServerImages.add(u);
              }
            }
          } else {
            debugPrint('[ProductController] Add product image upload failed: ${uploadRes.error}');
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('Image upload warning: ${uploadRes.error ?? "Could not upload image"}'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('[ProductController] Background image upload error: $e');
        }
      }

      final payload = {
        'name': name.trim(),
        'description': description.trim(),
        'sku': generatedSku,
        'barcode': barcode.trim().isNotEmpty ? barcode.trim() : generatedSku,
        'price': safePrice,
        'cost_price': safeCostPrice,
        'compare_price': safeComparePrice,
        'mrp': safeComparePrice,
        'stock_quantity': safeStock,
        'min_stock': lowStockThreshold,
        'low_stock_threshold': lowStockThreshold,
        'unit': unit,
        'category_id': catSlug,
        'category_name': cleanCategory,
        'category': cleanCategory,
        'weight': weight,
        'images': validServerImages,
        'is_active': true,
        'is_featured': isFeatured,
        'is_price_public': isPricePublic,
        'attributes': mergedAttributes,
      };

      final response = await _repo.createProduct(payload);

      if (response.success && response.data != null) {
        // Replace optimistic temporary item with actual DB entity
        final idx = _products.indexWhere((p) => p.id == tempId);
        final createdItem = response.data!;
        final resolvedImages = createdItem.images.isNotEmpty
            ? createdItem.images
            : (validServerImages.isNotEmpty ? validServerImages : images);

        // Ensure all specifications and attributes are fully preserved
        final combinedAttributes = Map<String, dynamic>.from(mergedAttributes);
        if (createdItem.attributes.isNotEmpty) {
          combinedAttributes.addAll(createdItem.attributes);
        }

        final finalProduct = createdItem.copyWith(
          images: resolvedImages,
          unit: createdItem.unit.isNotEmpty && createdItem.unit != 'piece'
              ? createdItem.unit
              : unit,
          isPricePublic: isPricePublic,
          attributes: combinedAttributes,
        );

        if (idx >= 0) {
          _products[idx] = finalProduct;
        } else {
          _products.insert(0, finalProduct);
        }
        await LocalCacheService.saveProducts(_products);
        notifyListeners();
        AppEventBus().emit(AppCacheEventType.productsMutated);
        return true;
      } else {
        // Revert optimistic item if backend rejected
        _products.removeWhere((p) => p.id == tempId);
        await LocalCacheService.saveProducts(_products);
        final err = response.error ?? 'Failed to save product. Please check details.';
        setError(err);
        notifyListeners();
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to save "$name": $err'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    } catch (e) {
      _products.removeWhere((p) => p.id == tempId);
      await LocalCacheService.saveProducts(_products);
      final err = e.toString();
      setError(err);
      notifyListeners();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Sync error for "$name": $err'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  /// Edit product with 0ms Optimistic UI & Local Storage update, then syncs with database in background
  Future<bool> editProduct(
    dynamic id,
    Map<String, dynamic> updateData, {
    List<XFile> localImageFiles = const [],
  }) async {
    final targetId = id.toString();
    clearError();

    // 0. Locate existing product first to safely preserve attributes & specifications on partial updates
    final index = _products.indexWhere((p) => p.id == id || p.id.toString() == targetId);
    final ProductModel? original = index >= 0 ? _products[index] : null;

    // 1. Build sanitized backend payload compliant with Go dto.UpdateProductRequest
    final payload = <String, dynamic>{};

    if (updateData['name'] != null && updateData['name'].toString().trim().isNotEmpty) {
      payload['name'] = updateData['name'].toString().trim();
    }
    if (updateData['description'] != null) {
      payload['description'] = updateData['description'].toString().trim();
    }

    // SKU: Only include if >= 2 characters to satisfy Go validate:"omitempty,min=2,max=100"
    final rawSku = (updateData['sku'] ?? updateData['barcode'])?.toString().trim() ?? '';
    if (rawSku.length >= 2) {
      payload['sku'] = rawSku.toUpperCase();
    }

    if (updateData['price'] != null) {
      payload['price'] = (updateData['price'] as num).toDouble();
    }
    if (updateData['cost_price'] != null) {
      payload['cost_price'] = (updateData['cost_price'] as num).toDouble();
    }
    if (updateData['compare_price'] != null) {
      payload['compare_price'] = (updateData['compare_price'] as num).toDouble();
      payload['mrp'] = (updateData['compare_price'] as num).toDouble();
    }

    // Stock Quantity
    final stockVal = updateData['stock_quantity'] ?? updateData['stock'];
    if (stockVal != null) {
      final s = (stockVal as num).toInt();
      payload['stock_quantity'] = s >= 0 ? s : 0;
    }

    // Min Stock / Threshold
    final minStockVal = updateData['min_stock'] ?? updateData['low_stock_threshold'];
    if (minStockVal != null) {
      final m = (minStockVal as num).toInt();
      payload['min_stock'] = m >= 1 ? m : 1;
      payload['low_stock_threshold'] = m >= 1 ? m : 1;
    }

    if (updateData['weight'] != null) {
      payload['weight'] = (updateData['weight'] as num).toDouble();
    }
    if (updateData['is_active'] != null) {
      payload['is_active'] = updateData['is_active'] == true;
    }
    if (updateData['is_featured'] != null) {
      payload['is_featured'] = updateData['is_featured'] == true;
    }

    // Robust Attribute Merging (RFC 7396 Merge Patch Standard):
    // Seed with existing product attributes so partial updates (e.g., toggling price visibility)
    // NEVER erase stored brand, specifications, dimensions, shelf life, or units.
    final mergedAttributes = Map<String, dynamic>.from(original?.attributes ?? {});

    if (updateData['attributes'] != null && updateData['attributes'] is Map) {
      mergedAttributes.addAll(Map<String, dynamic>.from(updateData['attributes'] as Map));
    }

    if (updateData['is_price_public'] != null) {
      final bool isPub = updateData['is_price_public'] == true;
      payload['is_price_public'] = isPub;
      mergedAttributes['is_price_public'] = isPub;
    }

    // Category: Canonical formatting, slug mapping & attributes persistence
    String? cleanCategory;
    if (updateData['category'] != null && updateData['category'].toString().trim().isNotEmpty) {
      cleanCategory = formatCategoryName(updateData['category'].toString());
    } else if (updateData['category_id'] != null && updateData['category_id'].toString().trim().isNotEmpty) {
      cleanCategory = formatCategoryName(updateData['category_id'].toString());
    }

    if (cleanCategory != null) {
      final catSlug = getCategorySlug(cleanCategory);
      payload['category_id'] = catSlug;
      payload['category_name'] = cleanCategory;
      payload['category'] = cleanCategory;
      mergedAttributes['category_name'] = cleanCategory;
      mergedAttributes['category'] = cleanCategory;
    }

    if (updateData['unit'] != null && updateData['unit'].toString().trim().isNotEmpty) {
      final cleanUnit = updateData['unit'].toString().trim();
      payload['unit'] = cleanUnit;
      mergedAttributes['unit'] = cleanUnit;
    }

    if (mergedAttributes.isNotEmpty) {
      payload['attributes'] = mergedAttributes;
    }

    // Images: extract clean server URLs (up to 10)
    if (updateData['images'] != null && updateData['images'] is List) {
      final rawImages = updateData['images'] as List;
      final serverUrls = rawImages
          .map((e) => e.toString().trim())
          .where((img) => isServerImageUrl(img))
          .take(10)
          .toList();
      payload['images'] = serverUrls;
    }

    // 2. OPTIMISTIC LOCAL UPDATE (0ms)
    if (index >= 0 && original != null) {
      final newImages = (updateData['images'] != null
          ? List<String>.from(updateData['images'])
          : (payload['images'] as List<String>?) ?? original.images);

      _products[index] = original.copyWith(
        name: updateData['name'] ?? original.name,
        price: updateData['price'] != null ? (updateData['price'] as num).toDouble() : original.price,
        costPrice: updateData['cost_price'] != null ? (updateData['cost_price'] as num).toDouble() : original.costPrice,
        comparePrice: updateData['compare_price'] != null ? (updateData['compare_price'] as num).toDouble() : original.comparePrice,
        stock: stockVal != null ? (stockVal as num).toInt() : original.stock,
        lowStockThreshold: minStockVal != null ? (minStockVal as num).toInt() : original.lowStockThreshold,
        unit: updateData['unit'] ?? original.unit,
        category: cleanCategory ?? original.category,
        description: updateData['description'] ?? original.description,
        barcode: updateData['barcode'] ?? original.barcode,
        sku: rawSku.isNotEmpty ? rawSku.toUpperCase() : original.sku,
        images: newImages,
        weight: updateData['weight'] != null ? (updateData['weight'] as num).toDouble() : original.weight,
        attributes: mergedAttributes.isNotEmpty ? mergedAttributes : original.attributes,
        isActive: updateData['is_active'] ?? original.isActive,
        isFeatured: updateData['is_featured'] ?? original.isFeatured,
        isPricePublic: updateData['is_price_public'] != null ? (updateData['is_price_public'] == true) : original.isPricePublic,
      );
      await LocalCacheService.saveProducts(_products);
      notifyListeners();
    }

    // 3. BACKGROUND SERVER SYNC
    try {
      if (localImageFiles.isNotEmpty) {
        try {
          final uploadRes = await _repo.uploadProductXFiles(localImageFiles);
          if (uploadRes.success && uploadRes.data != null) {
            final serverUrls = List<String>.from(payload['images'] ?? []);
            for (final u in uploadRes.data!) {
              if (serverUrls.length < 10 && !serverUrls.contains(u)) {
                serverUrls.add(u);
              }
            }
            payload['images'] = serverUrls;
          } else {
            debugPrint('[ProductController] Edit product image upload warning: ${uploadRes.error}');
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('Image upload warning: ${uploadRes.error ?? "Failed to upload image"}'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (original != null && (payload['images'] == null || (payload['images'] as List).isEmpty)) {
              payload['images'] = original.images;
            }
          }
        } catch (e) {
          debugPrint('[ProductController] Background image upload error: $e');
          if (original != null && (payload['images'] == null || (payload['images'] as List).isEmpty)) {
            payload['images'] = original.images;
          }
        }
      }

      final response = await _repo.updateProduct(targetId, payload);
      if (response.success && response.data != null) {
        final currentIdx = _products.indexWhere((p) => p.id == id || p.id.toString() == targetId);
        if (currentIdx >= 0) {
          final updatedItem = response.data!;
          final mergedAttr = Map<String, dynamic>.from(_products[currentIdx].attributes);
          if (updatedItem.attributes.isNotEmpty) {
            mergedAttr.addAll(updatedItem.attributes);
          }
          final resolvedImages = updatedItem.images.isNotEmpty
              ? updatedItem.images
              : (payload['images'] != null && (payload['images'] as List).isNotEmpty
                  ? List<String>.from(payload['images'] as List)
                  : _products[currentIdx].images);

          _products[currentIdx] = updatedItem.copyWith(
            images: resolvedImages,
            unit: updatedItem.unit.isNotEmpty && updatedItem.unit != 'piece'
                ? updatedItem.unit
                : _products[currentIdx].unit,
            attributes: mergedAttr,
          );
          await LocalCacheService.saveProducts(_products);
          notifyListeners();
          AppEventBus().emit(AppCacheEventType.productsMutated);
        }
        return true;
      } else {
        // Revert if API failed and original existed
        if (original != null && index >= 0) {
          _products[index] = original;
          await LocalCacheService.saveProducts(_products);
          final err = response.error ?? 'Failed to update product on server';
          setError(err);
          notifyListeners();
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Update failed: $err'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (original != null && index >= 0) {
        _products[index] = original;
        await LocalCacheService.saveProducts(_products);
        final err = e.toString();
        setError(err);
        notifyListeners();
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Update error: $err'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  /// Quick stock update with 0ms Optimistic UI & Local Storage update, then syncs with database
  Future<bool> quickUpdateStock(dynamic id, int newStock) async {
    if (newStock < 0) return false;
    final index = _products.indexWhere((p) => p.id == id || p.id.toString() == id.toString());
    if (index < 0) return false;

    final original = _products[index];
    final adjustment = newStock - original.stock;
    if (adjustment == 0) return true;

    // 1. 0ms Optimistic Local Update
    _products[index] = original.copyWith(stock: newStock);
    await LocalCacheService.saveProducts(_products);
    notifyListeners();

    // 2. Sync to Server via inventory adjust
    final response = await _repo.adjustStock(productId: id, adjustment: adjustment);
    if (response.success) {
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      return true;
    } else {
      // Revert on failure
      _products[index] = original;
      await LocalCacheService.saveProducts(_products);
      setError(response.error ?? 'Failed to update stock on server');
      notifyListeners();
      return false;
    }
  }

  /// Delete product with 0ms Optimistic UI & Local Storage update, then syncs with database
  Future<bool> deleteProduct(dynamic id) async {
    final index = _products.indexWhere((p) => p.id == id);
    ProductModel? removedItem;
    if (index >= 0) {
      removedItem = _products[index];
      _products.removeAt(index);
      await LocalCacheService.saveProducts(_products);
      notifyListeners();
    }

    final response = await _repo.deleteProduct(id);
    if (response.success) {
      AppEventBus().emit(AppCacheEventType.productsMutated);
      return true;
    } else {
      // Revert deletion if failed
      if (removedItem != null && index >= 0) {
        _products.insert(index, removedItem);
        await LocalCacheService.saveProducts(_products);
        notifyListeners();
      }
      setError(response.error ?? 'Failed to delete product');
      return false;
    }
  }

  /// Adjust stock with 0ms Optimistic UI & Local Storage update, then syncs with database
  Future<void> adjustStock(ProductModel product, int adjustment) async {
    final newStock = product.stock + adjustment;
    if (newStock < 0) return;

    // 1. OPTIMISTIC 0ms LOCAL UPDATE
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product.copyWith(stock: newStock);
      await LocalCacheService.saveProducts(_products);
      notifyListeners();
    }

    // 2. SERVER SYNC
    final response = await _repo.adjustStock(productId: product.id, adjustment: adjustment);
    if (response.success) {
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
    } else if (index >= 0) {
      // Revert if API failed
      _products[index] = product;
      await LocalCacheService.saveProducts(_products);
      notifyListeners();
    }
  }

  /// 0ms local in-memory lookup by Barcode or SKU first; if not loaded, queries shop database
  Future<ProductModel?> findProductByBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    // 1. 0ms local memory scan
    final localMatches = _products.where((p) {
      if (p.barcode.trim().toLowerCase() == cleanCode.toLowerCase()) return true;
      if (p.sku.trim().toLowerCase() == cleanCode.toLowerCase()) return true;
      if (p.attributes['barcode']?.toString().trim().toLowerCase() == cleanCode.toLowerCase()) return true;
      return false;
    }).toList();

    if (localMatches.isNotEmpty) {
      return localMatches.first;
    }

    // 2. Query shop inventory via backend API
    final res = await _repo.getProductByBarcode(cleanCode);
    if (res.success && res.data != null) {
      return res.data;
    }
    return null;
  }

  // --- Bulk Product Import (Excel / CSV) ---
  bool _isBulkImporting = false;
  bool get isBulkImporting => _isBulkImporting;

  Future<BulkImportResult?> bulkImportProducts({
    required List<int> fileBytes,
    required String fileName,
    bool updateExisting = true,
  }) async {
    _isBulkImporting = true;
    clearError();
    notifyListeners();

    try {
      final res = await _repo.bulkImportProducts(
        fileBytes: fileBytes,
        fileName: fileName,
        updateExisting: updateExisting,
      );

      _isBulkImporting = false;
      notifyListeners();

      if (res.success && res.data != null) {
        // Silently reload product catalog to reflect newly imported items instantly
        await loadProducts(forceRefresh: true, silent: true);
        AppEventBus().emit(AppCacheEventType.productsMutated);
        return res.data;
      } else {
        setError(res.error ?? 'Failed to import products');
        return null;
      }
    } catch (e) {
      _isBulkImporting = false;
      setError(e.toString());
      notifyListeners();
      return null;
    }
  }
}
