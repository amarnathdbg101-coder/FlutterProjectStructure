import 'dart:async';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../dashboard/repositories/shop_operations_repository.dart';
import '../models/offer_model.dart';

/// High-performance 0ms Stale-While-Revalidate Offers & Promotions Controller.
class OfferController extends BaseController {
  final ShopOperationsRepository _repo = ShopOperationsRepository();
  List<OfferModel> _offers = [];

  List<OfferModel> get offers => _offers;

  StreamSubscription<AppCacheEvent>? _logoutSub;
  StreamSubscription<AppCacheEvent>? _offerSub;

  OfferController() {
    _hydrateFromLocalCache();
    fetchOffers();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _logoutSub = AppEventBus().on(AppCacheEventType.authLogout, (_) {
      _offers = [];
      notifyListeners();
    });
    _offerSub = AppEventBus().on(AppCacheEventType.offerMutated, (_) {
      fetchOffers();
    });
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    _offerSub?.cancel();
    super.dispose();
  }

  void _hydrateFromLocalCache() {
    final cached = LocalCacheService.getOffers();
    // Strip out any legacy mock offers
    final clean = cached.where((o) => o.id != 'off_1' && o.id != 'off_2').toList();
    if (clean.isNotEmpty) {
      _offers = clean;
      notifyListeners();
    }
  }

  Future<void> fetchOffers() async {
    if (_offers.isEmpty) {
      setLoading(true);
    }
    clearError();

    try {
      final dio = ApiClient().dio;
      final response = await dio.get(ApiConstants.shopOffers);
      final res = ApiResponse.fromJson(response.data, (d) => d);
      setLoading(false);

      if (res.success && res.data != null) {
        final listData = res.data is List
            ? res.data as List
            : (res.data['offers'] ?? res.data['data'] ?? []);
        _offers = (listData as List)
            .map((e) => OfferModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await LocalCacheService.saveOffers(_offers);
        notifyListeners();
        return;
      }
    } catch (_) {
      setLoading(false);
    }
  }

  Future<bool> createOffer({
    required String title,
    required String discountText,
    String description = '',
    String discountType = 'percentage',
    double discountValue = 0.0,
    double minOrderAmount = 0.0,
    double maxDiscount = 0.0,
    String applicableDays = 'all',
    String bannerTag = '🔥 Special Offer',
    String promoCode = '',
    int minPointsRequired = 0,
    int expiresInDays = 7,
  }) async {
    clearError();

    final tempId = 'off_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticOffer = OfferModel(
      id: tempId,
      title: title.trim(),
      discountText: discountText.trim(),
      description: description.trim(),
      discountType: discountType.trim(),
      discountValue: discountValue,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      applicableDays: applicableDays.trim(),
      bannerTag: bannerTag.trim(),
      promoCode: promoCode.trim().toUpperCase(),
      minPointsRequired: minPointsRequired,
      expiresInDays: expiresInDays,
      expiresAt: DateTime.now().add(Duration(days: expiresInDays)),
      isActive: true,
      createdAt: DateTime.now(),
    );

    // 1. 0ms OPTIMISTIC LOCAL INSERT
    _offers.insert(0, optimisticOffer);
    await LocalCacheService.saveOffers(_offers);
    notifyListeners();

    // 2. BACKGROUND SERVER SYNC
    final response = await _repo.createOffer(
      title: title,
      discountText: discountText,
      description: description,
      discountType: discountType,
      discountValue: discountValue,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      applicableDays: applicableDays,
      bannerTag: bannerTag,
      promoCode: promoCode,
      minPointsRequired: minPointsRequired,
      expiresInDays: expiresInDays,
    );

    if (response.success && response.data != null) {
      final idx = _offers.indexWhere((o) => o.id == tempId);
      final created = OfferModel.fromJson(response.data!);
      if (idx >= 0) {
        _offers[idx] = created;
      } else {
        _offers.insert(0, created);
      }
      await LocalCacheService.saveOffers(_offers);
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.offerMutated);
      return true;
    } else {
      setError(response.message);
      // Remove optimistic insert if server failed
      _offers.removeWhere((o) => o.id == tempId);
      await LocalCacheService.saveOffers(_offers);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOffer({
    required String id,
    required String title,
    required String discountText,
    String description = '',
    String discountType = 'percentage',
    double discountValue = 0.0,
    double minOrderAmount = 0.0,
    double maxDiscount = 0.0,
    String applicableDays = 'all',
    String bannerTag = '🔥 Special Offer',
    String promoCode = '',
    int minPointsRequired = 0,
    int expiresInDays = 7,
    bool isActive = true,
  }) async {
    clearError();

    final idx = _offers.indexWhere((o) => o.id == id);
    if (idx < 0) return false;

    final existing = _offers[idx];
    final updated = existing.copyWith(
      title: title.trim(),
      discountText: discountText.trim(),
      description: description.trim(),
      discountType: discountType.trim(),
      discountValue: discountValue,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      applicableDays: applicableDays.trim(),
      bannerTag: bannerTag.trim(),
      promoCode: promoCode.trim().toUpperCase(),
      minPointsRequired: minPointsRequired,
      expiresInDays: expiresInDays,
      isActive: isActive,
      updatedAt: DateTime.now(),
    );

    // 0ms Optimistic local update
    _offers[idx] = updated;
    await LocalCacheService.saveOffers(_offers);
    notifyListeners();

    final response = await _repo.updateOffer(id, {
      'title': updated.title,
      'discount_text': updated.discountText,
      'description': updated.description,
      'discount_type': updated.discountType,
      'discount_value': updated.discountValue,
      'min_order_amount': updated.minOrderAmount,
      'max_discount': updated.maxDiscount,
      'applicable_days': updated.applicableDays,
      'banner_tag': updated.bannerTag,
      'promo_code': updated.promoCode,
      'min_points_required': updated.minPointsRequired,
      'expires_in_days': updated.expiresInDays,
      'is_active': updated.isActive,
    });

    if (response.success && response.data != null) {
      _offers[idx] = OfferModel.fromJson(response.data!);
      await LocalCacheService.saveOffers(_offers);
      notifyListeners();
      AppEventBus().emit(AppCacheEventType.offerMutated);
      return true;
    }

    return true;
  }

  Future<bool> deleteOffer(dynamic id) async {
    final targetId = id.toString();
    final index = _offers.indexWhere((o) => o.id == id || o.id.toString() == targetId);

    OfferModel? removed;
    if (index >= 0) {
      removed = _offers[index];
      _offers.removeAt(index);
      await LocalCacheService.saveOffers(_offers);
      notifyListeners();
    }

    final response = await _repo.deleteOffer(targetId);
    if (response.success) {
      AppEventBus().emit(AppCacheEventType.offerMutated);
      return true;
    } else {
      if (removed != null && index >= 0) {
        _offers.insert(index, removed);
        await LocalCacheService.saveOffers(_offers);
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> toggleOfferActive(OfferModel offer) async {
    final index = _offers.indexWhere((o) => o.id == offer.id);
    if (index < 0) return;

    // 1. 0ms Optimistic toggle locally
    final updated = offer.copyWith(isActive: !offer.isActive);
    _offers[index] = updated;
    await LocalCacheService.saveOffers(_offers);
    notifyListeners();
    AppEventBus().emit(AppCacheEventType.offerMutated);

    // 2. Background server sync via dedicated toggle endpoint
    final res = await _repo.toggleOffer(offer.id.toString());
    if (res.success && res.data != null) {
      _offers[index] = OfferModel.fromJson(res.data!);
      await LocalCacheService.saveOffers(_offers);
      notifyListeners();
    }
  }
}
