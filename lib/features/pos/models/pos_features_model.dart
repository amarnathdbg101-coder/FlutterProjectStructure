// POS & Store Operations Advanced Features Models
// Covers Margin Shield, Counter Hotkeys, Cash Drawer Telemetry,
// Scan & Go Queue Buster, Damage Claim Vault, Return Lookup,
// Batch Expiry Radar, and Khata Daily Micro-Installments.

class HotkeyItem {
  final String id;
  final String shopId;
  final String productId;
  final String label;
  final String colorCode;
  final int position;
  final double quickQuantity;
  final String productName;
  final double sellingPrice;
  final double stockQuantity;
  final String barcode;

  HotkeyItem({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.label,
    required this.colorCode,
    required this.position,
    required this.quickQuantity,
    this.productName = '',
    this.sellingPrice = 0.0,
    this.stockQuantity = 0.0,
    this.barcode = '',
  });

  factory HotkeyItem.fromJson(Map<String, dynamic> json) {
    return HotkeyItem(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      colorCode: json['color_code']?.toString() ?? '#3B82F6',
      position: (json['position'] as num?)?.toInt() ?? 0,
      quickQuantity: (json['quick_quantity'] as num?)?.toDouble() ?? 1.0,
      productName: json['product_name']?.toString() ?? '',
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      barcode: json['barcode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'product_id': productId,
      'label': label,
      'color_code': colorCode,
      'position': position,
      'quick_quantity': quickQuantity,
    };
  }
}


class CashDrawerSession {
  final String id;
  final String shopId;
  final String openedBy;
  final String openedByName;
  final double openingCash;
  final double closingCash;
  final double expectedCash;
  final double discrepancy;
  final double safeDropTotal;
  final double pettyCashExpenses;
  final String status; // 'OPEN' or 'CLOSED'
  final DateTime? openedAt;
  final DateTime? closedAt;
  final double currentCashInDrawer;
  final bool requiresSafeDrop;

  CashDrawerSession({
    required this.id,
    required this.shopId,
    required this.openedBy,
    required this.openedByName,
    required this.openingCash,
    required this.closingCash,
    required this.expectedCash,
    required this.discrepancy,
    required this.safeDropTotal,
    required this.pettyCashExpenses,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.currentCashInDrawer = 0.0,
    this.requiresSafeDrop = false,
  });

  bool get isOpen => status.toUpperCase() == 'OPEN';

