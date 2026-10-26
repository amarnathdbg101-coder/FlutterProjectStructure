import '../../../core/utils/date_time_utils.dart';

class OfferModel {
  final String id;
  final String shopId;
  final String title;
  final String discountText;
  final String description;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue; // 10 (%) or 50 (₹)
  final double minOrderAmount;
  final double maxDiscount;
  final String applicableDays; // 'all' or 'sunday,tuesday'
  final String bannerTag; // '🔥 Special Offer', '⚡ Flash Deal'
  final String promoCode;
  final int minPointsRequired;
  final int expiresInDays;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfferModel({
    required this.id,
    this.shopId = '',
    required this.title,
    required this.discountText,
    this.description = '',
    this.discountType = 'percentage',
    this.discountValue = 0.0,
    this.minOrderAmount = 0.0,
    this.maxDiscount = 0.0,
    this.applicableDays = 'all',
    this.bannerTag = '🔥 Special Offer',
    this.promoCode = '',
    this.minPointsRequired = 0,
    this.expiresInDays = 7,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApplicableToday {
    if (applicableDays.isEmpty || applicableDays.toLowerCase() == 'all') {
      return true;
    }
    const daysMap = {
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    };
    final today = daysMap[DateTime.now().weekday] ?? '';
    return applicableDays.toLowerCase().contains(today);
  }

  OfferModel copyWith({
    String? id,
    String? shopId,
    String? title,
    String? discountText,
    String? description,
    String? discountType,
    double? discountValue,
    double? minOrderAmount,
    double? maxDiscount,
    String? applicableDays,
    String? bannerTag,
    String? promoCode,
    int? minPointsRequired,
    int? expiresInDays,
    bool? isActive,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      discountText: discountText ?? this.discountText,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      applicableDays: applicableDays ?? this.applicableDays,
      bannerTag: bannerTag ?? this.bannerTag,
      promoCode: promoCode ?? this.promoCode,
      minPointsRequired: minPointsRequired ?? this.minPointsRequired,
      expiresInDays: expiresInDays ?? this.expiresInDays,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    final discVal = json['discount_value'] ?? json['discountValue'];
    final minOrd = json['min_order_amount'] ?? json['minOrderAmount'];
    final maxDisc = json['max_discount'] ?? json['maxDiscount'];

    return OfferModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? json['shopId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      discountText: json['discount_text']?.toString() ?? json['discountText']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? json['discountType']?.toString() ?? 'percentage',
      discountValue: discVal != null ? (discVal is num ? discVal.toDouble() : double.tryParse(discVal.toString()) ?? 0.0) : 0.0,
      minOrderAmount: minOrd != null ? (minOrd is num ? minOrd.toDouble() : double.tryParse(minOrd.toString()) ?? 0.0) : 0.0,
      maxDiscount: maxDisc != null ? (maxDisc is num ? maxDisc.toDouble() : double.tryParse(maxDisc.toString()) ?? 0.0) : 0.0,
      applicableDays: json['applicable_days']?.toString() ?? json['applicableDays']?.toString() ?? 'all',
      bannerTag: json['banner_tag']?.toString() ?? json['bannerTag']?.toString() ?? '🔥 Special Offer',
      promoCode: json['promo_code']?.toString() ?? json['promoCode']?.toString() ?? '',
      minPointsRequired: json['min_points_required'] ?? json['minPointsRequired'] ?? 0,
      expiresInDays: json['expires_in_days'] ?? 7,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      expiresAt: AppDateTimeUtils.parseToLocalNullable(json['expires_at']),
      createdAt: AppDateTimeUtils.parseToLocalNullable(json['created_at']),
      updatedAt: AppDateTimeUtils.parseToLocalNullable(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'title': title,
      'discount_text': discountText,
      'description': description,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount': maxDiscount,
      'applicable_days': applicableDays,
      'banner_tag': bannerTag,
      'promo_code': promoCode,
      'min_points_required': minPointsRequired,
      'expires_in_days': expiresInDays,
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
