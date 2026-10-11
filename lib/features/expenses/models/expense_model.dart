import '../../../core/utils/date_time_utils.dart';

class ExpenseModel {
  final dynamic id;
  final String category;
  final double amount;
  final String notes;
  final String paymentMethod;
  final DateTime expenseDate;

  ExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    this.notes = '',
    this.paymentMethod = 'cash',
    required this.expenseDate,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] ?? json['_id'] ?? '',
      category: json['category']?.toString() ?? 'other',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
      notes: json['notes']?.toString() ?? json['description']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      expenseDate: AppDateTimeUtils.parseToLocal(
          json['expense_date'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'notes': notes,
      'payment_method': paymentMethod,
      'expense_date': expenseDate.toIso8601String(),
    };
  }
}
