import '../../../core/utils/date_time_utils.dart';
import '../../products/models/product_model.dart';

class PosCartItem {
  final ProductModel product;
  int quantity;
  double customPrice;

  PosCartItem({
    required this.product,
    this.quantity = 1,
    double? customPrice,
  }) : customPrice = customPrice ?? product.price;

  double get total => customPrice * quantity;

  Map<String, dynamic> toJson() {
    final isCustom = product.id.isEmpty || product.id.startsWith('custom_');
    return {
      'product_id': isCustom ? '' : product.id,
      'quantity': quantity,
      'custom_price': customPrice,
      'unit_price': customPrice,
      'name': product.name,
    };
  }
}

class SaleModel {
  final String? billNumber;
  final String customerPhone;
  final List<PosCartItem> items;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod; // 'cash', 'upi', 'khata'
  final DateTime createdAt;

  SaleModel({
    this.billNumber,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    // Unnest if wrapped in "bill" or "data.bill"
    final Map<String, dynamic> target = (json['bill'] is Map<String, dynamic>)
        ? json['bill'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic> && (json['data'] as Map<String, dynamic>)['bill'] is Map<String, dynamic>)
            ? (json['data'] as Map<String, dynamic>)['bill'] as Map<String, dynamic>
            : (json['data'] is Map<String, dynamic>)
                ? json['data'] as Map<String, dynamic>
                : json;

    List<PosCartItem> cartItems = [];
    final itemsList = target['items'] ?? target['bill_items'] ?? json['items'];
    if (itemsList is List) {
      for (var item in itemsList) {
        if (item is Map<String, dynamic>) {
          final pName = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Product';
          final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;

          double price = 0.0;
          if (item['unit_price'] is num && (item['unit_price'] as num) > 0) {
            price = (item['unit_price'] as num).toDouble();
          } else if (item['custom_price'] is num && (item['custom_price'] as num) > 0) {
            price = (item['custom_price'] as num).toDouble();
          } else if (item['price'] is num && (item['price'] as num) > 0) {
            price = (item['price'] as num).toDouble();
          } else if (item['total_price'] is num && qty > 0) {
            price = (item['total_price'] as num).toDouble() / qty;
          }

          final prodId = item['product_id']?.toString() ?? '';

          cartItems.add(
            PosCartItem(
              product: ProductModel(
                id: prodId,
                name: pName,
                price: price,
                stock: 0,
                category: 'General Store',
                sku: item['product_sku']?.toString() ?? '',
              ),
              quantity: qty,
              customPrice: price,
            ),
          );
        }
      }
    }

    return SaleModel(
      billNumber: target['bill_number']?.toString() ?? target['id']?.toString() ?? json['bill_number']?.toString(),
      customerPhone: target['customer_phone']?.toString() ?? json['customer_phone']?.toString() ?? '',
      items: cartItems,
      subtotal: (target['subtotal'] is num) ? (target['subtotal'] as num).toDouble() : 0.0,
      discountAmount: (target['discount_amount'] is num) ? (target['discount_amount'] as num).toDouble() : 0.0,
      totalAmount: (target['total_amount'] is num)
          ? (target['total_amount'] as num).toDouble()
          : ((target['total'] is num) ? (target['total'] as num).toDouble() : 0.0),
      paymentMethod: target['payment_method']?.toString() ?? 'cash',
      createdAt: AppDateTimeUtils.parseToLocal(target['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bill_number': billNumber,
      'customer_phone': customerPhone,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PosHeldBill {
  final String id;
  final DateTime heldAt;
  final List<PosCartItem> items;
  final String customerPhone;
  final String customerName;
  final double discount;
  final String paymentMethod;

  PosHeldBill({
    required this.id,
    required this.heldAt,
    required this.items,
    this.customerPhone = '',
    this.customerName = '',
    this.discount = 0.0,
    this.paymentMethod = 'cash',
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.total);

  double get grandTotal {
    final t = subtotal - discount;
    return t > 0 ? t : 0.0;
  }
}
