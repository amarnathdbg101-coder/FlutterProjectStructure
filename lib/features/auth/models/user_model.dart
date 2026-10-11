import '../../../core/utils/date_time_utils.dart';

class UserModel {
  final dynamic id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  bool get isMerchant =>
      role == 'shop' || role == 'merchant' || role == 'admin' || role == 'owner';

  UserModel copyWith({
    dynamic id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['full_name'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString() ?? json['mobile']?.toString() ?? '',
      role: json['role'] ?? 'shop',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
      createdAt: AppDateTimeUtils.parseToLocalNullable(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar_url': avatarUrl,
      'avatar': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
