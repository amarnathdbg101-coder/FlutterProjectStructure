class KhataCustomerModel {
  final dynamic id;
  final String name;
  final String mobile;
  final double balance; // > 0 means Udhar (Customer owes merchant), < 0 means Advance
  final double creditLimit;
  final DateTime? lastTransactionAt;
  final int trustScore; // 0 - 100
  final DateTime? promiseDate;
  final int overdueDays;

  KhataCustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.balance,
    this.creditLimit = 10000.0,
    this.lastTransactionAt,
    this.trustScore = 80,
    this.promiseDate,
    this.overdueDays = 0,
  });

  bool get hasPendingUdhar => balance > 0;
  bool get isAdvance => balance < 0;
  bool get isSettled => balance == 0;
  bool get isOverdue => overdueDays > 0 || (promiseDate != null && DateTime.now().isAfter(promiseDate!));

  double get creditUtilizationPercent {
    if (creditLimit <= 0) return 0.0;
    if (balance <= 0) return 0.0;
    return ((balance / creditLimit) * 100).clamp(0.0, 100.0);
  }

  factory KhataCustomerModel.fromJson(Map<String, dynamic> json) {
    return KhataCustomerModel(
      id: json['id'] ?? json['customer_mobile'] ?? '',
      name: json['customer_name'] ?? json['name'] ?? 'Customer',
      mobile: json['customer_mobile'] ?? json['mobile'] ?? '',
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : (json['total_balance'] is num)
              ? (json['total_balance'] as num).toDouble()
              : (json['amount'] is num)
                  ? (json['amount'] as num).toDouble()
                  : double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      creditLimit: (json['credit_limit'] is num)
          ? (json['credit_limit'] as num).toDouble()
          : 10000.0,
      lastTransactionAt: json['last_activity'] != null
          ? DateTime.tryParse(json['last_activity'].toString())
          : json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
      trustScore: (json['trust_score'] is num)
          ? (json['trust_score'] as num).toInt()
          : (json['score'] is num)
              ? (json['score'] as num).toInt()
              : 80,
      promiseDate: json['promise_date'] != null
          ? DateTime.tryParse(json['promise_date'].toString())
          : null,
      overdueDays: (json['overdue_days'] is num)
          ? (json['overdue_days'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_name': name,
    'customer_mobile': mobile,
    'balance': balance,
    'credit_limit': creditLimit,
    'last_activity': lastTransactionAt?.toIso8601String(),
    'trust_score': trustScore,
    'promise_date': promiseDate?.toIso8601String(),
    'overdue_days': overdueDays,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KhataCustomerModel &&
          runtimeType == other.runtimeType &&
          (id == other.id || (mobile.isNotEmpty && mobile == other.mobile));

  @override
  int get hashCode => (id != null && id.toString().isNotEmpty) ? id.hashCode : mobile.hashCode;
}

class KhataTransactionModel {
  final dynamic id;
  final String customerMobile;
  final double amount;
  final String type; // 'credit' (Udhar diya) vs 'payment' (Jama kiya)
  final String notes;
  final String? billNumber;
  final DateTime createdAt;

  KhataTransactionModel({
    required this.id,
    required this.customerMobile,
    required this.amount,
    required this.type,
    this.notes = '',
    this.billNumber,
    required this.createdAt,
  });

  bool get isCredit => type.toLowerCase() == 'credit';

  factory KhataTransactionModel.fromJson(Map<String, dynamic> json) {
    return KhataTransactionModel(
      id: json['id'] ?? '',
      customerMobile: json['customer_mobile'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      type: json['type'] ?? (json['transaction_type'] ?? 'credit'),
      notes: json['notes'] ?? json['description'] ?? '',
      billNumber: json['bill_number'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_mobile': customerMobile,
    'amount': amount,
    'type': type,
    'notes': notes,
    'bill_number': billNumber,
    'created_at': createdAt.toIso8601String(),
  };
}

class KhataSummaryModel {
  final double totalReceivables;
  final int totalDebtors;
  final int overdueAccounts;
  final double overdueAmount;
  final double totalAdvance;

  KhataSummaryModel({
    this.totalReceivables = 0.0,
    this.totalDebtors = 0,
    this.overdueAccounts = 0,
    this.overdueAmount = 0.0,
    this.totalAdvance = 0.0,
  });

  factory KhataSummaryModel.fromJson(Map<String, dynamic> json) {
    return KhataSummaryModel(
      totalReceivables: (json['total_receivables'] is num)
          ? (json['total_receivables'] as num).toDouble()
          : (json['total_market_debt'] is num)
              ? (json['total_market_debt'] as num).toDouble()
              : (json['total_udhar'] is num)
                  ? (json['total_udhar'] as num).toDouble()
                  : (json['total_balance'] is num)
                      ? (json['total_balance'] as num).toDouble()
                      : double.tryParse(json['total_receivables']?.toString() ?? '0') ?? 0.0,
      totalDebtors: (json['total_debtors'] is num)
          ? (json['total_debtors'] as num).toInt()
          : (json['total_customers'] is num)
              ? (json['total_customers'] as num).toInt()
              : (json['customer_count'] is num)
                  ? (json['customer_count'] as num).toInt()
                  : 0,
      overdueAccounts: (json['overdue_accounts'] is num)
          ? (json['overdue_accounts'] as num).toInt()
          : (json['overdue_count'] is num)
              ? (json['overdue_count'] as num).toInt()
              : (json['overdue_customers'] is num)
                  ? (json['overdue_customers'] as num).toInt()
                  : 0,
      overdueAmount: (json['overdue_amount'] is num)
          ? (json['overdue_amount'] as num).toDouble()
          : 0.0,
      totalAdvance: (json['total_advance'] is num)
          ? (json['total_advance'] as num).toDouble()
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_receivables': totalReceivables,
    'total_debtors': totalDebtors,
    'overdue_accounts': overdueAccounts,
    'overdue_amount': overdueAmount,
    'total_advance': totalAdvance,
  };
}

class KhataAgingModel {
  final double currentDays0To30;
  final double days31To60;
  final double days61Plus;

  KhataAgingModel({
    this.currentDays0To30 = 0.0,
    this.days31To60 = 0.0,
    this.days61Plus = 0.0,
  });

  double get total => currentDays0To30 + days31To60 + days61Plus;

  factory KhataAgingModel.fromJson(Map<String, dynamic> json) {
    return KhataAgingModel(
      currentDays0To30: (json['0_30_days'] is num)
          ? (json['0_30_days'] as num).toDouble()
          : (json['current'] is num)
              ? (json['current'] as num).toDouble()
              : 0.0,
      days31To60: (json['31_60_days'] is num)
          ? (json['31_60_days'] as num).toDouble()
          : 0.0,
      days61Plus: (json['60_plus_days'] is num)
          ? (json['60_plus_days'] as num).toDouble()
          : (json['61_plus_days'] is num)
              ? (json['61_plus_days'] as num).toDouble()
              : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    '0_30_days': currentDays0To30,
    '31_60_days': days31To60,
    '60_plus_days': days61Plus,
  };
}
