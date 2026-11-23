import 'package:flutter/foundation.dart';
import '../services/offline_sync_service.dart';

/// Centralized Reactive Network Connectivity & Offline Awareness Service for ShopSilo.
/// Detects connectivity drops from API network timeouts and socket failures,
/// triggers background sync queue when network returns, and provides reactive state to UI.
class NetworkStatusService extends ChangeNotifier {
  static final NetworkStatusService _instance = NetworkStatusService._internal();
  factory NetworkStatusService() => _instance;
  NetworkStatusService._internal();

  bool _isOnline = true;
  DateTime? _lastOfflineAt;

  bool get isOnline => _isOnline;
  DateTime? get lastOfflineAt => _lastOfflineAt;

  /// Marks connection as online and initiates background sync for offline queued records
  void markOnline() {
    if (!_isOnline) {
      _isOnline = true;
      _lastOfflineAt = null;
      notifyListeners();

      // Trigger automatic background sync for offline queued operations
      try {
        OfflineSyncService.instance.processQueue();
      } catch (e) {
        debugPrint('[NetworkStatusService] Auto-sync trigger error: $e');
      }
    }
  }

  /// Marks connection as offline due to connection error or timeout
  void markOffline({String? reason}) {
    if (_isOnline) {
      _isOnline = false;
      _lastOfflineAt = DateTime.now();
      debugPrint('[NetworkStatusService] Offline mode activated: ${reason ?? "connection drop"}');
      notifyListeners();
    }
  }
}
