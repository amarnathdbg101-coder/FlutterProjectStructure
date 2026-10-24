import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/products/services/smart_barcode_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartBarcodeCatalogService Tests', () {
    test('Exact match for Dove Shampoo (8901030382910)', () async {
      final item = await SmartBarcodeCatalogService.lookup('8901030382910');
      expect(item, isNotNull);
      expect(item!.name, contains('Dove'));
      expect(item.brand, 'Dove');
      expect(item.category, contains('Personal Care'));
      expect(item.mrp, greaterThan(0));
      expect(item.sellingPrice, greaterThan(0));
      expect(item.sellingPrice, lessThanOrEqualTo(item.mrp));
      expect(item.unit, contains('ml'));
      expect(item.isPrefixMatch, isFalse);
    });

    test('Exact match for Dove Intense Repair Shampoo (8901030018598)', () async {
      final item = await SmartBarcodeCatalogService.lookup('8901030018598');
      expect(item, isNotNull);
      expect(item!.name, contains('Dove Intense Repair'));
      expect(item.brand, 'Dove');
      expect(item.category, contains('Personal Care'));
    });

    test('Exact match for Maggi Noodles', () async {
      final item = await SmartBarcodeCatalogService.lookup('8901058852104');
      expect(item, isNotNull);
      expect(item!.name, contains('Maggi'));
      expect(item.brand, 'Maggi');
      expect(item.category, 'Grocery & Staples');
      expect(item.mrp, 14.0);
    });

    test('Exact match for Tata Salt (8901063010018)', () async {
      final item = await SmartBarcodeCatalogService.lookup('8901063010018');
      expect(item, isNotNull);
      expect(item!.name, contains('Tata Salt'));
      expect(item.brand, 'Tata Salt');
      expect(item.category, 'Grocery & Staples');
    });

    test('Exact match for Parle-G Biscuits (8901499001017)', () async {
      final item = await SmartBarcodeCatalogService.lookup('8901499001017');
      expect(item, isNotNull);
      expect(item!.name, contains('Parle-G'));
      expect(item.brand, 'Parle');
      expect(item.category, 'Snacks & Branded Foods');
    });

    test('Prefix heuristic match for unknown Hindustan Unilever barcode', () async {
      // 8901030 prefix belongs to Unilever
      final item = SmartBarcodeCatalogService.lookupSync('8901030777777');
      expect(item, isNotNull);
      expect(item!.brand, contains('Hindustan'));
      expect(item.category, contains('Personal Care'));
      expect(item.isPrefixMatch, isTrue);
    });

    test('Empty or invalid barcode returns null', () async {
      expect(await SmartBarcodeCatalogService.lookup(''), isNull);
      expect(await SmartBarcodeCatalogService.lookup('   '), isNull);
      expect(await SmartBarcodeCatalogService.lookup('123'), isNull);
    });

    test('Master catalog count is non-trivial (> 0 items)', () {
      expect(SmartBarcodeCatalogService.totalCatalogCount, greaterThan(0));
    });
  });
}
