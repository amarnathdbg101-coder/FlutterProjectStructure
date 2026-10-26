class CategoryItemModel {
  final String id;
  final String name;
  final String slug;
  final String icon;
  final String description;
  final String imageUrl;
  final String? shopId;
  final bool isCustom;
  final bool isActive;
  final int productCount;
  final String createdAt;

  const CategoryItemModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon = '📦',
    this.description = '',
    this.imageUrl = '',
    this.shopId,
    this.isCustom = false,
    this.isActive = true,
    this.productCount = 0,
    this.createdAt = '',
  });

  String get displayName => icon.isNotEmpty ? '$icon $name' : name;

  factory CategoryItemModel.fromJson(Map<String, dynamic> json) {
    final rawCustom = json['is_custom'];
    final bool isCustom = rawCustom is bool
        ? rawCustom
        : (rawCustom == 1 || rawCustom == 'true' || json['shop_id'] != null);

    final rawActive = json['is_active'];
    final bool isActive = rawActive is bool
        ? rawActive
        : (rawActive == 1 || rawActive == 'true' || rawActive == null);

    final rawCount = json['product_count'];
    final int count = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '0') ?? 0;

    return CategoryItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      icon: (json['icon']?.toString().trim().isNotEmpty ?? false)
          ? json['icon'].toString().trim()
          : '📦',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      shopId: json['shop_id']?.toString(),
      isCustom: isCustom,
      isActive: isActive,
      productCount: count,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
      'description': description,
      'image_url': imageUrl,
      'shop_id': shopId,
      'is_custom': isCustom,
      'is_active': isActive,
      'product_count': productCount,
      'created_at': createdAt,
    };
  }

  CategoryItemModel copyWith({
    String? id,
    String? name,
    String? slug,
    String? icon,
    String? description,
    String? imageUrl,
    String? shopId,
    bool? isCustom,
    bool? isActive,
    int? productCount,
    String? createdAt,
  }) {
    return CategoryItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      shopId: shopId ?? this.shopId,
      isCustom: isCustom ?? this.isCustom,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
