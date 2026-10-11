import '../../../core/utils/date_time_utils.dart';

class ReservationModel {
  final dynamic id;
  final String pickupCode;
  final String customerName;
  final String customerMobile;
  final String productName;
  final String productImageUrl;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status; // 'pending', 'ready', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String notes;

  ReservationModel({
    required this.id,
    required this.pickupCode,
    required this.customerName,
    required this.customerMobile,
    required this.productName,
    this.productImageUrl = '',
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.notes = '',
  });

  bool get isPending => status == 'pending' || status == 'active';
  bool get isReady => status == 'ready';
  bool get isCompleted => status == 'completed' || status == 'verified';
  bool get isCancelled => status == 'cancelled';

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'] is Map ? json['product'] : {};
    final rawUser = json['user'] is Map ? json['user'] : {};
    final rawCustomer = json['customer'] is Map ? json['customer'] : {};

    final custName = (json['customer_name'] ?? rawUser['name'] ?? rawCustomer['name'] ?? 'Walk-in Customer').toString();
    final custPhone = (json['customer_phone'] ?? json['customer_mobile'] ?? rawUser['phone'] ?? rawCustomer['mobile'] ?? '').toString();

    final prodName = (rawProduct['name'] ?? json['product_name'] ?? json['item_name'] ?? 'Product Item').toString();
    final prodImg = (rawProduct['image_url'] ?? rawProduct['image'] ?? json['product_image'] ?? '').toString();

    final qty = (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1;
    final price = (json['price'] is num)
        ? (json['price'] as num).toDouble()
        : (rawProduct['price'] is num)
            ? (rawProduct['price'] as num).toDouble()
            : 0.0;
    final total = (json['total_amount'] is num)
        ? (json['total_amount'] as num).toDouble()
        : price * qty;

    final rawCode = (json['pickup_code'] ?? json['reservation_number'] ?? json['id'] ?? '').toString();
    final cleanCode = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    final displayCode = cleanCode.length >= 4 ? cleanCode.substring(cleanCode.length - 4) : (cleanCode.isNotEmpty ? cleanCode : '4812');

    return ReservationModel(
      id: json['id'] ?? '',
      pickupCode: displayCode,
      customerName: custName,
      customerMobile: custPhone,
      productName: prodName,
      productImageUrl: prodImg,
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      createdAt: AppDateTimeUtils.parseToLocal(json['created_at']),
      expiresAt: AppDateTimeUtils.parseToLocalNullable(json['expires_at']),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pickup_code': pickupCode,
    'customer_name': customerName,
    'customer_phone': customerMobile,
    'product_name': productName,
    'quantity': quantity,
    'price': unitPrice,
    'total_amount': totalPrice,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'notes': notes,
  };
}
