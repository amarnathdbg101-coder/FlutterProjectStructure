import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/services/sales_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SalesPdfService (Mandi-Style Layout) Tests', () {
    test('generateSalesPdf produces valid PDF bytes for typical sales', () async {
      final items = [
        SoldProductTimelineItem(
          productName: 'Aashirvaad Shudh Chakki Atta 5kg',
          productSku: '8901030382341',
          quantity: 2,
          unitPrice: 245.0,
          totalPrice: 490.0,
          paymentMethod: 'UPI',
          soldAt: DateTime.now().subtract(const Duration(minutes: 15)),
          billNumber: 'BILL-1001',
          customerPhone: '9876543210',
        ),
        SoldProductTimelineItem(
          productName: 'Tata Tea Gold 500g Pack',
          productSku: '8901058852341',
          quantity: 1,
          unitPrice: 320.0,
          totalPrice: 320.0,
          paymentMethod: 'CASH',
          soldAt: DateTime.now().subtract(const Duration(minutes: 45)),
          billNumber: 'BILL-1002',
          customerPhone: '',
        ),
      ];

      final pdfBytes = await SalesPdfService.generateSalesPdf(
        shopName: 'Maa Durga Kirana Store',
        items: items,
        totalRevenue: 810.0,
        totalBills: 2,
        cashRevenue: 320.0,
        upiRevenue: 490.0,
        khataRevenue: 0.0,
        windowDays: 1,
        shopAddress: 'Shop #12, Market Complex, Lucknow',
        shopPhone: '9876543210',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard %PDF- header check
      final headerStr = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('generateSalesPdf handles multi-page chunking gracefully for 35 items', () async {
      final items = List.generate(
        35,
        (i) => SoldProductTimelineItem(
          productName: 'Product Item #${i + 1} High Quality Grocery Pack',
          productSku: 'SKU-${1000 + i}',
          quantity: (i % 3) + 1,
          unitPrice: 150.0 + (i * 10),
          totalPrice: ((i % 3) + 1) * (150.0 + (i * 10)),
          paymentMethod: i % 2 == 0 ? 'UPI' : 'CASH',
          soldAt: DateTime.now().subtract(Duration(hours: i)),
          billNumber: 'BILL-${1000 + i}',
          customerPhone: '987650000$i',
        ),
      );

      final pdfBytes = await SalesPdfService.generateSalesPdf(
        shopName: 'ShopSilo Supermarket',
        items: items,
        totalRevenue: 12500.0,
        totalBills: 35,
        cashRevenue: 6000.0,
        upiRevenue: 6500.0,
        khataRevenue: 0.0,
        windowDays: 10,
        shopAddress: 'Civil Lines, Kanpur',
        shopPhone: '9999888877',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(2500));
      final headerStr = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });

    test('generateSalesPdf handles empty items gracefully without crashing', () async {
      final pdfBytes = await SalesPdfService.generateSalesPdf(
        shopName: 'Empty Store',
        items: [],
        totalRevenue: 0.0,
        totalBills: 0,
        cashRevenue: 0.0,
        upiRevenue: 0.0,
        khataRevenue: 0.0,
        windowDays: 1,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(500));
      final headerStr = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(headerStr, equals('%PDF-'));
    });
  });
}
