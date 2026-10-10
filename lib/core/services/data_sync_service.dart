import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/dashboard/controllers/dashboard_controller.dart';
import '../../features/products/controllers/product_controller.dart';
import '../storage/token_storage.dart';
import '../utils/image_utils.dart';

/// Real-World Enterprise Background Data Sync Worker.
/// Performs intelligent pre-fetching, stale-while-revalidate synchronization,
/// and image cache pre-warming on user login and app launch.
/// Prevents redundant server hits and delivers 0ms instantaneous page transitions.
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Cooldown between automatic background syncs to avoid overloading server
  static const Duration _syncCooldown = Duration(minutes: 5);

  /// Run full background synchronization
  Future<void> runBackgroundSync(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!TokenStorage.hasToken()) return;
    if (_isSyncing) return;
    if (!context.mounted) return;

    final now = DateTime.now();
    if (!force && _lastSyncTime != null && now.difference(_lastSyncTime!) < _syncCooldown) {
      debugPrint('[DataSyncService] Cache is fresh, skipping redundant sync');
      return;
    }

    _isSyncing = true;
    _lastSyncTime = now;
    debugPrint('[DataSyncService] Starting background data sync worker...');

    try {
      final authCtrl = Provider.of<AuthController>(context, listen: false);
      final prodCtrl = Provider.of<ProductController>(context, listen: false);
      final dashCtrl = Provider.of<DashboardController>(context, listen: false);

      // Execute essential API pre-fetches concurrently in background
      await Future.wait([
        authCtrl.fetchShopDetails(silent: true),
        authCtrl.fetchUserProfile(silent: true),
        prodCtrl.loadProducts(silent: true),
        dashCtrl.fetchDashboardData(silent: true),
      ]).catchError((err) {
        debugPrint('[DataSyncService] Background API sync error (non-fatal): $err');
        return <void>[];
      });

      // Warm up Image Disk & Memory Caches for 0ms visual rendering
      if (context.mounted) {
        _warmupImageCaches(context, authCtrl, prodCtrl);
      }

      debugPrint('[DataSyncService] Background data sync worker completed successfully.');
    } catch (e) {
      debugPrint('[DataSyncService] Sync worker encountered exception: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Triggered immediately upon user authentication (Login / Register / PIN)
  static void syncOnLogin(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataSyncService().runBackgroundSync(context, force: true);
    });
  }

  /// Triggered on app launch when valid session token exists
  static void syncOnAppLaunch(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataSyncService().runBackgroundSync(context, force: false);
    });
  }

  /// Pre-warms CachedNetworkImage cache for shop logo, banners, and top products
  void _warmupImageCaches(
    BuildContext context,
    AuthController authCtrl,
    ProductController prodCtrl,
  ) {
    try {
      final imagesToPrecache = <String>{};

      // 1. Shop Logo & Banners
      final shop = authCtrl.currentShop;
      if (shop != null) {
        if (shop.logoUrl != null && isServerImageUrl(shop.logoUrl!)) {
          imagesToPrecache.add(formatImageUrl(shop.logoUrl!));
        }
        for (final b in shop.banners) {
          if (isServerImageUrl(b)) {
            imagesToPrecache.add(formatImageUrl(b));
          }
        }
      }

      // 2. Merchant User Avatar
      final user = authCtrl.currentUser;
      if (user != null && user.avatarUrl != null && isServerImageUrl(user.avatarUrl!)) {
        imagesToPrecache.add(formatImageUrl(user.avatarUrl!));
      }

      // 3. Top Catalog Products
      for (final p in prodCtrl.products.take(10)) {
        if (p.images.isNotEmpty) {
          for (final img in p.images.take(2)) {
            if (isServerImageUrl(img)) {
              imagesToPrecache.add(formatImageUrl(img));
            }
          }
        } else if (p.imageUrl != null && isServerImageUrl(p.imageUrl!)) {
          imagesToPrecache.add(formatImageUrl(p.imageUrl!));
        }
      }

      // Precache each URL into memory and device disk
      for (final url in imagesToPrecache) {
        if (url.startsWith('http')) {
          if (kIsWeb) {
            precacheImage(NetworkImage(url), context).catchError((_) {});
          } else {
            precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
          }
        }
      }
    } catch (e) {
      debugPrint('[DataSyncService] Image precache exception: $e');
    }
  }
}
