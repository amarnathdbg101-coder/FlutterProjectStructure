/// Model representing an individual Gemini API Key entry stored securely in local vault.
class ApiKeyEntry {
  final String id;
  final String key;
  final String label;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool isRateLimited;
  final DateTime? rateLimitedAt;
  final int totalRequests;

  const ApiKeyEntry({
    required this.id,
    required this.key,
    required this.label,
    required this.createdAt,
    this.lastUsedAt,
    this.isRateLimited = false,
    this.rateLimitedAt,
    this.totalRequests = 0,
  });

  factory ApiKeyEntry.create({
    required String key,
    String? label,
    int existingCount = 0,
  }) {
    final cleanKey = key.trim();
    final now = DateTime.now();
    final generatedLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : 'Key #${existingCount + 1} (${cleanKey.length >= 8 ? cleanKey.substring(0, 6) : "Gemini"})';

    return ApiKeyEntry(
      id: 'key_${now.millisecondsSinceEpoch}_${now.microsecond}',
      key: cleanKey,
      label: generatedLabel,
      createdAt: now,
      lastUsedAt: null,
      isRateLimited: false,
      rateLimitedAt: null,
      totalRequests: 0,
    );
  }

  String get maskedKey {
    final clean = key.trim();
    if (clean.length < 12) {
      return '••••••••';
    }
    final start = clean.substring(0, 6);
    final end = clean.substring(clean.length - 4);
    return '$start••••••••$end';
  }

  bool get isValidFormat {
    final clean = key.trim();
    return clean.length >= 25 && clean.startsWith('AIza');
  }

  bool get isStillRateLimited {
    if (!isRateLimited || rateLimitedAt == null) return false;
    final diff = DateTime.now().difference(rateLimitedAt!);
    return diff.inMinutes < 60;
  }

  factory ApiKeyEntry.fromJson(Map<String, dynamic> json) {
    return ApiKeyEntry(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? 'Gemini Key').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
      isRateLimited: (json['is_rate_limited'] ?? false) as bool,
      rateLimitedAt: json['rate_limited_at'] != null
          ? DateTime.tryParse(json['rate_limited_at'].toString())
          : null,
      totalRequests: (json['total_requests'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'label': label,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
      'is_rate_limited': isRateLimited,
      'rate_limited_at': rateLimitedAt?.toIso8601String(),
      'total_requests': totalRequests,
    };
  }

  ApiKeyEntry copyWith({
    String? id,
    String? key,
    String? label,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool? isRateLimited,
    DateTime? rateLimitedAt,
    int? totalRequests,
  }) {
    return ApiKeyEntry(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isRateLimited: isRateLimited ?? this.isRateLimited,
      rateLimitedAt: rateLimitedAt ?? this.rateLimitedAt,
      totalRequests: totalRequests ?? this.totalRequests,
    );
  }
}
