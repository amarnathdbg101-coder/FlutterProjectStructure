import 'dart:convert';
import '../../../core/utils/image_utils.dart';

/// Formats raw database category codes / slugs into clean, human-readable Title Names
String formatCategoryName(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'General Store';

  final normalized = s.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  switch (normalized) {
    case 'general_store':
    case 'general':
      return 'General Store';
    case 'grocery_and_staples':
    case 'grocery_staples':
    case 'kirana_grocery':
    case 'grocery':
      return 'Grocery & Staples';
    case 'snacks_and_munchies':
    case 'snacks_munchies':
    case 'snacks_beverages':
    case 'snacks':
      return 'Snacks & Munchies';
    case 'beverages_and_drinks':
    case 'beverages_drinks':
    case 'beverages':
    case 'drinks':
      return 'Beverages & Drinks';
    case 'dairy_bakery_and_frozen':
    case 'dairy_and_bakery':
    case 'dairy_breakfast':
    case 'dairy_bakery':
    case 'dairy':
      return 'Dairy, Bakery & Frozen';
    case 'personal_care_and_beauty':
    case 'personal_care':
    case 'beauty':
      return 'Personal Care & Beauty';
    case 'household_and_cleaning':
    case 'household_cleaning':
    case 'household':
    case 'cleaning':
      return 'Household & Cleaning';
    case 'fruits_and_vegetables':
    case 'fruits_vegetables':
    case 'fruits':
    case 'vegetables':
      return 'Fruits & Vegetables';
    case 'electronics_and_appliances':
    case 'electronics_accessories':
    case 'electronics_appliances':
    case 'electronics':
      return 'Electronics & Appliances';
    case 'mobile_and_accessories':
    case 'mobile_accessories':
    case 'mobile':
      return 'Mobile & Accessories';
    case 'clothing_and_fashion':
    case 'clothing_apparel':
    case 'clothing_fashion':
    case 'clothing':
      return 'Clothing & Fashion';
    case 'footwear_and_leather':
    case 'footwear':
      return 'Footwear & Leather';
    case 'stationery_and_office_supplies':
    case 'stationery':
      return 'Stationery & Office Supplies';
    case 'hardware_and_building_material':
    case 'hardware':
      return 'Hardware & Building Material';
    case 'medicine_and_healthcare':
    case 'pharmacy_healthcare':
    case 'medicine':
    case 'healthcare':
      return 'Medicine & Healthcare';
    case 'toys_and_baby_products':
    case 'toys':
    case 'baby_products':
      return 'Toys & Baby Products';
    case 'sports_and_fitness':
    case 'sports':
      return 'Sports & Fitness';
    case 'automotive_and_spare_parts':
    case 'automotive':
      return 'Automotive & Spare Parts';
    case 'pet_supplies':
    case 'pets':
      return 'Pet Supplies';
    case 'services_and_others':
    case 'services':
    case 'others':
    case 'other':
      return 'Services & Others';
  }

  // Fallback: Title-Case hyphenated or underscored raw codes
  if (!s.contains('-') && !s.contains('_')) {
    return s;
  }

  return s
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.trim().isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

class ProductModel {
  final dynamic id;
  final String name;
  final String description;
  final String barcode;
  final String sku;
  final double price;
  final double costPrice;
  final double comparePrice;
  final double floorPrice;
  final bool allowBargain;
  final int stock;
  final String unit;
  final String category;
  final List<String> images;
  final int lowStockThreshold;
  final double weight;
  final bool isActive;
  final bool isFeatured;
  final bool isPricePublic;
  final Map<String, dynamic> attributes;

  ProductModel({
    required this.id,
    required this.name,
    this.description = '',
    this.barcode = '',
    this.sku = '',
    required this.price,
    this.costPrice = 0.0,
    this.comparePrice = 0.0,
    this.floorPrice = 0.0,
    this.allowBargain = false,
    required this.stock,
    this.unit = 'piece',
    required String category,
    this.images = const [],
    this.lowStockThreshold = 5,
    this.weight = 0.0,
    this.isActive = true,
    this.isFeatured = false,
    this.isPricePublic = true,
    this.attributes = const {},
  }) : category = formatCategoryName(category);

  bool get isLowStock => stock <= lowStockThreshold && stock > 0;
  bool get isOutOfStock => stock <= 0;
  String? get imageUrl {
    if (images.isEmpty) return null;
    for (final img in images) {
      if (isServerImageUrl(img)) return img;
    }
    return images.first;
  }

  double get profitAmount => (costPrice > 0 && price > costPrice) ? (price - costPrice) : 0.0;
  double get profitMarginPct => (costPrice > 0 && price > 0) ? ((price - costPrice) / price) * 100 : 0.0;
  bool get hasDiscount => comparePrice > price;
  double get discountPct => (comparePrice > price && comparePrice > 0) ? ((comparePrice - price) / comparePrice) * 100 : 0.0;

  ProductModel copyWith({
    dynamic id,
    String? name,
    String? description,
    String? barcode,
    String? sku,
    double? price,
    double? costPrice,
    double? comparePrice,
    double? floorPrice,
    bool? allowBargain,
    int? stock,
    String? unit,
    String? category,
    List<String>? images,
    int? lowStockThreshold,
    double? weight,
    bool? isActive,
    bool? isFeatured,
    bool? isPricePublic,
    Map<String, dynamic>? attributes,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      comparePrice: comparePrice ?? this.comparePrice,
      floorPrice: floorPrice ?? this.floorPrice,
      allowBargain: allowBargain ?? this.allowBargain,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      images: images ?? this.images,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      weight: weight ?? this.weight,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      isPricePublic: isPricePublic ?? this.isPricePublic,
      attributes: attributes ?? this.attributes,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<String> imgList = [];
    void extractImg(dynamic v) {
      if (v == null) return;
      if (v is List) {
        for (final item in v) {
          extractImg(item);
        }
        return;
      }
      final s = v.toString().trim();
      if (s.isEmpty) return;
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            for (final item in decoded) {
              extractImg(item);
            }
            return;
          }
        } catch (_) {}
      }
      if (!imgList.contains(s)) {
        imgList.add(s);
      }
    }

    extractImg(json['images']);
    extractImg(json['image_url']);
    extractImg(json['image']);
    extractImg(json['urls']);
    extractImg(json['photos']);
    extractImg(json['thumbnail']);

    Map<String, dynamic> attrMap = {};
    if (json['attributes'] is Map) {
      attrMap = Map<String, dynamic>.from(json['attributes'] as Map);
    }

    double parseDouble(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool parseBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return fallback;
    }

    // Stock resolution
    int resolvedStock = 0;
    if (json['stock_quantity'] != null) {
      resolvedStock = parseInt(json['stock_quantity'], 0);
    } else if (json['available_quantity'] != null) {
      resolvedStock = parseInt(json['available_quantity'], 0);
    } else if (json['stock'] != null) {
      resolvedStock = parseInt(json['stock'], 0);
    } else if (json['quantity'] != null) {
      resolvedStock = parseInt(json['quantity'], 0);
    } else if (json['inventory'] is Map) {
      final inv = json['inventory'] as Map;
      resolvedStock = parseInt(inv['available_quantity'] ?? inv['quantity'], 0);
    }

    // Unit resolution
    String resolvedUnit = 'piece';
    if (json['unit'] != null && json['unit'].toString().trim().isNotEmpty) {
      resolvedUnit = json['unit'].toString().trim();
    } else if (attrMap['unit'] != null && attrMap['unit'].toString().trim().isNotEmpty) {
      resolvedUnit = attrMap['unit'].toString().trim();
    }

    // Category display resolution with automatic Code/Slug -> Name formatting
    String rawCategory = 'General Store';
    if (json['category_name'] != null && json['category_name'].toString().trim().isNotEmpty) {
      rawCategory = json['category_name'].toString().trim();
    } else if (json['category'] is Map && (json['category'] as Map)['name'] != null) {
      rawCategory = (json['category'] as Map)['name'].toString().trim();
    } else if (json['category'] is String && json['category'].toString().trim().isNotEmpty) {
      rawCategory = json['category'].toString().trim();
    } else if (json['category_id'] != null && json['category_id'].toString().trim().isNotEmpty) {
      rawCategory = json['category_id'].toString().trim();
    }

    return ProductModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? json['title'] ?? 'Product',
      description: json['description']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? json['sku']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      price: parseDouble(json['price'] ?? json['sellingPrice'], 0.0),
      costPrice: parseDouble(json['cost_price'] ?? json['purchasingPrice'] ?? json['purchase_price'], 0.0),
      comparePrice: parseDouble(json['compare_price'] ?? json['mrp'], 0.0),
      floorPrice: parseDouble(json['floor_price'], 0.0),
      allowBargain: parseBool(json['allow_bargain'], false),
      stock: resolvedStock,
      unit: resolvedUnit,
      category: rawCategory,
      images: imgList,
      lowStockThreshold: parseInt(json['min_stock'] ?? json['low_stock_threshold'], 5),
      weight: parseDouble(json['weight'], 0.0),
      isActive: parseBool(json['is_active'], true),
      isFeatured: parseBool(json['is_featured'], false),
      isPricePublic: parseBool(json['is_price_public'], true),
      attributes: attrMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'name': name,
      'description': description,
      'barcode': barcode,
      'sku': sku,
      'price': price,
      'sellingPrice': price,
      'cost_price': costPrice,
      'purchasingPrice': costPrice,
      'compare_price': comparePrice,
      'mrp': comparePrice,
      'floor_price': floorPrice,
      'allow_bargain': allowBargain,
      'stock': stock,
      'stock_quantity': stock,
      'min_stock': lowStockThreshold,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'category_id': category.toLowerCase().replaceAll(' ', '_'),
      'category': category,
      'images': images,
      'image_url': imageUrl ?? '',
      'weight': weight,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_price_public': isPricePublic,
      'attributes': attributes,
    };
  }
}
