import 'dart:convert';
import '../../../core/utils/image_utils.dart';

/// System Category Registry managing bidirectional mapping between
/// Backend UUIDs, API Slugs, and Clean User-Facing Display Names.
class CategoryRegistry {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // In-memory dynamic cache for categories fetched from API at runtime
  static final Map<String, String> _dynamicIdToName = {};
  static final Map<String, String> _dynamicSlugToName = {};

  // Pre-mapped backend database UUIDs -> Clean Human-Readable Title Names
  static final Map<String, String> _knownUuidToName = {
    'a7361ac9-52e8-4480-b666-755710237943': 'Toys & Baby Products', // Baby Care
    '115dfc24-d880-4a7d-afa1-f7152938f5e3': 'Dairy, Bakery & Frozen', // Bakery & Cakes
    'ca392a81-e2f4-49c2-bb52-7d6a92b453f7': 'Personal Care & Beauty', // Beauty & Cosmetics
    '4f7d2e8d-662a-4dcb-8e55-556fdbae6961': 'Beverages & Drinks',     // Beverages
    '1c8071da-777e-4264-84df-fa810377b4af': 'Clothing & Fashion',     // Clothing & Apparel
    '0973ccf7-ef05-4e42-a38c-3851f643cb7a': 'Dairy, Bakery & Frozen', // Dairy & Breakfast
    'ee032c31-f991-4e30-bae0-065ee821ca30': 'Dairy, Bakery & Frozen', // Dairy, Bread & Eggs
    '9a87281b-40f7-4d60-93f2-067dc97564da': 'Electronics & Appliances', // Electronics & Accessories
    'be1b44db-d104-40e4-8ff6-2a40358eb195': 'Mobile & Accessories',     // Electronics And Mobile
    'a3e3b51f-ae00-4eb3-98fe-d5d609a0934e': 'Footwear & Leather',       // Footwear
    'd4f985f8-717d-4ecf-b7bb-42bbf0233005': 'Fruits & Vegetables',     // Fruits & Vegetables
    'b0687580-1de3-43ac-8f22-b34c9423ec57': 'General Store',           // General Store
    '808dda87-4268-469d-bd6e-400fe47402b5': 'Grocery & Staples',       // Groceries & Staples
    '381f901f-c94b-43d9-be64-780b500dc9be': 'Hardware & Building Material', // Hardware & Tools
    '8dc1d7df-7274-4254-ad6a-b5f1beb4a6f5': 'Household & Cleaning',   // Home & Kitchen
    '24c6e691-414b-47b7-a902-5e919f928578': 'Household & Cleaning',   // Household Cleaning
    'db43b6f0-32a4-4053-bc8e-afdca6dc6e76': 'Grocery & Staples',       // Kirana & Grocery
    '71b661ff-ca38-48c4-9141-3cbd7a74690d': 'Personal Care & Beauty', // Personal Care
    'fe0775d6-0a23-439b-9c81-ff7fe0b61e43': 'Pet Supplies',            // Pet Care
    'ea8e77d6-5d4f-4088-ac8e-156132b64628': 'Medicine & Healthcare',   // Pharmacy & Healthcare
    'f158421a-ba95-402d-bfce-35d7877b476a': 'Services & Others',       // Pooja & Spiritual
    'ecb88553-1682-4df5-8b5d-65a5c35adc3c': 'Snacks & Munchies',       // Snacks & Beverages
    'e556f4e9-59ab-4923-8808-0a65c7e433a1': 'Snacks & Munchies',       // Snacks & Chocolates
    'e6d0d83b-4090-4262-af56-e2931874027e': 'Snacks & Munchies',       // Snacks & Instant Food
    '754c7164-bece-4528-8249-77500c531152': 'Sports & Fitness',        // Sports & Fitness
    '1f4dfc44-b29b-4831-9a67-8e0aa5a9f477': 'Stationery & Office Supplies', // Stationery & Office
    '912b378b-fae5-4ef2-bb58-ad847e855244': 'Toys & Baby Products',     // Toys & Games
  };

