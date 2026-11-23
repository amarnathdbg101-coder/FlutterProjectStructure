import 'dart:convert';

/// Daily high-impact prescription card in the Morning 3-Action Brief.
class DailyPrescriptionModel {
  final String id;
  final String shopId;
  final String urgencyTier; // URGENT_CASH, STOCKOUT_CRITICAL, KHATA_RECOVERY
  final String category;    // DEAD_STOCK, REORDER, PROMO, NEGOTIATION
  final String headline;
  final String explanation;
  final double financialImpactINR;
  final String executableActionType;
  final Map<String, dynamic> actionPayload;
  final bool isExecuted;
  final DateTime? executedAt;
  final DateTime createdAt;

  const DailyPrescriptionModel({
    required this.id,
    required this.shopId,
    required this.urgencyTier,
    required this.category,
    required this.headline,
    required this.explanation,
    required this.financialImpactINR,
    required this.executableActionType,
    required this.actionPayload,
    this.isExecuted = false,
    this.executedAt,
    required this.createdAt,
  });

  factory DailyPrescriptionModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedPayload = {};
    if (json['action_payload'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['action_payload'] as Map);
    } else if (json['action_payload'] is String && (json['action_payload'] as String).isNotEmpty) {
      try {
        parsedPayload = Map<String, dynamic>.from(jsonDecode(json['action_payload'] as String) as Map);
      } catch (_) {}
    }

