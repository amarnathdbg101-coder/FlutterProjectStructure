class AnalyticsModel {
  final double totalRevenue;
  final double totalCost;
  final double totalExpenses;
  final double netPocketProfit;
  final double averageMarginPct;
  final int totalSalesCount;
  final List<AnalyticsProductItem> bestProfitable;
  final List<AnalyticsProductItem> deadStock;

  AnalyticsModel({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalExpenses,
    required this.netPocketProfit,
    required this.averageMarginPct,
    required this.totalSalesCount,
    this.bestProfitable = const [],
    this.deadStock = const [],
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final bestList = json['best_profitable'] as List? ?? json['top_products'] as List? ?? [];
    final deadList = json['old_dead_stock'] as List? ?? json['slow_moving'] as List? ?? [];

    double rev = (json['total_revenue'] ?? json['total_sales'] ?? json['revenue'] ?? 0.0).toDouble();
    double cost = (json['total_cost'] ?? json['cost_of_goods_sold'] ?? json['cogs'] ?? 0.0).toDouble();
    double exp = (json['total_expenses'] ?? json['operating_expenses'] ?? 0.0).toDouble();
    double profit = (json['net_pocket_profit'] ?? json['total_profit'] ?? json['net_profit'] ?? (rev - cost - exp)).toDouble();

    double margin = (json['average_margin_pct'] ?? json['profit_margin'] ?? (rev > 0 ? (profit / rev) * 100 : 0.0)).toDouble();
    int salesCount = json['total_completed_sales'] ?? json['total_orders'] ?? json['transaction_count'] ?? 0;

    return AnalyticsModel(
      totalRevenue: rev,
      totalCost: cost,
      totalExpenses: exp,
      netPocketProfit: profit,
      averageMarginPct: margin,
      totalSalesCount: salesCount,
      bestProfitable: bestList.map((e) => AnalyticsProductItem.fromJson(e as Map<String, dynamic>)).toList(),
      deadStock: deadList.map((e) => AnalyticsProductItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'total_cost': totalCost,
      'total_expenses': totalExpenses,
      'net_pocket_profit': netPocketProfit,
      'average_margin_pct': averageMarginPct,
      'total_completed_sales': totalSalesCount,
      'best_profitable': bestProfitable.map((e) => e.toJson()).toList(),
      'old_dead_stock': deadStock.map((e) => e.toJson()).toList(),
    };
  }
}

class AnalyticsProductItem {
  final String productId;
  final String name;
  final int soldQty;
  final int currentStock;
  final double profitAmount;
  final double marginPct;
  final int daysInStock;

  AnalyticsProductItem({
    required this.productId,
    required this.name,
    this.soldQty = 0,
    this.currentStock = 0,
    this.profitAmount = 0.0,
    this.marginPct = 0.0,
    this.daysInStock = 0,
  });

  factory AnalyticsProductItem.fromJson(Map<String, dynamic> json) {
    return AnalyticsProductItem(
      productId: json['product_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['product_name']?.toString() ?? 'Product',
      soldQty: json['total_sold_qty'] ?? json['sold_qty'] ?? json['quantity'] ?? 0,
      currentStock: json['current_stock'] ?? json['stock_quantity'] ?? json['stock'] ?? 0,
      profitAmount: (json['total_profit'] ?? json['profit'] ?? json['profit_amount'] ?? 0.0).toDouble(),
      marginPct: (json['profit_margin_pct'] ?? json['margin'] ?? 0.0).toDouble(),
      daysInStock: json['days_in_stock'] ?? json['days_idle'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'total_sold_qty': soldQty,
      'current_stock': currentStock,
      'total_profit': profitAmount,
      'profit_margin_pct': marginPct,
      'days_in_stock': daysInStock,
    };
  }
}