  /// Register a single category into runtime registry
  static void registerCategory({required String id, required String name, String slug = ''}) {
    final cleanName = formatCategoryName(name);
    if (id.trim().isNotEmpty) {
      _dynamicIdToName[id.trim().toLowerCase()] = cleanName;
    }
    if (slug.trim().isNotEmpty) {
      _dynamicSlugToName[slug.trim().toLowerCase()] = cleanName;
    }
  }

  /// Bulk register categories from /categories API
  static void registerCategories(List<Map<String, dynamic>> categories) {
    for (final c in categories) {
      final id = c['id']?.toString() ?? '';
      final name = c['name']?.toString() ?? '';
      final slug = c['slug']?.toString() ?? '';
      if (name.isNotEmpty) {
        registerCategory(id: id, name: name, slug: slug);
      }
    }
  }

  static bool isUuid(String input) {
    final s = input.trim().toLowerCase();
    return s.length == 36 && _uuidRegex.hasMatch(s);
  }

  static String? resolveUuid(String uuid) {
    final clean = uuid.trim().toLowerCase();
    return _dynamicIdToName[clean] ?? _knownUuidToName[clean];
  }

  /// 21 Standard Canonical Categories displayed across merchant and customer flows
  static const List<String> canonicalCategories = [
    'General Store',
    'Grocery & Staples',
    'Dairy, Bakery & Frozen',
    'Snacks & Munchies',
    'Beverages & Drinks',
    'Fruits & Vegetables',
    'Personal Care & Beauty',
    'Household & Cleaning',
    'Home & Kitchen',
    'Pooja & Spiritual',
    'Clothing & Fashion',
    'Footwear & Leather',
    'Electronics & Appliances',
    'Mobile & Accessories',
    'Medicine & Healthcare',
    'Toys & Baby Products',
    'Stationery & Office Supplies',
    'Hardware & Building Material',
    'Sports & Fitness',
    'Automotive & Spare Parts',
    'Pet Supplies',
    'Services & Others',
  ];

