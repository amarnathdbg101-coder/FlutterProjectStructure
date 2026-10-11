import '../../../core/utils/date_time_utils.dart';

class ProductsModel {
  final dynamic id;
  final String title;
  final String description;
  final String sellingPrice;
  final String purchasingPrice;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.sellingPrice,
    required this.purchasingPrice,
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductsModel.fromJson(Map<String, dynamic> json) {
    return ProductsModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      sellingPrice: json['selling_price'] ?? '',
      purchasingPrice: json['purchasing_price'] ?? '',
      image: json['image_url'],
      createdAt: AppDateTimeUtils.parseToLocalNullable(json['created_at']),
      updatedAt: AppDateTimeUtils.parseToLocalNullable(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'selling_price': sellingPrice,
      'purchasing_price': purchasingPrice,
      'image_url': image,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

