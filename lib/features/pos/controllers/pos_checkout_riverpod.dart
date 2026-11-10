import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/event_bus_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../models/pos_model.dart';
import '../repositories/pos_repository.dart';

/// State representation for POS Checkout Saga execution
class PosCheckoutState {
  final bool isLoading;
  final SaleModel? completedSale;
  final String? errorMessage;
  final bool isCompensated;
  final String? compensationReason;

  const PosCheckoutState({
    this.isLoading = false,
    this.completedSale,
    this.errorMessage,
    this.isCompensated = false,
    this.compensationReason,
  });

  PosCheckoutState copyWith({
    bool? isLoading,
    SaleModel? completedSale,
    String? errorMessage,
    bool? isCompensated,
    String? compensationReason,
  }) {
    return PosCheckoutState(
      isLoading: isLoading ?? this.isLoading,
      completedSale: completedSale ?? this.completedSale,
      errorMessage: errorMessage,
      isCompensated: isCompensated ?? this.isCompensated,
      compensationReason: compensationReason,
    );
  }
}

/// Riverpod StateNotifier managing POS counter checkout orchestration
class PosCheckoutNotifier extends StateNotifier<PosCheckoutState> {
  final PosRepository _repository;

  PosCheckoutNotifier([PosRepository? repository])
      : _repository = repository ?? PosRepository(),
        super(const PosCheckoutState());

  /// Executes checkout via distributed Order Saga orchestrator with automatic reverse compensation
  Future<SaleModel?> executeCheckoutSaga({
    required String customerPhone,
    String customerName = '',
    required List<PosCartItem> items,
    required double discountAmount,
    required String paymentMethod,
    PosSplitPayment? splitPayments,
    String? customIdempotencyKey,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isCompensated: false,
      compensationReason: null,
    );

    final idempotencyKey = customIdempotencyKey ??
        'saga_pos_${DateTime.now().microsecondsSinceEpoch}';

    final response = await _repository.createSale(
      customerPhone: customerPhone,
      customerName: customerName,
      items: items,
      discountAmount: discountAmount,
      paymentMethod: paymentMethod,
      splitPayments: splitPayments,
      idempotencyKey: idempotencyKey,
    );

    if (response.success && response.data != null) {
      final sale = response.data!;
      await LocalCacheService.saveCompletedSale(sale);

      state = state.copyWith(
        isLoading: false,
        completedSale: sale,
        errorMessage: null,
        isCompensated: false,
      );

      // Publish broadcast events for UI reactivity
      AppEventBus().emit(AppCacheEventType.posSaleCompleted, payload: sale);
      AppEventBus().emit(AppCacheEventType.inventoryMutated);
      if (paymentMethod == 'khata') {
        AppEventBus().emit(AppCacheEventType.khataMutated);
      }

      return sale;
    } else {
      final err = response.error ?? 'Checkout failed';
      final isCompensated = err.toLowerCase().contains('compensation') ||
          err.toLowerCase().contains('rolled back') ||
          err.toLowerCase().contains('reverted') ||
          err.toLowerCase().contains('insufficient stock');

      state = state.copyWith(
        isLoading: false,
        errorMessage: err,
        isCompensated: isCompensated,
        compensationReason: isCompensated ? err : null,
      );

      return null;
    }
  }

  void reset() {
    state = const PosCheckoutState();
  }
}

/// Global Riverpod Provider for POS Checkout Orchestration
final posCheckoutProvider =
    StateNotifierProvider<PosCheckoutNotifier, PosCheckoutState>((ref) {
  return PosCheckoutNotifier();
});