  /// Normalizes any category string (UUID, slug, English name, Hindi name, or alias)
  /// into a canonical slug key (e.g. 'kirana-grocery', 'dairy-breakfast')
  static String normalizeCategoryKey(String? raw) {
    if (raw == null) return 'general-store';
    final s = raw.trim().toLowerCase();
    if (s.isEmpty || s == 'all') return 'all';

    // 1. If UUID, check if resolved to a known name
    if (isUuid(s)) {
      final name = resolveUuid(s);
      if (name != null) {
        return getCategorySlug(name);
      }
      return 'general-store';
    }

    // 2. Normalize punctuation and symbols
    final clean = s
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    // 3. Match against canonical slug buckets
    if (clean.contains('kirana') || clean.contains('grocery') || clean.contains('staple') ||
        clean.contains('pulses') || clean.contains('lentils') || clean.contains('atta') ||
        clean.contains('rice') || clean.contains('grain') || clean.contains('edible-oil') ||
        clean.contains('masala') || clean.contains('spice')) {
      return 'kirana-grocery';
    }
    if (clean.contains('dairy') || clean.contains('breakfast') || clean.contains('milk') ||
        clean.contains('curd') || clean.contains('paneer') || clean.contains('butter') ||
        clean.contains('cheese') || clean.contains('egg')) {
      return 'dairy-breakfast';
    }
    if (clean.contains('snack') || clean.contains('munch') || clean.contains('namkeen') ||
        clean.contains('biscuit') || clean.contains('cookie') || clean.contains('chip') ||
        clean.contains('chocolate')) {
      return 'snacks-beverages';
    }
    if (clean.contains('beverage') || clean.contains('drink') || clean.contains('juice') ||
        clean.contains('tea') || clean.contains('coffee')) {
      return 'beverages';
    }
    if (clean.contains('bakery') || clean.contains('cake') || clean.contains('pastry') || clean.contains('rusk')) {
      return 'bakery-cakes';
    }
    if (clean.contains('fruit') || clean.contains('vegetable') || clean.contains('sabji')) {
      return 'fruits-vegetables';
    }
    if (clean.contains('beauty') || clean.contains('cosmetic') || clean.contains('makeup')) {
      return 'beauty-cosmetics';
    }
    if (clean.contains('personal') || clean.contains('shampoo') || clean.contains('soap') ||
        clean.contains('bath') || clean.contains('skin') || clean.contains('oral') ||
        clean.contains('toothpaste') || clean.contains('hair')) {
      return 'personal-care';
    }
    if (clean.contains('household') || clean.contains('cleaning') || clean.contains('laundry') ||
        clean.contains('detergent') || clean.contains('dishwash')) {
      return 'household-cleaning';
    }
    if (clean.contains('kitchen') || clean.contains('cookware') || clean.contains('utensil')) {
      return 'home-kitchen';
    }
    if (clean.contains('pooja') || clean.contains('puja') || clean.contains('spiritual') ||
        clean.contains('agarbatti') || clean.contains('camphor') || clean.contains('diya')) {
      return 'pooja-spiritual';
    }
    if (clean.contains('baby') || clean.contains('diaper') || clean.contains('wipes')) {
      return 'baby-care';
    }
    if (clean.contains('pharmacy') || clean.contains('medicine') || clean.contains('health') ||
        clean.contains('doctor') || clean.contains('vitamin') || clean.contains('supplement') ||
        clean.contains('medical') || clean.contains('first-aid')) {
      return 'pharmacy-healthcare';
    }
    if (clean.contains('electronics') || clean.contains('electronic') || clean.contains('appliance') ||
        clean.contains('gadget')) {
      return 'electronics-accessories';
    }
    if (clean.contains('mobile') || clean.contains('charger') || clean.contains('earphone')) {
      return 'electronics-and-mobile';
    }
    if (clean.contains('clothing') || clean.contains('cloth') || clean.contains('fashion') ||
        clean.contains('apparel') || clean.contains('shirt') || clean.contains('pant') ||
        clean.contains('wear')) {
      return 'clothing-apparel';
    }
    if (clean.contains('footwear') || clean.contains('shoe') || clean.contains('sandal') ||
        clean.contains('slipper') || clean.contains('leather')) {
      return 'footwear';
    }
    if (clean.contains('stationery') || clean.contains('office') || clean.contains('notebook') ||
        clean.contains('pen') || clean.contains('paper') || clean.contains('book')) {
      return 'stationery-office';
    }
    if (clean.contains('hardware') || clean.contains('tool') || clean.contains('building') ||
        clean.contains('electrical') || clean.contains('lock')) {
      return 'hardware-tools';
    }
    if (clean.contains('automotive') || clean.contains('spare') || clean.contains('vehicle')) {
      return 'automotive-spare-parts';
    }
    if (clean.contains('sport') || clean.contains('fitness') || clean.contains('gym') || clean.contains('cricket')) {
      return 'sports-fitness';
    }
    if (clean.contains('toy') || clean.contains('game') || clean.contains('puzzle')) {
      return 'toys-games';
    }
    if (clean.contains('pet') || clean.contains('dog') || clean.contains('cat')) {
      return 'pet-care';
    }
    if (clean.contains('service') || clean.contains('other')) {
      return 'services-others';
    }

    return clean.isNotEmpty ? clean : 'general-store';
  }

  /// 0ms bidirectional category matching across merchant and customer categories
  static bool isCategoryMatch(String? cat1, String? cat2) {
    if (cat1 == null || cat2 == null) return true;
    final c1 = cat1.trim();
    final c2 = cat2.trim();
    if (c1.isEmpty || c2.isEmpty) return true;
    if (c1.toLowerCase() == 'all' || c2.toLowerCase() == 'all') return true;
    if (c1.toLowerCase() == c2.toLowerCase()) return true;

    final key1 = normalizeCategoryKey(c1);
    final key2 = normalizeCategoryKey(c2);
    if (key1 == key2) return true;

    // Cross-bucket compatibility (e.g. beverages under snacks-beverages)
    if ((key1 == 'beverages' && key2 == 'snacks-beverages') ||
        (key2 == 'beverages' && key1 == 'snacks-beverages')) {
      return true;
    }
    if ((key1 == 'automotive-spare-parts' && key2 == 'hardware-tools') ||
        (key2 == 'automotive-spare-parts' && key1 == 'hardware-tools')) {
      return true;
    }
    if ((key1 == 'services-others' && key2 == 'general-store') ||
        (key2 == 'services-others' && key1 == 'general-store')) {
      return true;
    }

    return false;
  }

