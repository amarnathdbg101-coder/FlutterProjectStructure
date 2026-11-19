import 'package:flutter_test/flutter_test.dart';

// Test the identical logic used in InventoryScreen AI autofill
bool isUsefulAttribute(String k, String v) {
  final kClean = k.toLowerCase().trim();
  final vClean = v.toLowerCase().trim();
  if (kClean.isEmpty || vClean.isEmpty) return false;

  // 1. Reject placeholder/dummy values
  const dummyValues = {
    'n/a', 'na', 'none', 'unknown', 'null', 'not specified',
    'not applicable', 'standard', 'generic', '-', '--', 'nil',
    'undefined', 'default', 'regular', 'general'
  };
  if (dummyValues.contains(vClean)) return false;

  // 2. Reject overly long values (> 45 chars) — custom attributes should be concise specs
  if (vClean.length > 45) return false;

  // 3. Reject generic advice, warnings, or storage sentences
  if (vClean.contains('store in') ||
      vClean.contains('keep away') ||
      vClean.contains('keep out') ||
      vClean.contains('as directed') ||
      vClean.contains('refer pack') ||
      vClean.contains('sunlight') ||
      vClean.contains('consult')) {
    return false;
  }

  // 4. Reject redundant or useless keys
  const uselessKeys = {
    'storage instructions', 'storage', 'usage', 'how to use',
    'instructions', 'directions', 'care instructions', 'wash care',
    'warning', 'safety warning', 'caution', 'disclaimer', 'notice',
    'country of origin', 'origin',
    // Redundant with primary form fields:
    'name', 'product name', 'brand', 'category', 'subcategory',
    'sub category', 'mrp', 'price', 'selling price', 'cost price',
    'weight', 'net weight', 'unit', 'net quantity', 'barcode',
    'sku', 'description', 'highlights'
  };
  if (uselessKeys.contains(kClean)) return false;

  return true;
}

void main() {
  group('AI Custom Attribute Filter Tests', () {
    test('filters out useless boilerplate storage advice and warnings', () {
      expect(isUsefulAttribute('Storage Instructions', 'Store in a cool and dry place'), isFalse);
      expect(isUsefulAttribute('Usage', 'Apply evenly on face twice daily as directed'), isFalse);
      expect(isUsefulAttribute('Care Instructions', 'Hand wash separately'), isFalse);
      expect(isUsefulAttribute('Safety Warning', 'Keep away from direct sunlight and children'), isFalse);
      expect(isUsefulAttribute('Notice', 'Best before 6 months from manufacture'), isFalse);
    });

    test('filters out dummy placeholders and empty values', () {
      expect(isUsefulAttribute('Warranty', 'N/A'), isFalse);
      expect(isUsefulAttribute('Model', 'None'), isFalse);
      expect(isUsefulAttribute('Color', 'Unknown'), isFalse);
      expect(isUsefulAttribute('Material', '-'), isFalse);
      expect(isUsefulAttribute('Grade', 'Standard'), isFalse);
      expect(isUsefulAttribute('', 'Vegetarian'), isFalse);
      expect(isUsefulAttribute('Diet', ''), isFalse);
    });

    test('filters out redundant keys already present in the primary form fields', () {
      expect(isUsefulAttribute('Category', 'Grocery & Staples'), isFalse);
      expect(isUsefulAttribute('Subcategory', 'Edible Oils'), isFalse);
      expect(isUsefulAttribute('Brand', 'Fortune'), isFalse);
      expect(isUsefulAttribute('Name', 'Mustard Oil'), isFalse);
      expect(isUsefulAttribute('MRP', '₹150'), isFalse);
      expect(isUsefulAttribute('Weight', '1 Litre'), isFalse);
      expect(isUsefulAttribute('Barcode', '8901234567890'), isFalse);
    });

    test('filters out overly verbose essay paragraphs', () {
      expect(
        isUsefulAttribute(
          'Features',
          'This premium mustard oil is traditionally processed through cold press extraction to retain all essential micro-nutrients',
        ),
        isFalse,
      );
    });

    test('accepts essential, high-value, product-defining attributes', () {
      expect(isUsefulAttribute('Dietary Preference', 'Vegetarian'), isTrue);
      expect(isUsefulAttribute('Packaging Type', 'Pouch'), isTrue);
      expect(isUsefulAttribute('Item Form', 'Liquid'), isTrue);
      expect(isUsefulAttribute('Flavor', 'Mustard'), isTrue);
      expect(isUsefulAttribute('Fabric', '100% Pure Cotton'), isTrue);
      expect(isUsefulAttribute('Connectivity', 'Bluetooth 5.3'), isTrue);
      expect(isUsefulAttribute('Warranty', '1 Year Brand Warranty'), isTrue);
      expect(isUsefulAttribute('Fit Type', 'Slim Fit'), isTrue);
      expect(isUsefulAttribute('Color', 'Navy Blue'), isTrue);
    });
  });
}