    return DailyPrescriptionModel(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      urgencyTier: json['urgency_tier']?.toString() ?? 'MEDIUM',
      category: json['category']?.toString() ?? 'GENERAL',
      headline: json['headline']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      financialImpactINR: (json['financial_impact_inr'] as num?)?.toDouble() ?? 0.0,
      executableActionType: json['executable_action_type']?.toString() ?? '',
      actionPayload: parsedPayload,
      isExecuted: json['is_executed'] == true,
      executedAt: json['executed_at'] != null ? DateTime.tryParse(json['executed_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'urgency_tier': urgencyTier,
    'category': category,
    'headline': headline,
    'explanation': explanation,
    'financial_impact_inr': financialImpactINR,
    'executable_action_type': executableActionType,
    'action_payload': actionPayload,
    'is_executed': isExecuted,
    'executed_at': executedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  DailyPrescriptionModel copyWith({bool? isExecuted, DateTime? executedAt}) {
    return DailyPrescriptionModel(
      id: id,
      shopId: shopId,
      urgencyTier: urgencyTier,
      category: category,
      headline: headline,
      explanation: explanation,
      financialImpactINR: financialImpactINR,
      executableActionType: executableActionType,
      actionPayload: actionPayload,
      isExecuted: isExecuted ?? this.isExecuted,
      executedAt: executedAt ?? this.executedAt,
      createdAt: createdAt,
    );
  }
}

/// Product Intelligence Model holding ABC-XYZ demand tiers and dead capital metrics.
class ProductIntelligenceModel {
  final String id;
  final String productId;
  final String shopId;
  final String productName;
  final double productPrice;
  final double costPrice;
  final double floorPrice;
  final int currentStock;
  final String categoryName;
  final String abcTier;
  final String xyzTier;
  final double velocityDaily;
  final int daysOfSupply;
  final int daysSinceLastSale;
  final bool isDeadStock;
  final double carryingCostMonthly;
  final int clearanceStage;
  final String recommendedAction;
  final double recommendedMinPrice;

  const ProductIntelligenceModel({
    required this.id,
    required this.productId,
    required this.shopId,
    required this.productName,
    required this.productPrice,
    required this.costPrice,
    required this.floorPrice,
    required this.currentStock,
    required this.categoryName,
    required this.abcTier,
    required this.xyzTier,
    required this.velocityDaily,
    required this.daysOfSupply,
    required this.daysSinceLastSale,
    required this.isDeadStock,
    required this.carryingCostMonthly,
    required this.clearanceStage,
    required this.recommendedAction,
    required this.recommendedMinPrice,
  });

  factory ProductIntelligenceModel.fromJson(Map<String, dynamic> json) {
    return ProductIntelligenceModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productPrice: (json['product_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      floorPrice: (json['floor_price'] as num?)?.toDouble() ?? 0.0,
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      categoryName: json['category_name']?.toString() ?? 'General',
      abcTier: json['abc_tier']?.toString() ?? 'C',
      xyzTier: json['xyz_tier']?.toString() ?? 'Z',
      velocityDaily: (json['velocity_daily'] as num?)?.toDouble() ?? 0.0,
      daysOfSupply: (json['days_of_supply'] as num?)?.toInt() ?? 999,
      daysSinceLastSale: (json['days_since_last_sale'] as num?)?.toInt() ?? 0,
      isDeadStock: json['is_dead_stock'] == true,
      carryingCostMonthly: (json['carrying_cost_monthly'] as num?)?.toDouble() ?? 0.0,
      clearanceStage: (json['clearance_stage'] as num?)?.toInt() ?? 0,
      recommendedAction: json['recommended_action']?.toString() ?? '',
      recommendedMinPrice: (json['recommended_min_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'shop_id': shopId,
    'product_name': productName,
    'product_price': productPrice,
    'cost_price': costPrice,
    'floor_price': floorPrice,
    'current_stock': currentStock,
    'category_name': categoryName,
    'abc_tier': abcTier,
    'xyz_tier': xyzTier,
    'velocity_daily': velocityDaily,
    'days_of_supply': daysOfSupply,
    'days_since_last_sale': daysSinceLastSale,
    'is_dead_stock': isDeadStock,
    'carrying_cost_monthly': carryingCostMonthly,
    'clearance_stage': clearanceStage,
    'recommended_action': recommendedAction,
    'recommended_min_price': recommendedMinPrice,
  };
}

/// Dead Capital Summary for the store.
class DeadCapitalSummaryModel {
  final int totalDeadStockItems;
  final double totalBlockedCapitalINR;
  final double monthlyCarryingCostLoss;
  final double recoverableCashINR;
  final List<ProductIntelligenceModel> deadStockItems;

  const DeadCapitalSummaryModel({
    required this.totalDeadStockItems,
    required this.totalBlockedCapitalINR,
    required this.monthlyCarryingCostLoss,
    required this.recoverableCashINR,
    required this.deadStockItems,
  });

  factory DeadCapitalSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['dead_stock_items'] as List?;
    final items = rawList != null
        ? rawList
            .whereType<Map>()
            .map((m) => ProductIntelligenceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <ProductIntelligenceModel>[];

    return DeadCapitalSummaryModel(
      totalDeadStockItems: (json['total_dead_stock_items'] as num?)?.toInt() ?? 0,
      totalBlockedCapitalINR: (json['total_blocked_capital_inr'] as num?)?.toDouble() ?? 0.0,
      monthlyCarryingCostLoss: (json['monthly_carrying_cost_loss'] as num?)?.toDouble() ?? 0.0,
      recoverableCashINR: (json['recoverable_cash_inr'] as num?)?.toDouble() ?? 0.0,
      deadStockItems: items,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_dead_stock_items': totalDeadStockItems,
    'total_blocked_capital_inr': totalBlockedCapitalINR,
    'monthly_carrying_cost_loss': monthlyCarryingCostLoss,
    'recoverable_cash_inr': recoverableCashINR,
    'dead_stock_items': deadStockItems.map((i) => i.toJson()).toList(),
  };
}

/// Real-time margin-aware evaluation of customer price bargaining.
class BargainEvaluationModel {
  final String productId;
  final String productName;
  final double originalPrice;
  final double customerOfferedPrice;
  final double costPrice;
  final double hardFloorPrice;
  final bool isAcceptable;
  final double suggestedCounterOffer;
  final double netProfitINR;
  final int inventoryAgeDays;
  final String abcTier;
  final String xyzTier;
  final String customerRFM;
  final String salesScript;
  final String warningMessage;

  const BargainEvaluationModel({
    required this.productId,
    required this.productName,
    required this.originalPrice,
    required this.customerOfferedPrice,
    required this.costPrice,
    required this.hardFloorPrice,
    required this.isAcceptable,
    required this.suggestedCounterOffer,
    required this.netProfitINR,
    required this.inventoryAgeDays,
    required this.abcTier,
    required this.xyzTier,
    required this.customerRFM,
    required this.salesScript,
    this.warningMessage = '',
  });

  factory BargainEvaluationModel.fromJson(Map<String, dynamic> json) {
    return BargainEvaluationModel(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0.0,
      customerOfferedPrice: (json['customer_offered_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      hardFloorPrice: (json['hard_floor_price'] as num?)?.toDouble() ?? 0.0,
      isAcceptable: json['is_acceptable'] == true,
      suggestedCounterOffer: (json['suggested_counter_offer'] as num?)?.toDouble() ?? 0.0,
      netProfitINR: (json['net_profit_inr'] as num?)?.toDouble() ?? 0.0,
      inventoryAgeDays: (json['inventory_age_days'] as num?)?.toInt() ?? 0,
      abcTier: json['abc_tier']?.toString() ?? 'C',
      xyzTier: json['xyz_tier']?.toString() ?? 'Z',
      customerRFM: json['customer_rfm']?.toString() ?? 'REGULAR',
      salesScript: json['sales_script']?.toString() ?? '',
      warningMessage: json['warning_message']?.toString() ?? '',
    );
  }
}

/// Substitute Recommendation model for clothes/cosmetics.
class SubstituteRecommendationModel {
  final String productId;
  final String productName;
  final String categoryName;
  final int currentStock;
  final double mrp;
  final double offerPrice;
  final double shopProfitMargin;
  final double matchScore;
  final bool isExactMatch;
  final List<String> matchedAttributes;
  final String salesPitchScript;

  const SubstituteRecommendationModel({
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.currentStock,
    required this.mrp,
    required this.offerPrice,
    required this.shopProfitMargin,
    required this.matchScore,
    required this.isExactMatch,
    required this.matchedAttributes,
    required this.salesPitchScript,
  });

  factory SubstituteRecommendationModel.fromJson(Map<String, dynamic> json) {
    final rawAttrs = json['matched_attributes'] as List?;
    final attrs = rawAttrs != null ? rawAttrs.map((e) => e.toString()).toList() : <String>[];

    return SubstituteRecommendationModel(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? 'General',
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      offerPrice: (json['offer_price'] as num?)?.toDouble() ?? 0.0,
      shopProfitMargin: (json['shop_profit_margin'] as num?)?.toDouble() ?? 0.0,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      isExactMatch: json['is_exact_match'] == true,
      matchedAttributes: attrs,
      salesPitchScript: json['sales_pitch_script']?.toString() ?? '',
    );
  }
}
