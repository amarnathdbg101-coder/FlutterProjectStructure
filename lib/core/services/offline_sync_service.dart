import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../storage/local_cache_service.dart';
import 'event_bus_service.dart';

enum SyncActionType {
  posSale,
  expenseCreate,
  khataEntry,
  stockAdjust,
}

enum SyncStatus {
  pending,
  syncing,
  failed,
  completed,
}

class SyncQueueItem {
  final String id;
  final SyncActionType action;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String idempotencyKey;
  final int retryCount;
  final SyncStatus status;
  final String? errorMessage;
  final String title;
  final double amount;

  const SyncQueueItem({
    required this.id,
    required this.action,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.createdAt,
    required this.idempotencyKey,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    this.errorMessage,
    required this.title,
    this.amount = 0.0,
  });

  SyncQueueItem copyWith({
    int? retryCount,
    SyncStatus? status,
    String? errorMessage,
  }) {
    return SyncQueueItem(
      id: id,
      action: action,
      endpoint: endpoint,
      method: method,
      payload: payload,
      createdAt: createdAt,
      idempotencyKey: idempotencyKey,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      title: title,
      amount: amount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'idempotency_key': idempotencyKey,
      'retry_count': retryCount,
      'status': status.name,
      'error_message': errorMessage,
      'title': title,
      'amount': amount,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    SyncActionType parsedAction;
    try {
      parsedAction = SyncActionType.values.byName(json['action']?.toString() ?? 'posSale');
    } catch (_) {
      parsedAction = SyncActionType.posSale;
    }

    SyncStatus parsedStatus;
    try {
      parsedStatus = SyncStatus.values.byName(json['status']?.toString() ?? 'pending');
    } catch (_) {
      parsedStatus = SyncStatus.pending;
    }

    return SyncQueueItem(
      id: json['id']?.toString() ?? 'sync_${DateTime.now().millisecondsSinceEpoch}',
      action: parsedAction,
      endpoint: json['endpoint']?.toString() ?? '',
      method: json['method']?.toString() ?? 'POST',
      payload: (json['payload'] is Map) ? Map<String, dynamic>.from(json['payload']) : {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      idempotencyKey: json['idempotency_key']?.toString() ?? 'idemp_${DateTime.now().millisecondsSinceEpoch}',
      retryCount: (json['retry_count'] is num) ? (json['retry_count'] as num).toInt() : 0,
      status: parsedStatus,
      errorMessage: json['error_message']?.toString(),
      title: json['title']?.toString() ?? 'Offline Transaction',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
    );
  }
}

/// Centralized Conflict-Free Background Sync Engine for offline retail operations.
/// Manages optimistic queuing, FIFO retries, and network reconciliation.
class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  factory OfflineSyncService() => instance;
  OfflineSyncService._internal() {
    _hydrateQueue();
  }

  final List<SyncQueueItem> _queue = [];
  bool _isSyncing = false;

  final StreamController<int> _countController = StreamController<int>.broadcast();

  List<SyncQueueItem> get queue => List.unmodifiable(_queue);
  List<SyncQueueItem> get pendingItems => _queue.where((i) => i.status != SyncStatus.completed).toList();
  int get pendingCount => pendingItems.length;
  bool get isSyncing => _isSyncing;
  Stream<int> get pendingCountStream => _countController.stream;

  void _hydrateQueue() {
    final raw = LocalCacheService.getSyncQueue();
    if (raw.isNotEmpty) {
      _queue.clear();
      for (final m in raw) {
        try {
          _queue.add(SyncQueueItem.fromJson(m));
        } catch (_) {}
      }
      _notifyCount();
    }
  }

  void _notifyCount() {
    if (!_countController.isClosed) {
      _countController.add(pendingCount);
    }
  }

  Future<void> _persist() async {
    final list = _queue.map((i) => i.toJson()).toList();
    await LocalCacheService.saveSyncQueue(list);
    _notifyCount();
  }

  /// Reload in-memory queue from persistent cache
  void reloadFromCache() {
    _hydrateQueue();
  }

  /// Enqueue an offline mutation with 0ms latency and schedule background sync
  Future<SyncQueueItem> enqueue({
    required SyncActionType action,
    required String endpoint,
    String method = 'POST',
    required Map<String, dynamic> payload,
    required String title,
    double amount = 0.0,
    String? idempotencyKey,
    bool autoProcess = true,
  }) async {
    final now = DateTime.now();
    final uniqueId = 'sync_${now.millisecondsSinceEpoch}_${_queue.length + 1}';
    final key = idempotencyKey ?? 'idemp_${now.microsecondsSinceEpoch}_$uniqueId';

    final item = SyncQueueItem(
      id: uniqueId,
      action: action,
      endpoint: endpoint,
      method: method,
      payload: payload,
      createdAt: now,
      idempotencyKey: key,
      status: SyncStatus.pending,
      title: title,
      amount: amount,
    );

    _queue.add(item);
    await _persist();

    // Trigger non-blocking background queue flush if autoProcess is true
    if (autoProcess) {
      unawaited(processQueue());
    }

    return item;
  }

  /// Process pending queue items in FIFO order with conflict-free idempotency
  Future<bool> processQueue({BuildContext? context}) async {
    if (_isSyncing) return false;
    final pending = pendingItems;
    if (pending.isEmpty) return true;

    _isSyncing = true;
    _notifyCount();

    final dio = ApiClient().dio;
    bool allSucceeded = true;

    // Snapshot IDs to iterate safely without index range errors
    final targetIds = _queue.where((i) => i.status != SyncStatus.completed).map((i) => i.id).toList();

    for (final itemId in targetIds) {
      // Re-lookup index in case items were modified or cleared
      final currentIdx = _queue.indexWhere((i) => i.id == itemId);
      if (currentIdx == -1) continue;
      final current = _queue[currentIdx];
      if (current.status == SyncStatus.completed) continue;

      // Mark current item as syncing
      _queue[currentIdx] = current.copyWith(status: SyncStatus.syncing);
      await _persist();

      try {
        final options = Options(
          method: current.method,
          headers: {
            'X-Idempotency-Key': current.idempotencyKey,
          },
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        );

        final response = await dio.request(
          current.endpoint,
          data: current.payload,
          options: options,
        );

        final statusCode = response.statusCode ?? 200;
        final idx = _queue.indexWhere((i) => i.id == itemId);
        if (idx == -1) continue;

        if (statusCode >= 200 && statusCode < 300) {
          // Success! Mark completed
          _queue[idx] = _queue[idx].copyWith(
            status: SyncStatus.completed,
            errorMessage: null,
          );
          _emitEventBusAfterSync(current);
        } else {
          allSucceeded = false;
          _queue[idx] = _queue[idx].copyWith(
            status: SyncStatus.failed,
            retryCount: current.retryCount + 1,
            errorMessage: 'Server status: $statusCode',
          );
        }
      } on DioException catch (dioErr) {
        final idx = _queue.indexWhere((i) => i.id == itemId);
        if (idx == -1) continue;

        // If 409 conflict, item was already recorded on server (idempotency match)
        if (dioErr.response?.statusCode == 409) {
          _queue[idx] = _queue[idx].copyWith(
            status: SyncStatus.completed,
            errorMessage: null,
          );
          _emitEventBusAfterSync(current);
        } else {
          allSucceeded = false;
          final isNetworkError = dioErr.type == DioExceptionType.connectionError ||
              dioErr.type == DioExceptionType.connectionTimeout ||
              dioErr.type == DioExceptionType.receiveTimeout;

          _queue[idx] = _queue[idx].copyWith(
            status: isNetworkError ? SyncStatus.pending : SyncStatus.failed,
            retryCount: current.retryCount + 1,
            errorMessage: dioErr.message ?? 'Network connection error',
          );

          // If device is offline, stop loop so we don't spam network
          if (isNetworkError) {
            break;
          }
        }
      } catch (err) {
        final idx = _queue.indexWhere((i) => i.id == itemId);
        if (idx == -1) continue;

        allSucceeded = false;
        _queue[idx] = _queue[idx].copyWith(
          status: SyncStatus.failed,
          retryCount: current.retryCount + 1,
          errorMessage: err.toString(),
        );
      }
    }

    _isSyncing = false;
    await _persist();

    return allSucceeded;
  }

  void _emitEventBusAfterSync(SyncQueueItem item) {
    switch (item.action) {
      case SyncActionType.posSale:
        AppEventBus().emit(AppCacheEventType.posSaleCompleted, payload: item.payload);
        break;
      case SyncActionType.expenseCreate:
        AppEventBus().emit(AppCacheEventType.expenseMutated);
        break;
      case SyncActionType.khataEntry:
        AppEventBus().emit(AppCacheEventType.khataMutated);
        break;
      case SyncActionType.stockAdjust:
        AppEventBus().emit(AppCacheEventType.inventoryMutated);
        break;
    }
  }

  /// Remove completed items to keep local storage clean
  Future<void> removeCompleted() async {
    _queue.removeWhere((i) => i.status == SyncStatus.completed);
    await _persist();
  }

  /// Wipe queue (for testing or user logout)
  Future<void> clearQueue() async {
    _queue.clear();
    await _persist();
  }

  void dispose() {
    if (!_countController.isClosed) {
      _countController.close();
    }
  }
}