  factory CashDrawerSession.fromJson(Map<String, dynamic> json) {
    return CashDrawerSession(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      openedBy: json['opened_by']?.toString() ?? '',
      openedByName: json['opened_by_name']?.toString() ?? json['cashier_name']?.toString() ?? 'Staff',
      openingCash: (json['opening_cash'] as num?)?.toDouble() ?? 0.0,
      closingCash: (json['closing_cash'] as num?)?.toDouble() ?? 0.0,
      expectedCash: (json['expected_cash'] as num?)?.toDouble() ?? 0.0,
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
      safeDropTotal: (json['safe_drop_total'] as num?)?.toDouble() ?? 0.0,
      pettyCashExpenses: (json['petty_cash_expenses'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'CLOSED',
      openedAt: json['opened_at'] != null ? DateTime.tryParse(json['opened_at'].toString()) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'].toString()) : null,
      currentCashInDrawer: (json['current_cash_in_drawer'] as num?)?.toDouble() ??
          (json['current_drawer_cash'] as num?)?.toDouble() ??
          0.0,
      requiresSafeDrop: json['requires_safe_drop'] == true || json['safe_drop_recommended'] == true,
    );
  }
}

class CashDrawerEvent {
  final String id;
  final String sessionId;
  final String eventType; // SALE_CASH, SAFE_DROP, PETTY_EXPENSE, SHIFT_OPEN, SHIFT_CLOSE
  final double amount;
  final String notes;
  final String cashierName;
  final DateTime createdAt;

  CashDrawerEvent({
    required this.id,
    required this.sessionId,
    required this.eventType,
    required this.amount,
    required this.notes,
    required this.cashierName,
    required this.createdAt,
  });

  factory CashDrawerEvent.fromJson(Map<String, dynamic> json) {
    return CashDrawerEvent(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      cashierName: json['cashier_name']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ScanAndGoItem {
  final String id;
  final String productId;
  final String productName;
  final String barcode;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  ScanAndGoItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory ScanAndGoItem.fromJson(Map<String, dynamic> json) {
    return ScanAndGoItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ScanAndGoSession {
  final String id;
  final String shopId;
  final String customerPhone;
  final String verificationCode;
  final String status; // 'OPEN', 'VERIFIED', 'CONVERTED', 'EXPIRED'
  final List<ScanAndGoItem> items;
  final double totalAmount;
  final int totalItems;
  final DateTime? createdAt;

  ScanAndGoSession({
    required this.id,
    required this.shopId,
    required this.customerPhone,
    required this.verificationCode,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.totalItems,
    this.createdAt,
  });

  factory ScanAndGoSession.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<ScanAndGoItem> list = [];
    if (rawItems is List) {
      list = rawItems.map((e) => ScanAndGoItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return ScanAndGoSession(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      verificationCode: json['verification_code']?.toString() ?? json['code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      items: list,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalItems: (json['total_items'] as num?)?.toInt() ?? list.length,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class DamageClaim {
  final String id;
  final String shopId;
  final String distributorName;
  final String productId;
  final String productName;
  final String batchNumber;
  final double quantity;
  final double unitCost;
  final double claimAmount;
  final String reason; // DAMAGED_IN_TRANSIT, EXPIRED_LOT, DEFECTIVE_BATCH
  final String status; // PENDING, APPROVED, SETTLED, REJECTED
  final String distributorNote;
  final DateTime createdAt;

  DamageClaim({
    required this.id,
    required this.shopId,
    required this.distributorName,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantity,
    required this.unitCost,
    required this.claimAmount,
    required this.reason,
    required this.status,
    this.distributorNote = '',
    required this.createdAt,
  });

  factory DamageClaim.fromJson(Map<String, dynamic> json) {
    return DamageClaim(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      distributorName: json['distributor_name']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      claimAmount: (json['claim_amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? 'DAMAGED_IN_TRANSIT',
      status: json['status']?.toString() ?? 'PENDING',
      distributorNote: json['distributor_note']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DistributorClaimSummary {
  final String distributorName;
  final int totalClaims;
  final double totalPendingAmount;
  final double totalSettledAmount;
  final List<DamageClaim> claims;

  DistributorClaimSummary({
    required this.distributorName,
    required this.totalClaims,
    required this.totalPendingAmount,
    required this.totalSettledAmount,
    required this.claims,
  });

  factory DistributorClaimSummary.fromJson(Map<String, dynamic> json) {
    final rawClaims = json['claims'];
    List<DamageClaim> list = [];
    if (rawClaims is List) {
      list = rawClaims.map((e) => DamageClaim.fromJson(e as Map<String, dynamic>)).toList();
    }
    return DistributorClaimSummary(
      distributorName: json['distributor_name']?.toString() ?? '',
      totalClaims: (json['total_claims'] as num?)?.toInt() ?? list.length,
      totalPendingAmount: (json['total_pending_amount'] as num?)?.toDouble() ?? 0.0,
      totalSettledAmount: (json['total_settled_amount'] as num?)?.toDouble() ?? 0.0,
      claims: list,
    );
  }
}

class ReturnLookupItem {
  final String saleId;
  final String billNumber;
  final DateTime saleDate;
  final String customerPhone;
  final String productId;
  final String productName;
  final String barcode;
  final double quantitySold;
  final double unitPrice;
  final double discount;
  final double netPrice;
  final bool isReturnable;

  ReturnLookupItem({
    required this.saleId,
    required this.billNumber,
    required this.saleDate,
    required this.customerPhone,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantitySold,
    required this.unitPrice,
    required this.discount,
    required this.netPrice,
    required this.isReturnable,
  });

  factory ReturnLookupItem.fromJson(Map<String, dynamic> json) {
    return ReturnLookupItem(
      saleId: json['sale_id']?.toString() ?? '',
      billNumber: json['bill_number']?.toString() ?? '',
      saleDate: json['sale_date'] != null
          ? DateTime.tryParse(json['sale_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customerPhone: json['customer_phone']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      quantitySold: (json['quantity_sold'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      netPrice: (json['net_price'] as num?)?.toDouble() ?? 0.0,
      isReturnable: json['is_returnable'] ?? true,
    );
  }
}

class ProductBatch {
  final String id;
  final String shopId;
  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime expiryDate;
  final double initialQuantity;
  final double currentQuantity;
  final double purchaseCost;
  final double mrp;
  final double markdownDiscount;
  final int daysToExpiry;
  final String status; // 'FRESH', 'NEAR_EXPIRY', 'CRITICAL', 'EXPIRED'

  ProductBatch({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.expiryDate,
    required this.initialQuantity,
    required this.currentQuantity,
    required this.purchaseCost,
    required this.mrp,
    this.markdownDiscount = 0.0,
    required this.daysToExpiry,
    required this.status,
  });

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    final exp = json['expiry_date'] != null
        ? DateTime.tryParse(json['expiry_date'].toString()) ?? DateTime.now().add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 30));

    int days = (json['days_to_expiry'] as num?)?.toInt() ?? 0;
    if (json['days_to_expiry'] == null) {
      final now = DateTime.now();
      days = DateTime(exp.year, exp.month, exp.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    }

    return ProductBatch(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: exp,
      initialQuantity: (json['initial_quantity'] ?? json['quantity'] as num?)?.toDouble() ?? 0.0,
      currentQuantity: (json['current_quantity'] ?? json['quantity'] as num?)?.toDouble() ?? 0.0,
      purchaseCost: (json['purchase_cost'] ?? json['cost_price'] as num?)?.toDouble() ?? 0.0,
      mrp: (json['mrp'] ?? json['original_selling_price'] ?? json['selling_price'] as num?)?.toDouble() ?? 0.0,
      markdownDiscount: (json['markdown_discount'] ?? json['markdown_percent'] as num?)?.toDouble() ?? 0.0,
      daysToExpiry: days,
      status: json['status']?.toString() ?? 'FRESH',
    );
  }
}

class MarkdownScanResult {
  final int batchesScanned;
  final int markdownsApplied;
  final double totalPotentialLossSaved;
  final List<String> updatedBatches;

  MarkdownScanResult({
    required this.batchesScanned,
    required this.markdownsApplied,
    required this.totalPotentialLossSaved,
    required this.updatedBatches,
  });

  factory MarkdownScanResult.fromJson(Map<String, dynamic> json) {
    final raw = json['updated_batches'] ?? json['batches'];
    List<String> list = [];
    if (raw is List) {
      list = raw.map((e) => e is Map ? (e['batch_number'] ?? e['id'] ?? '').toString() : e.toString()).toList();
    }
    return MarkdownScanResult(
      batchesScanned: (json['batches_scanned'] as num?)?.toInt() ?? 0,
      markdownsApplied: (json['markdowns_applied'] as num?)?.toInt() ?? 0,
      totalPotentialLossSaved: (json['capital_protected_amount'] ?? json['total_potential_loss_saved'] as num?)?.toDouble() ?? 0.0,
      updatedBatches: list,
    );
  }
}

class ExpiryRadarSummary {
  final int totalLotsTracked;
  final double capitalAtRisk30D;
  final double expiredCapitalLost;
  final double criticalCapitalAtRisk;
  final double warningCapitalAtRisk;
  final int expiredCount;
  final int criticalCount;
  final int warningCount;
  final int upcomingCount;

  ExpiryRadarSummary({
    required this.totalLotsTracked,
    required this.capitalAtRisk30D,
    required this.expiredCapitalLost,
    required this.criticalCapitalAtRisk,
    required this.warningCapitalAtRisk,
    required this.expiredCount,
    required this.criticalCount,
    required this.warningCount,
    required this.upcomingCount,
  });

  factory ExpiryRadarSummary.fromJson(Map<String, dynamic> json) {
    return ExpiryRadarSummary(
      totalLotsTracked: (json['total_lots_tracked'] as num?)?.toInt() ?? 0,
      capitalAtRisk30D: (json['capital_at_risk_30d'] as num?)?.toDouble() ?? 0.0,
      expiredCapitalLost: (json['expired_capital_lost'] as num?)?.toDouble() ?? 0.0,
      criticalCapitalAtRisk: (json['critical_capital_at_risk'] as num?)?.toDouble() ?? 0.0,
      warningCapitalAtRisk: (json['warning_capital_at_risk'] as num?)?.toDouble() ?? 0.0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
      criticalCount: (json['critical_count'] as num?)?.toInt() ?? 0,
      warningCount: (json['warning_count'] as num?)?.toInt() ?? 0,
      upcomingCount: (json['upcoming_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class KhataMicroPlan {
  final String id;
  final String shopId;
  final String customerPhone;
  final String customerName;
  final double totalDebt;
  final double dailyAmount;
  final double collectedAmount;
  final double remainingAmount;
  final int targetDays;
  final int daysCompleted;
  final int currentStreak;
  final DateTime startDate;
  final DateTime nextDueDate;
  final String status; // 'ACTIVE', 'PAUSED', 'COMPLETED'

  KhataMicroPlan({
    required this.id,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    required this.totalDebt,
    required this.dailyAmount,
    required this.collectedAmount,
    required this.remainingAmount,
    required this.targetDays,
    required this.daysCompleted,
    required this.currentStreak,
    required this.startDate,
    required this.nextDueDate,
    required this.status,
  });

  double get progressPercentage {
    if (totalDebt <= 0) return 1.0;
    return (collectedAmount / totalDebt).clamp(0.0, 1.0);
  }

  bool get isCompleted => remainingAmount <= 0 || status == 'COMPLETED';

  factory KhataMicroPlan.fromJson(Map<String, dynamic> json) {
    return KhataMicroPlan(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      dailyAmount: (json['daily_amount'] as num?)?.toDouble() ?? (json['daily_installment'] as num?)?.toDouble() ?? 0.0,
      collectedAmount: (json['collected_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      targetDays: (json['target_days'] as num?)?.toInt() ?? 30,
      daysCompleted: (json['days_completed'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? (json['streak_days'] as num?)?.toInt() ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      nextDueDate: json['next_due_date'] != null
          ? DateTime.tryParse(json['next_due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

