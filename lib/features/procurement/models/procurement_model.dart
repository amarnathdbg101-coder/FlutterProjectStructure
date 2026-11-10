import '../../../core/utils/date_time_utils.dart';

class ProcurementItemModel {
  final String id;
  final String name;
  final String category;
  final String qty;
  final double estimatedPrice;
  final double actualPrice;
  final String dealerName;
  final String dealerPhone;
  final String notes;
  bool isCompleted;
  final DateTime createdAt;

  ProcurementItemModel({
    required this.id,
    required this.name,
    this.category = 'General Store',
    required this.qty,
    this.estimatedPrice = 0.0,
    this.actualPrice = 0.0,
    this.dealerName = '',
    this.dealerPhone = '',
    this.notes = '',
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get itemEstimatedCost => estimatedPrice;
  double get itemActualCost => actualPrice > 0 ? actualPrice : estimatedPrice;

  factory ProcurementItemModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ??
            json['product_name'] ??
            json['item_name'] ??
            json['title'] ??
            json['item'] ??
            json['description'] ??
            '')
        .toString()
        .trim();
    final rawNotes = (json['notes'] ?? '').toString().trim();
    final rawCat = (json['category'] ?? json['category_name'] ?? '').toString().trim();

    // Smart fallback for name if empty
    String resolvedName = rawName;
    if (resolvedName.isEmpty) {
      if (rawNotes.isNotEmpty) {
        resolvedName = rawNotes;
      } else if (rawCat.isNotEmpty && rawCat.toLowerCase() != 'general store') {
        resolvedName = rawCat;
      } else {
        resolvedName = 'Item';
      }
    }

    final resolvedCat = rawCat.isNotEmpty ? rawCat : 'General Store';

    return ProcurementItemModel(
      id: json['id']?.toString() ?? '',
      name: resolvedName,
      category: resolvedCat,
      qty: (json['qty'] ?? json['quantity'] ?? '1').toString().trim().isNotEmpty
          ? (json['qty'] ?? json['quantity'] ?? '1').toString().trim()
          : '1',
      estimatedPrice: (json['estimated_price'] is num)
          ? (json['estimated_price'] as num).toDouble()
          : (json['target_price'] is num)
              ? (json['target_price'] as num).toDouble()
              : (json['price'] is num)
                  ? (json['price'] as num).toDouble()
                  : 0.0,
      actualPrice: (json['actual_price'] is num)
          ? (json['actual_price'] as num).toDouble()
          : 0.0,
      dealerName: json['dealer_name']?.toString() ?? json['wholesaler']?.toString() ?? '',
      dealerPhone: json['dealer_phone']?.toString() ?? '',
      notes: rawNotes,
      isCompleted: json['is_completed'] ?? json['completed'] ?? false,
      createdAt: AppDateTimeUtils.parseToLocal(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'qty': qty,
      'estimated_price': estimatedPrice,
      'actual_price': actualPrice,
      'dealer_name': dealerName,
      'dealer_phone': dealerPhone,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
