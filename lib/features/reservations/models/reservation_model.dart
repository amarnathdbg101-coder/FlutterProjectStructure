import '../../../core/constants/api_constants.dart';
import '../../../core/utils/date_time_utils.dart';

class ReservationModel {
  final dynamic id;
  final String pickupCode;
  final String reservationNumber;
  final String customerName;
  final String customerMobile;
  final String productId;
  final String productName;
  final String productSku;
  final String categoryName;
  final String productImageUrl;
  final List<String> productImages;
  final List<String> itemsBreakdown;
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
    this.reservationNumber = '',
    required this.customerName,
    required this.customerMobile,
    this.productId = '',
    required this.productName,
    this.productSku = '',
    this.categoryName = '',
    this.productImageUrl = '',
    this.productImages = const [],
    this.itemsBreakdown = const [],
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

    // Robust Product Name Resolution
    String prodName = (rawProduct['name'] ?? json['product_name'] ?? json['item_name'] ?? '').toString().trim();

    // Robust Product Images Resolution (List, comma-string, or single string)
    List<String> imagesList = [];
    if (rawProduct['images'] is List) {
      imagesList = (rawProduct['images'] as List).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    } else if (json['product_images'] is List) {
      imagesList = (json['product_images'] as List).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    } else if (json['images'] is List) {
      imagesList = (json['images'] as List).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }

    String prodImg = '';
    if (imagesList.isNotEmpty) {
      prodImg = imagesList.first;
    } else {
      prodImg = (rawProduct['image_url'] ?? rawProduct['image'] ?? json['product_image'] ?? '').toString().trim();
    }

    // Resolve Image URL with baseUrl if relative path (/images/...)
    if (prodImg.isNotEmpty && !prodImg.startsWith('http://') && !prodImg.startsWith('https://')) {
      if (prodImg.startsWith('/')) {
        prodImg = '${ApiConstants.baseUrl}$prodImg';
      } else {
        prodImg = '${ApiConstants.baseUrl}/$prodImg';
      }
    }

    final notes = (json['notes'] ?? '').toString();

    // Parse items breakdown if from cart checkout (Items: Tata Salt (x1), Maggi (x2))
    List<String> itemsBreakdown = [];
    final itemsMatch = RegExp(r'Items:\s*([^|]+)').firstMatch(notes);
    if (itemsMatch != null && itemsMatch.group(1) != null) {
      final itemsStr = itemsMatch.group(1)!.trim();
      itemsBreakdown = itemsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (prodName.isEmpty || prodName == 'Product Item') {
        prodName = itemsBreakdown.isNotEmpty ? itemsBreakdown.first : itemsStr;
      }
    }

    if (prodName.isEmpty) {
      prodName = 'Product Item';
    }

    final sku = (rawProduct['sku'] ?? json['product_sku'] ?? json['sku'] ?? '').toString().trim();
    final catName = (rawProduct['category_name'] ?? rawProduct['category'] ?? json['category_name'] ?? '').toString().trim();
    final prodId = (json['product_id'] ?? rawProduct['id'] ?? '').toString().trim();

    final qty = (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1;
    final price = (json['product_price'] is num)
        ? (json['product_price'] as num).toDouble()
        : (rawProduct['price'] is num)
            ? (rawProduct['price'] as num).toDouble()
            : (json['price'] is num)
                ? (json['price'] as num).toDouble()
                : 0.0;
    final total = (json['total_amount'] is num)
        ? (json['total_amount'] as num).toDouble()
        : (price * qty);

    final rawPickupCode = (json['pickup_code'] ?? '').toString().trim();
    final rawResNumber = (json['reservation_number'] ?? '').toString().trim();
    final rawId = (json['id'] ?? '').toString().trim();

    // Preserve the actual 6-digit pickup code or reservation number from server
    final pickupCode = rawPickupCode.isNotEmpty
        ? rawPickupCode
        : (rawResNumber.isNotEmpty ? rawResNumber : rawId);

    return ReservationModel(
      id: rawId,
      pickupCode: pickupCode,
      reservationNumber: rawResNumber.isNotEmpty ? rawResNumber : (rawPickupCode.startsWith('HLD') ? rawPickupCode : ''),
      customerName: custName,
      customerMobile: custPhone,
      productId: prodId,
      productName: prodName,
      productSku: sku,
      categoryName: catName,
      productImageUrl: prodImg,
      productImages: imagesList,
      itemsBreakdown: itemsBreakdown,
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      createdAt: AppDateTimeUtils.parseToLocal(json['created_at']),
      expiresAt: AppDateTimeUtils.parseToLocalNullable(json['expires_at']),
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pickup_code': pickupCode,
    'reservation_number': reservationNumber,
    'customer_name': customerName,
    'customer_phone': customerMobile,
    'product_id': productId,
    'product_name': productName,
    'product_sku': productSku,
    'category_name': categoryName,
    'product_image_url': productImageUrl,
    'product_images': productImages,
    'items_breakdown': itemsBreakdown,
    'quantity': quantity,
    'price': unitPrice,
    'total_amount': totalPrice,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'notes': notes,
  };
}

