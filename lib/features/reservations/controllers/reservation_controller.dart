import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/base_controller.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../dashboard/repositories/shop_operations_repository.dart';
import '../models/reservation_model.dart';

class ReservationController extends BaseController {
  final ShopOperationsRepository _repo = ShopOperationsRepository();

  List<ReservationModel> _reservations = [];
  List<ReservationModel> get reservations => _reservations;

  String _activeTab = 'all'; // 'all', 'pending', 'ready', 'completed', 'cancelled'
  String get activeTab => _activeTab;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int get totalCount => _reservations.length;
  int get activeCount => _reservations.where((r) => r.isPending || r.isReady).length;
  int get completedCount => _reservations.where((r) => r.isCompleted).length;
  int get cancelledCount => _reservations.where((r) => r.isCancelled).length;

  List<ReservationModel> get filteredReservations {
    return _reservations.where((r) {
      final matchesQuery = _searchQuery.isEmpty ||
          r.pickupCode.contains(_searchQuery) ||
          r.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.customerMobile.contains(_searchQuery) ||
          r.productName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesQuery) return false;

      switch (_activeTab) {
        case 'pending':
          return r.isPending;
        case 'ready':
          return r.isReady;
        case 'completed':
          return r.isCompleted;
        case 'cancelled':
          return r.isCancelled;
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<void> loadReservations({bool silent = false}) async {
    if (!silent && _reservations.isEmpty) {
      setLoading(true);
    }
    clearError();

    final response = await _repo.listReservations();
    if (!silent) setLoading(false);

    if (response.success && response.data != null) {
      _reservations = response.data!
          .map((e) => ReservationModel.fromJson(e))
          .toList();
      _reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } else {
      if (!silent && _reservations.isEmpty) {
        setError(response.error ?? 'Failed to load counter pickup orders');
      }
    }
  }

  /// 1-Tap Counter Verification (Verify 4-digit pickup code / OTP token at counter)
  Future<bool> verifyPickupCode(String code) async {
    clearError();
    setLoading(true);

    final response = await _repo.verifyReservation(pickupCode: code);
    setLoading(false);

    if (response.success) {
      await loadReservations(silent: true);
      return true;
    } else {
      setError(response.error ?? 'Invalid or expired pickup code');
      return false;
    }
  }

  /// Cancel reservation
  Future<bool> cancelReservation(String id) async {
    clearError();
    final response = await _repo.cancelReservation(id);
    if (response.success) {
      await loadReservations(silent: true);
      return true;
    } else {
      setError(response.error ?? 'Failed to cancel reservation');
      return false;
    }
  }

  /// 1-Tap WhatsApp Customer Chat
  Future<void> openWhatsAppChat(BuildContext context, ReservationModel reservation) async {
    final cleanPhone = reservation.customerMobile.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }

    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final shop = LocalCacheService.getShop();
    final shopName = shop?.name ?? 'ShopSilo Store';

    final text = 'Namaste ${reservation.customerName} Ji! '
        'This is regarding your counter pickup order (#${reservation.pickupCode}) for '
        '"${reservation.productName}" (Qty: ${reservation.quantity}, Total: ₹${reservation.totalPrice.toStringAsFixed(0)}) '
        'at $shopName. Your order is ready for pickup at our counter!';

    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
