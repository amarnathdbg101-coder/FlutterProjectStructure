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
    return {
      'product_id': product.id,
      'quantity': quantity,
      'custom_price': customPrice,
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
    List<PosCartItem> cartItems = [];
    if (json['items'] is List) {
      for (var item in (json['items'] as List)) {
        if (item is Map<String, dynamic>) {
          final pName = item['name']?.toString() ?? 'Product';
          final qty = (item['quantity'] is num) ? (item['quantity'] as num).toInt() : 1;
          final price = (item['custom_price'] is num)
              ? (item['custom_price'] as num).toDouble()
              : ((item['price'] is num) ? (item['price'] as num).toDouble() : 0.0);

          cartItems.add(
            PosCartItem(
              product: ProductModel(id: item['product_id'] ?? '', name: pName, price: price, stock: 0, category: 'General Store'),
              quantity: qty,
              customPrice: price,
            ),
          );
        }
      }
    }

    return SaleModel(
      billNumber: json['bill_number']?.toString() ?? json['id']?.toString(),
      customerPhone: json['customer_phone']?.toString() ?? '',
      items: cartItems,
      subtotal: (json['subtotal'] is num) ? (json['subtotal'] as num).toDouble() : 0.0,
      discountAmount: (json['discount_amount'] is num) ? (json['discount_amount'] as num).toDouble() : 0.0,
      totalAmount: (json['total_amount'] is num)
          ? (json['total_amount'] as num).toDouble()
          : ((json['total'] is num) ? (json['total'] as num).toDouble() : 0.0),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : DateTime.now(),
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
