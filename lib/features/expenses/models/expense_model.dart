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
      expenseDate: json['expense_date'] != null
          ? DateTime.tryParse(json['expense_date'].toString()) ?? DateTime.now()
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
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