  /// Formats raw database category codes, UUIDs, or slugs into clean, human-readable Title Names
  static String formatCategoryName(String raw) => _formatCategoryNameInternal(raw);
}

/// Formats raw database category codes, UUIDs, or slugs into clean, human-readable Title Names
String formatCategoryName(String raw) => _formatCategoryNameInternal(raw);

String _formatCategoryNameInternal(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'General Store';

  // 1. Check if input is a UUID
  if (CategoryRegistry.isUuid(s)) {
    final resolved = CategoryRegistry.resolveUuid(s);
    if (resolved != null) return resolved;
    // Safe fallback for unknown UUID: NEVER expose raw hexadecimal ID strings
    return 'General Store';
  }

  // 2. Check dynamic runtime registry
  final lower = s.toLowerCase();
  if (CategoryRegistry._dynamicSlugToName.containsKey(lower)) {
    return CategoryRegistry._dynamicSlugToName[lower]!;
  }
  if (CategoryRegistry._dynamicIdToName.containsKey(lower)) {
    return CategoryRegistry._dynamicIdToName[lower]!;
  }

  // 3. Normalize for slug matching
  final normalized = lower
      .replaceAll('&', '_and_')
      .replaceAll(',', '')
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  switch (normalized) {
    case 'general_store':
    case 'general':
      return 'General Store';

    case 'grocery_and_staples':
    case 'groceries_and_staples':
    case 'groceries_staples':
    case 'grocery_staples':
    case 'kirana_and_grocery':
    case 'kirana_grocery':
    case 'kirana':
    case 'grocery':
    case 'groceries':
    case 'staples':
      return 'Grocery & Staples';

    case 'snacks_and_munchies':
    case 'snacks_munchies':
    case 'snacks_and_branded_foods':
    case 'snacks_branded_foods':
    case 'branded_foods':
    case 'snacks_and_beverages':
    case 'snacks_beverages':
    case 'snacks_and_chocolates':
    case 'snacks_chocolates':
    case 'snacks_and_instant_food':
    case 'snacks_instant_food':
    case 'snacks':
    case 'munchies':
    case 'namkeen':
      return 'Snacks & Munchies';

    case 'beverages_and_drinks':
    case 'beverages_drinks':
    case 'beverages':
    case 'drinks':
    case 'cold_drinks':
      return 'Beverages & Drinks';

    case 'dairy_bakery_and_frozen':
    case 'dairy_and_bakery':
    case 'dairy_bakery':
    case 'dairy_and_breakfast':
    case 'dairy_breakfast':
    case 'dairy_bread_and_eggs':
    case 'dairy_bread_eggs':
    case 'bakery_and_cakes':
    case 'bakery_cakes':
    case 'dairy':
    case 'bakery':
      return 'Dairy, Bakery & Frozen';

    case 'personal_care_and_beauty':
    case 'personal_care':
    case 'beauty_and_cosmetics':
    case 'beauty_cosmetics':
    case 'beauty':
    case 'cosmetics':
      return 'Personal Care & Beauty';

    case 'household_and_cleaning':
    case 'household_cleaning':
    case 'home_and_kitchen':
    case 'home_kitchen':
    case 'household':
    case 'cleaning':
      return 'Household & Cleaning';

    case 'fruits_and_vegetables':
    case 'fruits_vegetables':
    case 'fruits':
    case 'vegetables':
    case 'sabji':
      return 'Fruits & Vegetables';

    case 'electronics_and_appliances':
    case 'electronics_and_accessories':
    case 'electronics_accessories':
    case 'electronics_appliances':
    case 'electronics':
    case 'appliances':
      return 'Electronics & Appliances';

    case 'mobile_and_accessories':
    case 'electronics_and_mobile':
    case 'mobile_accessories':
    case 'mobile':
      return 'Mobile & Accessories';

    case 'clothing_and_fashion':
    case 'clothing_and_apparel':
    case 'clothing_apparel':
    case 'clothing_fashion':
    case 'clothing':
    case 'apparel':
    case 'fashion':
      return 'Clothing & Fashion';

    case 'footwear_and_leather':
    case 'footwear':
    case 'shoes':
    case 'leather':
      return 'Footwear & Leather';

    case 'stationery_and_office_supplies':
    case 'stationery_and_office':
    case 'stationery_office':
    case 'stationery':
    case 'office':
      return 'Stationery & Office Supplies';

    case 'hardware_and_building_material':
    case 'hardware_and_tools':
    case 'hardware_tools':
    case 'hardware':
    case 'tools':
      return 'Hardware & Building Material';

    case 'medicine_and_healthcare':
    case 'pharmacy_and_healthcare':
    case 'pharmacy_healthcare':
    case 'medicine':
    case 'healthcare':
    case 'pharmacy':
      return 'Medicine & Healthcare';

    case 'toys_and_baby_products':
    case 'toys_and_games':
    case 'toys_games':
    case 'baby_care':
    case 'toys':
    case 'baby_products':
    case 'baby':
      return 'Toys & Baby Products';

    case 'sports_and_fitness':
    case 'sports_fitness':
    case 'sports':
    case 'fitness':
      return 'Sports & Fitness';

    case 'automotive_and_spare_parts':
    case 'automotive_spare_parts':
    case 'automotive':
    case 'auto_parts':
      return 'Automotive & Spare Parts';

    case 'pet_supplies':
    case 'pet_care':
    case 'pets':
    case 'pet':
      return 'Pet Supplies';

    case 'services_and_others':
    case 'pooja_and_spiritual':
    case 'pooja_spiritual':
    case 'services':
    case 'others':
    case 'other':
      return 'Services & Others';
  }

  // 4. Fallback: Clean title-case hyphenated or underscored codes
  if (!s.contains('-') && !s.contains('_')) {
    return s;
  }

  return s
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .map((w) {
        final wLow = w.toLowerCase();
        if (wLow == 'and') return '&';
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Converts clean human-readable Category Name into canonical API slug accepted by GoBackend
String getCategorySlug(String category) {
  final clean = category.trim().toLowerCase();
  if (clean.contains('kirana') || clean.contains('grocery') || clean.contains('staple')) return 'kirana-grocery';
  if (clean.contains('dairy') || clean.contains('breakfast') || clean.contains('bakery') || clean.contains('egg')) return 'dairy-breakfast';
  if (clean.contains('snack') || clean.contains('munch') || clean.contains('chocolate') || clean.contains('namkeen')) return 'snacks-beverages';
  if (clean.contains('beverage') || clean.contains('drink')) return 'beverages';
  if (clean.contains('fruit') || clean.contains('vegetable') || clean.contains('sabji')) return 'fruits-vegetables';
  if (clean.contains('beauty') || clean.contains('cosmetic') || clean.contains('personal') || clean.contains('care')) return 'personal-care';
  if (clean.contains('clean') || clean.contains('household') || clean.contains('kitchen')) return 'household-cleaning';
  if (clean.contains('cloth') || clean.contains('apparel') || clean.contains('fashion')) return 'clothing-apparel';
  if (clean.contains('footwear') || clean.contains('shoe') || clean.contains('leather')) return 'footwear';
  if (clean.contains('mobile')) return 'electronics-and-mobile';
  if (clean.contains('electronic') || clean.contains('appliance')) return 'electronics-accessories';
  if (clean.contains('stationery') || clean.contains('office')) return 'stationery-office';
  if (clean.contains('hardware') || clean.contains('building') || clean.contains('tool')) return 'hardware-tools';
  if (clean.contains('pharmacy') || clean.contains('health') || clean.contains('medicine')) return 'pharmacy-healthcare';
  if (clean.contains('toy') || clean.contains('baby') || clean.contains('game')) return 'toys-games';
  if (clean.contains('sport') || clean.contains('fitness')) return 'sports-fitness';
  if (clean.contains('automotive') || clean.contains('spare') || clean.contains('vehicle')) return 'hardware-tools';
  if (clean.contains('pet')) return 'pet-care';
  if (clean.contains('pooja') || clean.contains('spiritual') || clean.contains('service')) return 'general-store';
  if (clean.contains('general')) return 'general-store';

  // Generic clean slugify fallback
  final slug = clean
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isNotEmpty ? slug : 'general-store';
}

/// Enterprise Privacy Shield that prevents leakage of internal merchant metrics
/// (purchase costs, margins, floor prices, wholesale suppliers, reorder alerts, etc.)
/// to public customers while preserving all customer-facing specifications.
class CustomerPrivacyShield {
  static const Set<String> blockedKeys = {
    // Internal Financials & Margins
    'cost_price', 'costprice', 'cost', 'unit_profit', 'profit', 'margin', 'profit_margin_pct', 'markup',
    'wholesale_price', 'wholesaleprice', 'purchase_price', 'kharid_price', 'cogs',

    // Bargaining Limits
    'floor_price', 'floorprice', 'min_price', 'bottom_price', 'allow_bargain', 'is_bargain_allowed',

    // Supplier & Dealer Contacts
    'supplier', 'supplier_name', 'distributor', 'distributor_name', 'vendor',
    'dealer', 'dealer_name', 'dealer_phone', 'wholesaler',

    // Inventory Restocking Thresholds
    'reorder_point', 'reorder_qty', 'threshold', 'stock_alert_threshold',
    'low_stock_threshold', 'min_stock', 'inventory',

    // Internal Codes, UUIDs & Barcodes
    'barcode', 'sku', 'id', 'uuid', 'shop_id', 'user_id', 'internal_code',

    // Internal System Flags & Redundant Category Keys
    'is_price_public', 'ispricepublic', 'hide_price', 'price_public', 'is_public', 'is_active', 'is_featured',
    'category', 'category_name', 'category_id', 'category_slug', 'unit', 'brand',
  };

  /// Returns true if an attribute key is safe to be shown to public customers.
  static bool isSafeCustomerKey(String key) {
    return !blockedKeys.contains(key.trim().toLowerCase());
  }

  /// Extracts customer-safe specifications from a product model.
  static List<MapEntry<String, String>> extractPublicSpecifications(ProductModel product) {
    final specs = <MapEntry<String, String>>[];

    // 1. Core Public Identity & Classification
    final brandVal = product.brand.isNotEmpty
        ? product.brand
        : (product.attributes['brand']?.toString().trim() ?? '');
    if (brandVal.isNotEmpty) {
      specs.add(MapEntry('Brand', brandVal));
    }
    if (product.category.isNotEmpty) {
      specs.add(MapEntry('Category', product.category));
    }
    if (product.unit.isNotEmpty) {
      specs.add(MapEntry('Unit', product.unit));
    }
    if (product.weight > 0) {
      specs.add(MapEntry('Net Weight', '${product.weight} kg'));
    }

    // 2. Dynamic Custom Merchant Specifications (filtering out blocked keys)
    if (product.attributes.isNotEmpty) {
      product.attributes.forEach((k, v) {
        if (isSafeCustomerKey(k) &&
            v != null &&
            v.toString().trim().isNotEmpty &&
            v is! bool) {
          final formattedLabel = k
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
              .join(' ');
          specs.add(MapEntry(formattedLabel, v.toString().trim()));
        }
      });
    }

    return specs;
  }
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

  String get brand => attributes['brand']?.toString() ?? '';
  String get supplier => attributes['supplier']?.toString() ?? '';

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

  /// Batch Number from specs/attributes if present
  String get batchNo => (attributes['batch_no'] ?? attributes['batch'] ?? attributes['Batch'] ?? '').toString().trim();

  /// Expiry Date parsed as DateTime
  DateTime? get expiryDate {
    final raw = attributes['expiry_date'] ?? attributes['expiry'] ?? attributes['exp_date'] ?? attributes['Expiry'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    try {
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }

  /// Days remaining until expiration (negative if already expired)
  int? get daysUntilExpiry {
    final exp = expiryDate;
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(exp.year, exp.month, exp.day);
    return expDay.difference(today).inDays;
  }

  /// Whether product has passed its expiry date
  bool get isExpired {
    final days = daysUntilExpiry;
    return days != null && days < 0;
  }

  /// Whether product is expiring soon (within 30 days)
  bool get isNearExpiry {
    final days = daysUntilExpiry;
    return days != null && days >= 0 && days <= 30;
  }

  /// Public specifications filtered for safe customer storefront viewing
  List<MapEntry<String, String>> get customerSpecifications =>
      CustomerPrivacyShield.extractPublicSpecifications(this);

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
    } else if (json['attributes'] is String) {
      final s = (json['attributes'] as String).trim();
      if (s.isNotEmpty && s.startsWith('{') && s.endsWith('}')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is Map) {
            attrMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }

    // Fallback to alternative attribute/specification keys if empty
    if (attrMap.isEmpty) {
      for (final altKey in ['specifications', 'specs', 'metadata']) {
        if (json[altKey] is Map) {
          attrMap = Map<String, dynamic>.from(json[altKey] as Map);
          break;
        } else if (json[altKey] is String) {
          final s = (json[altKey] as String).trim();
          if (s.isNotEmpty && s.startsWith('{') && s.endsWith('}')) {
            try {
              final decoded = jsonDecode(s);
              if (decoded is Map) {
                attrMap = Map<String, dynamic>.from(decoded);
                break;
              }
            } catch (_) {}
          }
        }
      }
    }

    // Extract top-level known specification keys into attributes if not already present
    for (final specKey in [
      'brand',
      'unit',
      'size',
      'color',
      'flavor',
      'warranty',
      'model',
      'origin',
      'manufacturer',
      'shelf_life',
      'expiry_date',
    ]) {
      if (json[specKey] != null && json[specKey].toString().trim().isNotEmpty) {
        attrMap.putIfAbsent(specKey, () => json[specKey].toString().trim());
      }
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
    attrMap['unit'] = resolvedUnit;

    // Category display resolution with automatic Code/Slug/UUID -> Name formatting
    String rawCategory = 'General Store';
    if (json['category_name'] != null && json['category_name'].toString().trim().isNotEmpty) {
      rawCategory = json['category_name'].toString().trim();
    } else if (attrMap['category_name'] != null && attrMap['category_name'].toString().trim().isNotEmpty) {
      rawCategory = attrMap['category_name'].toString().trim();
    } else if (attrMap['category'] != null && attrMap['category'].toString().trim().isNotEmpty) {
      rawCategory = attrMap['category'].toString().trim();
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
      isPricePublic: json['is_price_public'] != null
          ? parseBool(json['is_price_public'], true)
          : (attrMap['is_price_public'] != null
              ? parseBool(attrMap['is_price_public'], true)
              : (json['hide_price'] != null ? !parseBool(json['hide_price'], false) : true)),
      attributes: attrMap,
    );
  }

  Map<String, dynamic> toJson() {
    final cleanCategory = formatCategoryName(category);
    final slug = getCategorySlug(cleanCategory);
    final mergedAttr = Map<String, dynamic>.from(attributes);
    mergedAttr['category_name'] = cleanCategory;
    mergedAttr['category'] = cleanCategory;
    mergedAttr['unit'] = unit;
    mergedAttr['is_price_public'] = isPricePublic;
    if (attributes['brand'] != null && attributes['brand'].toString().trim().isNotEmpty) {
      mergedAttr['brand'] = attributes['brand'].toString().trim();
    }

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
      'brand': attributes['brand']?.toString() ?? '',
      'category_id': slug,
      'category_name': cleanCategory,
      'category': cleanCategory,
      'images': images,
      'image_url': imageUrl ?? '',
      'weight': weight,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_price_public': isPricePublic,
      'attributes': mergedAttr,
    };
  }
}
