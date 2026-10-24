import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

/// Smart Global Barcode Catalog & Auto-Fill Service
/// Implements Hybrid Architecture: 0ms Edge Local Cache + GoBackend Master DB + GS1 India Heuristics.
class SmartCatalogItem {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String unit;
  final double mrp;
  final double sellingPrice;
  final String? description;
  final Map<String, dynamic>? attributes;
  final bool isPrefixMatch;

  const SmartCatalogItem({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.unit,
    required this.mrp,
    required this.sellingPrice,
    this.description,
    this.attributes,
    this.isPrefixMatch = false,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'category': category,
        'unit': unit,
        'mrp': mrp,
        'sellingPrice': sellingPrice,
        'description': description,
        'attributes': attributes,
        'isPrefixMatch': isPrefixMatch,
      };

  factory SmartCatalogItem.fromJson(Map<String, dynamic> json) {
    return SmartCatalogItem(
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General Store',
      unit: json['unit']?.toString() ?? 'piece',
      mrp: (json['mrp'] as num?)?.toDouble() ?? (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? (json['mrp'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      attributes: json['attributes'] is Map ? Map<String, dynamic>.from(json['attributes']) : null,
      isPrefixMatch: json['isPrefixMatch'] == true,
    );
  }
}

class SmartBarcodeCatalogService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  /// Runtime dynamic catalog cache populated as merchant scans or saves products
  static final Map<String, SmartCatalogItem> _dynamicCatalog = {};

  /// In-memory master catalog indexed by standard EAN-13 barcodes
  static final Map<String, SmartCatalogItem> _masterCatalog = {
    // ─── DEODORANTS, PERFUMES & SCENTS ───
    '8904238300081': const SmartCatalogItem(
      barcode: '8904238300081',
      name: 'Fogg Scent Xpressio Eau De Parfum 100ml',
      brand: 'Fogg',
      category: 'Personal Care & Beauty',
      unit: '100ml',
      mrp: 499.0,
      sellingPrice: 449.0,
      description: 'Fogg Scent Xpressio long-lasting perfume for men.',
    ),
    '8904238300098': const SmartCatalogItem(
      barcode: '8904238300098',
      name: 'Fogg Scent Intensio Eau De Parfum 100ml',
      brand: 'Fogg',
      category: 'Personal Care & Beauty',
      unit: '100ml',
      mrp: 499.0,
      sellingPrice: 449.0,
      description: 'Fogg Scent Intensio long-lasting perfume for men.',
    ),
    '8908001158244': const SmartCatalogItem(
      barcode: '8908001158244',
      name: 'Fogg Napoleon Fragrance Body Spray 150ml',
      brand: 'Fogg',
      category: 'Personal Care & Beauty',
      unit: '150ml',
      mrp: 250.0,
      sellingPrice: 230.0,
      description: 'Fogg Napoleon no gas deodorant body spray.',
    ),

    // ─── PERSONAL CARE & HYGIENE (DOVE / UNILEVER / COLGATE / DABUR) ───
    '8901030382910': const SmartCatalogItem(
      barcode: '8901030382910',
      name: 'Dove Daily Shine Shampoo 180ml',
      brand: 'Dove',
      category: 'Personal Care',
      unit: '180ml',
      mrp: 185.0,
      sellingPrice: 175.0,
      description: 'Dove Daily Shine shampoo with nutritive serum for smooth, shiny hair.',
    ),
    '8901030018598': const SmartCatalogItem(
      barcode: '8901030018598',
      name: 'Dove Intense Repair Shampoo 180ml',
      brand: 'Dove',
      category: 'Personal Care',
      unit: '180ml',
      mrp: 195.0,
      sellingPrice: 185.0,
      description: 'Dove Intense Repair shampoo with fiber actives to nourish damaged hair.',
    ),

    // ─── GROCERY & STAPLES (TATA / AASHIRVAAD / FORTUNE / MAGGI) ───
    '8901063010018': const SmartCatalogItem(
      barcode: '8901063010018',
      name: 'Tata Salt Vacuum Evaporated Iodized 1kg',
      brand: 'Tata Salt',
      category: 'Grocery & Staples',
      unit: '1kg',
      mrp: 28.0,
      sellingPrice: 28.0,
      description: 'Desh Ka Namak - Tata Salt vacuum evaporated iodized edible salt.',
    ),
    '8901058852104': const SmartCatalogItem(
      barcode: '8901058852104',
      name: 'Maggi 2-Minute Masala Instant Noodles 70g',
      brand: 'Maggi',
      category: 'Grocery & Staples',
      unit: '70g',
      mrp: 14.0,
      sellingPrice: 14.0,
      description: 'Maggi 2-minute instant noodles with tastemaker spices.',
    ),

    // ─── SNACKS, BISCUITS & CONFECTIONERY ───
    '8901499001017': const SmartCatalogItem(
      barcode: '8901499001017',
      name: 'Parle-G Gluco Biscuits 80g',
      brand: 'Parle',
      category: 'Snacks & Branded Foods',
      unit: '80g',
      mrp: 10.0,
      sellingPrice: 10.0,
      description: 'Parle-G original glucose biscuits.',
    ),
  };

  /// GS1 Prefix Heuristic Rules for Indian FMCG
  static final Map<String, _PrefixRule> _prefixHeuristics = {
    '8904238': const _PrefixRule('Fogg Scent / Perfume (Vini Cosmetics)', 'Personal Care & Beauty', estimatedMrp: 499.0, estimatedSellingPrice: 449.0, defaultUnit: '100ml'),
    '8908001': const _PrefixRule('Fogg Body Spray / Deodorant (Vini Cosmetics)', 'Personal Care & Beauty', estimatedMrp: 250.0, estimatedSellingPrice: 230.0, defaultUnit: '150ml'),
    '8901030': const _PrefixRule('Hindustan Unilever (Dove / Lux / Surf)', 'Personal Care', estimatedMrp: 95.0, estimatedSellingPrice: 90.0, defaultUnit: '180ml'),
    '8901058': const _PrefixRule('Nestlé India (Maggi / Nescafé / KitKat)', 'Grocery & Staples', estimatedMrp: 25.0, estimatedSellingPrice: 25.0, defaultUnit: '70g'),
    '8901719': const _PrefixRule('Britannia Industries (Good Day / Marie Gold)', 'Snacks & Branded Foods', estimatedMrp: 20.0, estimatedSellingPrice: 20.0, defaultUnit: '100g'),
    '8901499': const _PrefixRule('Parle Products (Parle-G / Monaco / Hide & Seek)', 'Snacks & Branded Foods', estimatedMrp: 10.0, estimatedSellingPrice: 10.0, defaultUnit: '80g'),
    '8901063': const _PrefixRule('Tata Consumer Products (Tata Salt / Tata Tea)', 'Grocery & Staples', estimatedMrp: 40.0, estimatedSellingPrice: 38.0, defaultUnit: '1kg'),
    '8906007': const _PrefixRule('ITC Limited (Aashirvaad / Sunfeast / Bingo)', 'Grocery & Staples', estimatedMrp: 50.0, estimatedSellingPrice: 48.0, defaultUnit: '1 pc'),
    '8906010': const _PrefixRule('Amul / GCMMF (Butter / Ghee / Milk)', 'Dairy, Bakery & Frozen', estimatedMrp: 55.0, estimatedSellingPrice: 52.0, defaultUnit: '100g'),
  };

  /// Single-flight request deduplication map (prevents duplicate concurrent network requests for same barcode)
  static final Map<String, Future<SmartCatalogItem?>> _inflightRequests = {};

  /// Dynamically register a product into in-memory and local device cache
  static Future<void> registerDynamicItem(SmartCatalogItem item) async {
    final clean = item.barcode.trim();
    if (clean.isNotEmpty) {
      if (_dynamicCatalog.length > 1000) {
        _dynamicCatalog.remove(_dynamicCatalog.keys.first); // LRU eviction
      }
      _dynamicCatalog[clean] = item;
      Future.microtask(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('shopsilo_master_barcode_$clean', jsonEncode(item.toJson()));
        } catch (e) {
          debugPrint('[SmartCatalog] Local cache save skipped/failed: $e');
        }
      });
    }
  }

  /// Synchronous 0ms Local Edge Lookup
  static SmartCatalogItem? lookupSync(String rawBarcode) {
    var clean = rawBarcode.trim();
    if (clean.isEmpty) return null;

    if (clean.length == 14 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    // 1. Dynamic Memory Catalog
    if (_dynamicCatalog.containsKey(clean)) {
      return _dynamicCatalog[clean];
    }
    final stripped = clean.replaceFirst(RegExp(r'^0+'), '');
    if (stripped.isNotEmpty && _dynamicCatalog.containsKey(stripped)) {
      return _dynamicCatalog[stripped];
    }

    // 2. Static Master Catalog
    if (_masterCatalog.containsKey(clean)) {
      return _masterCatalog[clean];
    }
    if (stripped.isNotEmpty && _masterCatalog.containsKey(stripped)) {
      return _masterCatalog[stripped];
    }

    // 3. GS1 Heuristic Match
    for (final entry in _prefixHeuristics.entries) {
      if (clean.startsWith(entry.key) || stripped.startsWith(entry.key)) {
        final rule = entry.value;
        return SmartCatalogItem(
          barcode: clean,
          name: '${rule.brandGroup} Pack',
          brand: rule.brandGroup.split('(').first.trim(),
          category: rule.defaultCategory,
          unit: rule.defaultUnit,
          mrp: rule.estimatedMrp,
          sellingPrice: rule.estimatedSellingPrice,
          isPrefixMatch: true,
        );
      }
    }

    // 4. GS1 890 Fallback
    if (clean.startsWith('890') || stripped.startsWith('890')) {
      return SmartCatalogItem(
        barcode: clean,
        name: 'Packaged Retail Item ($clean)',
        brand: 'Retail Brand',
        category: 'General Store',
        unit: '1 pc',
        mrp: 99.0,
        sellingPrice: 95.0,
        isPrefixMatch: true,
      );
    }

    return null;
  }

  /// Hybrid Resolution Engine (0ms Local Edge Cache ➔ GoBackend Master DB ➔ Heuristic Fallback)
  static Future<SmartCatalogItem?> lookup(String rawBarcode) async {
    final clean = rawBarcode.trim();
    if (clean.isEmpty) return null;

    // 1. Check synchronous in-memory edge cache (0ms response)
    final syncMatch = lookupSync(clean);
    if (syncMatch != null && !syncMatch.isPrefixMatch) {
      return syncMatch;
    }

    // 2. Single-Flight Request Deduplication: reuse pending in-flight request if already in progress
    if (_inflightRequests.containsKey(clean)) {
      return _inflightRequests[clean]!;
    }

    final future = _executeLookup(clean, syncMatch);
    _inflightRequests[clean] = future;
    try {
      final res = await future;
      return res;
    } finally {
      _inflightRequests.remove(clean);
    }
  }

  static Future<SmartCatalogItem?> _executeLookup(String clean, SmartCatalogItem? syncMatch) async {
    // Query GoBackend PostgreSQL Master Catalog API
    try {
      final response = await _dio.get('/catalog/barcode/$clean');
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data;
        if (resData['success'] == true && resData['data'] != null) {
          final data = resData['data'];
          final item = SmartCatalogItem(
            barcode: data['barcode']?.toString() ?? clean,
            name: data['name']?.toString() ?? '',
            brand: data['brand']?.toString() ?? '',
            category: data['category']?.toString() ?? 'General Store',
            unit: data['unit']?.toString() ?? 'piece',
            mrp: (data['mrp'] as num?)?.toDouble() ?? 0.0,
            sellingPrice: (data['selling_price'] as num?)?.toDouble() ?? (data['mrp'] as num?)?.toDouble() ?? 0.0,
            description: data['description']?.toString(),
            attributes: data['attributes'] is Map ? Map<String, dynamic>.from(data['attributes']) : null,
            isPrefixMatch: false,
          );

          if (item.name.isNotEmpty) {
            await registerDynamicItem(item);
            return item;
          }
        }
      }
    } catch (e) {
      debugPrint('[SmartCatalog] GoBackend API lookup skipped/error: $e');
    }

    return syncMatch;
  }

  static int get totalCatalogCount => _masterCatalog.length + _dynamicCatalog.length;
}

class _PrefixRule {
  final String brandGroup;
  final String defaultCategory;
  final double estimatedMrp;
  final double estimatedSellingPrice;
  final String defaultUnit;

  const _PrefixRule(
    this.brandGroup,
    this.defaultCategory, {
    this.estimatedMrp = 50.0,
    this.estimatedSellingPrice = 48.0,
    this.defaultUnit = '1 pc',
  });
}
