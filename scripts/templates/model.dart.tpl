class __PASCAL__Model {
  final dynamic id;
  final String title;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  __PASCAL__Model({
    required this.id,
    required this.title,
    required this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory __PASCAL__Model.fromJson(Map<String, dynamic> json) {
    return __PASCAL__Model(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
    };
  }
}
