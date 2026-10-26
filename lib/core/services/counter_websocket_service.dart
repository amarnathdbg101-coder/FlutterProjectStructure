import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import '../storage/local_cache_service.dart';
import '../storage/token_storage.dart';
import 'event_bus_service.dart';
import '../../features/products/models/product_model.dart';

/// Real-Time Enterprise Counter WebSocket Service.
/// Establishes and manages persistent bi-directional connection between Shop Counter
/// and ShopSilo GoBackend to receive 0ms instant counter pickup order alerts,
/// live POS billing sync, and customer notifications.
class CounterWebSocketService {
  static final CounterWebSocketService _instance = CounterWebSocketService._internal();
  static CounterWebSocketService get instance => _instance;
  CounterWebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  int _reconnectAttempts = 0;
  bool _isManualDisconnect = false;

  final StreamController<Map<String, dynamic>> _reservationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming real-time customer pickup reservations
  Stream<Map<String, dynamic>> get reservationStream => _reservationStreamController.stream;

  final StreamController<Map<String, dynamic>> _posParkedStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming real-time POS Parked Bills / Multi-Basket updates across floor staff & counters
  Stream<Map<String, dynamic>> get posParkedStream => _posParkedStreamController.stream;

  /// Global notification callback for in-app alert banner
  void Function(Map<String, dynamic> orderPayload)? onNewReservationNotification;

  /// Initialize and connect to shop's dedicated real-time counter channel
  void connect() {
    _isManualDisconnect = false;
    final token = TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[WebSocket] Cannot connect: No merchant session token found.');
      return;
    }

    if (_isConnected && _channel != null) {
      debugPrint('[WebSocket] Connection already active.');
      return;
    }

    _cleanup();

    final wsUri = Uri.parse('${ApiConstants.wsUrl}?token=$token');
    debugPrint('[WebSocket] Connecting to counter channel: $wsUri');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;
      _reconnectAttempts = 0;

      // Start ping heartbeat ticker to keep proxies & reverse proxies alive
      _startHeartbeat();

      _subscription = _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _reconnectAttempts = 0;
          _handleIncomingMessage(data);
        },
        onError: (error) {
          debugPrint('[WebSocket] Counter stream error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WebSocket] Counter stream closed by server.');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WebSocket] Failed to establish connection: $e');
      _handleDisconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()}));
        } catch (e) {
          debugPrint('[WebSocket] Heartbeat send failed: $e');
        }
      }
    });
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map<String, dynamic>) return;

      final event = decoded['event']?.toString() ?? '';
      final payload = decoded['payload'] is Map<String, dynamic>
          ? decoded['payload'] as Map<String, dynamic>
          : <String, dynamic>{};

      debugPrint('[WebSocket] Received event: $event');

      if (event == 'NEW_RESERVATION') {
        // 1. Instant Auditory & Haptic Feedback
        try {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        } catch (_) {}

        // 2. Broadcast on stream for controllers
        _reservationStreamController.add(payload);

        // 3. Trigger global in-app alert banner
        onNewReservationNotification?.call(payload);
      } else if (event == 'RESERVATION_STATUS_MUTATED' || event == 'RESERVATION_CANCELLED') {
        AppEventBus().emit(AppCacheEventType.reservationMutated, payload: payload);
        _reservationStreamController.add(payload);
      } else if (event == 'PRODUCT_CREATED' || event == 'PRODUCT_MUTATED') {
        try {
          if (payload.isNotEmpty) {
            final product = ProductModel.fromJson(payload);
            LocalCacheService.saveSingleProduct(product);
          }
        } catch (e) {
          debugPrint('[WebSocket] Error parsing product payload: $e');
        }
        AppEventBus().emit(AppCacheEventType.productsMutated, payload: payload);
      } else if (event == 'PRODUCT_DELETED') {
        final prodId = payload['product_id'] ?? payload['id'];
        if (prodId != null) {
          LocalCacheService.removeProduct(prodId);
        }
        AppEventBus().emit(AppCacheEventType.productsMutated, payload: payload);
      } else if (event == 'STOCK_CHANGED') {
        final prodId = payload['product_id'] ?? payload['id'];
        final stock = payload['stock'];
        if (prodId != null && stock != null) {
          final stockInt = int.tryParse(stock.toString()) ?? 0;
          LocalCacheService.updateProductStock(prodId, stockInt);
        }
        AppEventBus().emit(AppCacheEventType.inventoryMutated, payload: payload);
      } else if (event == 'POS_SALE_COMPLETED' || event == 'POS_RETURN_COMPLETED') {
        AppEventBus().emit(AppCacheEventType.posSaleCompleted, payload: payload);
        AppEventBus().emit(AppCacheEventType.inventoryMutated, payload: payload);
      } else if (event == 'KHATA_MUTATED') {
        AppEventBus().emit(AppCacheEventType.khataMutated, payload: payload);
      } else if (event == 'SHOP_STATUS_CHANGED') {
        AppEventBus().emit(AppCacheEventType.shopProfileUpdated, payload: payload);
      } else if (event == 'CATEGORY_MUTATED' || event == 'CATEGORY_DELETED') {
        AppEventBus().emit(AppCacheEventType.categoriesMutated, payload: payload);
      } else if (event == 'PROCUREMENT_MUTATED') {
        AppEventBus().emit(AppCacheEventType.procurementMutated, payload: payload);
      } else if (event == 'OFFER_MUTATED') {
        AppEventBus().emit(AppCacheEventType.offerMutated, payload: payload);
      } else if (event == 'POS_PARKED_BILLS_CHANGED' || event == 'POS_PARKED_BILL_DELETED') {
        // Instant Haptic Feedback on remote token update
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}

        _posParkedStreamController.add({
          'event': event,
          'payload': payload,
        });
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message payload: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _cleanup();

    if (_isManualDisconnect) return;

    // Exponential backoff reconnect: 3s, 6s, 9s ... up to 30s
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 3).clamp(3, 30);
    debugPrint('[WebSocket] Reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (TokenStorage.hasToken() && !_isManualDisconnect) {
        connect();
      }
    });
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Disconnect cleanly upon user logout
  void disconnect() {
    _isManualDisconnect = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _cleanup();
    debugPrint('[WebSocket] Disconnected cleanly.');
  }

  void dispose() {
    disconnect();
    _reservationStreamController.close();
  }
}
