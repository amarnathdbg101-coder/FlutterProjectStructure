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
    return ProcurementItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General Store',
      qty: json['qty']?.toString() ?? '1',
      estimatedPrice: (json['estimated_price'] is num)
          ? (json['estimated_price'] as num).toDouble()
          : (json['target_price'] is num)
              ? (json['target_price'] as num).toDouble()
              : 0.0,
      actualPrice: (json['actual_price'] is num)
          ? (json['actual_price'] as num).toDouble()
          : 0.0,
      dealerName: json['dealer_name']?.toString() ?? json['notes']?.toString() ?? '',
      dealerPhone: json['dealer_phone']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
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
