/// Model representing a permanent wholesale dealer / supplier in the merchant's directory.
class WholesalerModel {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String address;
  final String gstin;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WholesalerModel({
    required this.id,
    this.shopId = '',
    required this.name,
    this.phone = '',
    this.address = '',
    this.gstin = '',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory WholesalerModel.fromJson(Map<String, dynamic> json) {
    return WholesalerModel(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'name': name,
    'phone': phone,
    'address': address,
    'gstin': gstin,
    'notes': notes,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  WholesalerModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? address,
    String? gstin,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WholesalerModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
