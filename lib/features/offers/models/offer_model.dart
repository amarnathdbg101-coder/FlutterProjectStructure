class OfferModel {
  final String id;
  final String title;
  final String discountText;
  final String description;
  final int expiresInDays;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  OfferModel({
    required this.id,
    required this.title,
    required this.discountText,
    required this.description,
    this.expiresInDays = 7,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      discountText: json['discount_text']?.toString() ?? json['discountText']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      expiresInDays: json['expires_in_days'] ?? 7,
      isActive: json['is_active'] ?? true,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'discount_text': discountText,
      'description': description,
      'expires_in_days': expiresInDays,
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
