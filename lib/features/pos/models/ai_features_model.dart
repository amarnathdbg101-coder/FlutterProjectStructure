// ShopSilo AI Layer Models
// Covers:
// 1. Photo-to-Inventory OCR Ingestion (Supplier Invoice)
// 2. Real-Time Counter Cross-Sell Script
// 3. Dead-Stock Liquidation Combo Bundles
// 4. Psychology-Based Khata Recovery Nudges
// 5. Hinglish Voice-to-Bill Assistant
// 6. Festive Digital Marketing Posters & Copy

// 1. Supplier Invoice OCR Ingestion
class SupplierInvoiceItem {
  final String productName;
  final String batchNumber;
  final String expiryDate;
  final int quantity;
  final double unitCost;
  final double suggestedMRP;
  final double gstPercent;
  final double totalPrice;

  SupplierInvoiceItem({
    required this.productName,
    this.batchNumber = '',
    this.expiryDate = '',
    required this.quantity,
    required this.unitCost,
    required this.suggestedMRP,
    this.gstPercent = 0.0,
    required this.totalPrice,
  });

  factory SupplierInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SupplierInvoiceItem(
      productName: json['product_name']?.toString() ?? '',
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      suggestedMRP: (json['suggested_mrp'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (json['gst_percent'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'batch_number': batchNumber,
        'expiry_date': expiryDate,
        'quantity': quantity,
        'unit_cost': unitCost,
        'suggested_mrp': suggestedMRP,
        'gst_percent': gstPercent,
        'total_price': totalPrice,
      };
}

class SupplierInvoiceResponse {
  final String distributorName;
  final String distributorPhone;
  final String invoiceNumber;
  final String invoiceDate;
  final double totalAmount;
  final List<SupplierInvoiceItem> items;
  final String extractedNotes;

  SupplierInvoiceResponse({
    required this.distributorName,
    this.distributorPhone = '',
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    required this.items,
    this.extractedNotes = '',
  });

  factory SupplierInvoiceResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<SupplierInvoiceItem> list = [];
    if (rawItems is List) {
      list = rawItems.map((e) => SupplierInvoiceItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return SupplierInvoiceResponse(
      distributorName: json['distributor_name']?.toString() ?? '',
      distributorPhone: json['distributor_phone']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      invoiceDate: json['invoice_date']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items: list,
      extractedNotes: json['extracted_notes']?.toString() ?? '',
    );
  }
}

// 2. Real-Time Counter Cross-Sell & Look-Stylist
class CrossSellSuggestion {
  final String suggestedProductName;
  final String category;
  final double estimatedPrice;
  final double marginBoost;
  final String cashierScriptHinglish;
  final String reason;

  CrossSellSuggestion({
    required this.suggestedProductName,
    required this.category,
    required this.estimatedPrice,
    required this.marginBoost,
    required this.cashierScriptHinglish,
    required this.reason,
  });

  factory CrossSellSuggestion.fromJson(Map<String, dynamic> json) {
    return CrossSellSuggestion(
      suggestedProductName: json['suggested_product_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0.0,
      marginBoost: (json['margin_boost'] as num?)?.toDouble() ?? 0.0,
      cashierScriptHinglish: json['cashier_script_hinglish']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class CrossSellResponse {
  final String scannedProduct;
  final List<CrossSellSuggestion> recommendations;

  CrossSellResponse({
    required this.scannedProduct,
    required this.recommendations,
  });

  factory CrossSellResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['recommendations'];
    List<CrossSellSuggestion> list = [];
    if (raw is List) {
      list = raw.map((e) => CrossSellSuggestion.fromJson(e as Map<String, dynamic>)).toList();
    }
    return CrossSellResponse(
      scannedProduct: json['scanned_product']?.toString() ?? '',
      recommendations: list,
    );
  }
}

// 3. Dead-Stock Liquidation Combo Bundles
class DeadStockBundle {
  final String bundleName;
  final String slowMovingItem;
  final String fastMovingAnchor;
  final double originalTotal;
  final double bundlePrice;
  final double customerSavings;
  final double estimatedProfit;
  final String pitchLineHinglish;

  DeadStockBundle({
    required this.bundleName,
    required this.slowMovingItem,
    required this.fastMovingAnchor,
    required this.originalTotal,
    required this.bundlePrice,
    required this.customerSavings,
    required this.estimatedProfit,
    required this.pitchLineHinglish,
  });

  factory DeadStockBundle.fromJson(Map<String, dynamic> json) {
    return DeadStockBundle(
      bundleName: json['bundle_name']?.toString() ?? '',
      slowMovingItem: json['slow_moving_item']?.toString() ?? '',
      fastMovingAnchor: json['fast_moving_anchor']?.toString() ?? '',
      originalTotal: (json['original_total'] as num?)?.toDouble() ?? 0.0,
      bundlePrice: (json['bundle_price'] as num?)?.toDouble() ?? 0.0,
      customerSavings: (json['customer_savings'] as num?)?.toDouble() ?? 0.0,
      estimatedProfit: (json['estimated_profit'] as num?)?.toDouble() ?? 0.0,
      pitchLineHinglish: json['pitch_line_hinglish']?.toString() ?? '',
    );
  }
}

class DeadStockResponse {
  final List<DeadStockBundle> suggestedBundles;

  DeadStockResponse({required this.suggestedBundles});

  factory DeadStockResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['suggested_bundles'];
    List<DeadStockBundle> list = [];
    if (raw is List) {
      list = raw.map((e) => DeadStockBundle.fromJson(e as Map<String, dynamic>)).toList();
    }
    return DeadStockResponse(suggestedBundles: list);
  }
}

// 4. Respectful Psychology-Based Khata Recovery Nudges
class RecoveryNudgeResponse {
  final String customerName;
  final String gentleNudge;
  final String microPlanNudge;
  final String formalNotice;
  final String upiPaymentLink;

  RecoveryNudgeResponse({
    required this.customerName,
    required this.gentleNudge,
    required this.microPlanNudge,
    required this.formalNotice,
    required this.upiPaymentLink,
  });

  factory RecoveryNudgeResponse.fromJson(Map<String, dynamic> json) {
    return RecoveryNudgeResponse(
      customerName: json['customer_name']?.toString() ?? '',
      gentleNudge: json['gentle_nudge']?.toString() ?? '',
      microPlanNudge: json['micro_plan_nudge']?.toString() ?? '',
      formalNotice: json['formal_notice']?.toString() ?? '',
      upiPaymentLink: json['upi_payment_link']?.toString() ?? '',
    );
  }
}

// 5. Hinglish Voice-to-Bill Assistant
class VoiceBillItem {
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  VoiceBillItem({
    this.productId = '',
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory VoiceBillItem.fromJson(Map<String, dynamic> json) {
    return VoiceBillItem(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit']?.toString() ?? 'pkt',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VoiceBillResponse {
  final String spokenText;
  final List<VoiceBillItem> matchedItems;
  final List<String> unmatchedText;
  final double totalAmount;

  VoiceBillResponse({
    required this.spokenText,
    required this.matchedItems,
    required this.unmatchedText,
    required this.totalAmount,
  });

  factory VoiceBillResponse.fromJson(Map<String, dynamic> json) {
    final rawMatched = json['matched_items'];
    List<VoiceBillItem> matched = [];
    if (rawMatched is List) {
      matched = rawMatched.map((e) => VoiceBillItem.fromJson(e as Map<String, dynamic>)).toList();
    }

    final rawUnmatched = json['unmatched_text'];
    List<String> unmatched = [];
    if (rawUnmatched is List) {
      unmatched = rawUnmatched.map((e) => e.toString()).toList();
    }

    return VoiceBillResponse(
      spokenText: json['spoken_text']?.toString() ?? '',
      matchedItems: matched,
      unmatchedText: unmatched,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// 6. Festive Digital Marketing Posters & Copy
class MarketingCampaignResponse {
  final String headline;
  final String whatsappMessage;
  final String socialPostText;
  final List<String> suggestedHashtags;

  MarketingCampaignResponse({
    required this.headline,
    required this.whatsappMessage,
    required this.socialPostText,
    required this.suggestedHashtags,
  });

  factory MarketingCampaignResponse.fromJson(Map<String, dynamic> json) {
    final rawTags = json['suggested_hashtags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }
    return MarketingCampaignResponse(
      headline: json['headline']?.toString() ?? '',
      whatsappMessage: json['whatsapp_message']?.toString() ?? '',
      socialPostText: json['social_post_text']?.toString() ?? '',
      suggestedHashtags: tags,
    );
  }
}

