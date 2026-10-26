class ShopModel {
  final dynamic id;
  final String name;
  final String description;
  final String slug;
  final String category;
  final String address;
  final String city;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String phone;
  final String whatsappNumber;
  final bool isOpen;
  final String? upiId;
  final String openingTime;
  final String closingTime;
  final String weeklyOff;
  final String timing;
  final String status;
  final String? logoUrl;
  final List<String> banners;
  final double rating;

  ShopModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.slug,
    this.category = 'General Store',
    this.address = '',
    this.city = '',
    this.pincode = '',
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.phone = '',
    this.whatsappNumber = '',
    this.isOpen = true,
    this.upiId,
    this.openingTime = '09:00 AM',
    this.closingTime = '09:00 PM',
    this.weeklyOff = '',
    this.timing = '',
    this.status = 'active',
    this.logoUrl,
    this.banners = const [],
    this.rating = 0.0,
  });

  String? get bannerUrl => banners.isNotEmpty ? banners.first : logoUrl;
  String get gstin => '';

  bool get hasGpsCoordinates => latitude != null && longitude != null && latitude != 0 && longitude != 0;

  String get formattedGps => hasGpsCoordinates
      ? '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'
      : 'No GPS Pin Set';

  String get fullAddress {
    final parts = <String>[];
    if (address.trim().isNotEmpty) parts.add(address.trim());
    if (city.trim().isNotEmpty) parts.add(city.trim());
    if (pincode.trim().isNotEmpty) parts.add(pincode.trim());
    return parts.isEmpty ? 'Address not specified' : parts.join(', ');
  }

  String get formattedTimings {
    if (timing.trim().isNotEmpty) return timing.trim();
    if (openingTime.trim().isNotEmpty && closingTime.trim().isNotEmpty) {
      return '${openingTime.trim()} - ${closingTime.trim()}';
    }
    return '09:00 AM - 09:00 PM';
  }

  ShopModel copyWith({
    dynamic id,
    String? name,
    String? description,
    String? slug,
    String? category,
    String? address,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    String? googleMapsUrl,
    String? phone,
    String? whatsappNumber,
    bool? isOpen,
    String? upiId,
    String? openingTime,
    String? closingTime,
    String? weeklyOff,
    String? timing,
    String? status,
    String? logoUrl,
    List<String>? banners,
    double? rating,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      isOpen: isOpen ?? this.isOpen,
      upiId: upiId ?? this.upiId,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      weeklyOff: weeklyOff ?? this.weeklyOff,
      timing: timing ?? this.timing,
      status: status ?? this.status,
      logoUrl: logoUrl ?? this.logoUrl,
      banners: banners ?? this.banners,
      rating: rating ?? this.rating,
    );
  }

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    List<String> bList = [];
    if (json['banners'] is List) {
      bList = (json['banners'] as List).map((e) => e.toString()).toList();
    } else if (json['banner_url'] != null && json['banner_url'].toString().isNotEmpty) {
      bList = [json['banner_url'].toString()];
    }

    return ShopModel(
      id: json['id'] ?? '',
      name: json['name'] ?? json['shop_name'] ?? 'ShopSilo Store',
      description: json['description']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      category: json['category'] ?? json['business_category'] ?? 'General Store',
      address: json['address'] ?? json['store_address'] ?? '',
      city: json['city']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : (json['lat'] is num) ? (json['lat'] as num).toDouble() : double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : (json['lng'] is num) ? (json['lng'] as num).toDouble() : double.tryParse(json['longitude']?.toString() ?? ''),
      googleMapsUrl: json['google_maps_url']?.toString() ?? json['maps_url']?.toString(),
      phone: json['phone']?.toString() ?? json['contact_phone']?.toString() ?? '',
      whatsappNumber: json['whatsapp_number']?.toString() ?? json['whatsapp']?.toString() ?? '',
      isOpen: json['is_currently_open'] ?? json['is_open'] ?? true,
      upiId: json['upi_id'] ?? json['upi_vpa'],
      openingTime: json['opening_time']?.toString() ?? '09:00 AM',
      closingTime: json['closing_time']?.toString() ?? '09:00 PM',
      weeklyOff: json['weekly_off']?.toString() ?? '',
      timing: json['timing']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      logoUrl: json['logo_url'] ?? json['image_url'],
      banners: bList,
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'slug': slug,
      'category': category,
      'address': address,
      'city': city,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'google_maps_url': googleMapsUrl,
      'phone': phone,
      'whatsapp_number': whatsappNumber,
      'is_open': isOpen,
      'is_currently_open': isOpen,
      'upi_id': upiId,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'weekly_off': weeklyOff,
      'timing': timing,
      'status': status,
      'logo_url': logoUrl,
      'banners': banners,
      'rating': rating,
    };
  }
}
