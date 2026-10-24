import 'dart:async';
import 'package:flutter/foundation.dart';
import '../storage/local_cache_service.dart';

/// Centralized Memory-Safe Event Bus for Event-Driven Cache Invalidation across Flutter Merchant OS
class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  AppEventBus._internal();

  final StreamController<AppCacheEvent> _streamController = StreamController<AppCacheEvent>.broadcast();

  Stream<AppCacheEvent> get stream => _streamController.stream;

  /// Fire a cache invalidation event with synchronous targeted cache eviction
  void emit(AppCacheEventType type, {dynamic payload}) {
    // 1. Perform synchronous targeted local cache invalidation first
    try {
      _invalidateTargetedCache(type, payload);
    } catch (e) {
      debugPrint('[AppEventBus] Error in automatic cache invalidation: $e');
    }

    // 2. Notify all active in-memory listeners
    if (!_streamController.isClosed) {
      _streamController.add(AppCacheEvent(type, payload: payload));
    }
  }

  void _invalidateTargetedCache(AppCacheEventType type, dynamic payload) {
    switch (type) {
      case AppCacheEventType.authLogout:
        LocalCacheService.clearCache();
        break;
      case AppCacheEventType.productsMutated:
      case AppCacheEventType.inventoryMutated:
        LocalCacheService.invalidateProducts();
        LocalCacheService.invalidateDashboardStats();
        LocalCacheService.invalidateAnalytics();
        break;
      case AppCacheEventType.posSaleCompleted:
        LocalCacheService.invalidateProducts();
        LocalCacheService.invalidateDashboardStats();
        LocalCacheService.invalidateAnalytics();
        if (payload is Map && payload['payment_method'] == 'khata') {
          LocalCacheService.invalidateKhata();
        }
        break;
      case AppCacheEventType.khataMutated:
        LocalCacheService.invalidateKhata();
        LocalCacheService.invalidateDashboardStats();
        break;
      case AppCacheEventType.expenseMutated:
        LocalCacheService.invalidateExpenses();
        LocalCacheService.invalidateDashboardStats();
        LocalCacheService.invalidateAnalytics();
        break;
      case AppCacheEventType.offerMutated:
        LocalCacheService.invalidateOffers();
        break;
      case AppCacheEventType.reservationMutated:
        LocalCacheService.invalidateReservations();
        LocalCacheService.invalidateDashboardStats();
        break;
      case AppCacheEventType.shopProfileUpdated:
        LocalCacheService.invalidateDashboardStats();
        LocalCacheService.invalidateProducts();
        LocalCacheService.invalidateKhata();
        LocalCacheService.invalidateExpenses();
        LocalCacheService.invalidateOffers();
        LocalCacheService.invalidateReservations();
        break;
    }
  }

  /// Listen to cache invalidation events with automatic stream filtering
  StreamSubscription<AppCacheEvent> on(AppCacheEventType type, Function(AppCacheEvent) callback) {
    return stream.where((e) => e.type == type).listen((event) {
      try {
        callback(event);
      } catch (err) {
        debugPrint('[AppEventBus] Error in event callback for ${event.type}: $err');
      }
    });
  }

  void dispose() {
    if (!_streamController.isClosed) {
      _streamController.close();
    }
  }
}

enum AppCacheEventType {
  productsMutated,
  inventoryMutated,
  posSaleCompleted,
  khataMutated,
  expenseMutated,
  offerMutated,
  reservationMutated,
  shopProfileUpdated,
  authLogout,
}

class AppCacheEvent {
  final AppCacheEventType type;
  final dynamic payload;
  final DateTime timestamp;

  AppCacheEvent(this.type, {this.payload}) : timestamp = DateTime.now();
}
