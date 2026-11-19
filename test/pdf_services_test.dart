import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/services/floor_token_cards_service.dart';
import 'package:flutter_project_structure/features/procurement/models/procurement_model.dart';
import 'package:flutter_project_structure/features/procurement/services/procurement_pdf_service.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/services/khata_pdf_service.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/services/thermal_receipt_pdf_service.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';
import 'package:flutter_project_structure/features/products/services/barcode_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Services Vector Generation Tests', () {
    test(
      'ProcurementPdfService generates valid A4 PDF bytes with Hindi & ₹',
      () async {
        final items = [
          ProcurementItemModel(
            id: 'p1',
            name: 'स्थानीय Generic Yellow Co...',
            qty: '10 pieces',
            category: 'Grocery',
            estimatedPrice: 200,
            dealerName: 'Mandi Trader 1',
          ),
          ProcurementItemModel(
            id: 'p2',
            name: 'Red Moti Decoration',
            qty: '1 packet',
            category: 'Home & Kitchen',
            estimatedPrice: 150,
          ),
        ];

        final bytes = await ProcurementPdfService.generateProcurementPdf(
          shopName: 'OM CLOTHES & COSMETICS',
          items: items,
          totalBudget: 350,
          shopAddress: 'Dhoi, pipal chowk, Darbhanga 846009',
          shopPhone: '7979014637',
        );

        expect(bytes, isNotNull);
        expect(bytes.length, greaterThan(1000));
        final header = String.fromCharCodes(bytes.take(4));
        expect(header, equals('%PDF'));
      },
    );

    test('ProcurementPdfService handles 13 items with Hindi and missing names cleanly', () async {
      final items = [
        ProcurementItemModel(
          id: '1',
          name: 'Item 1',
          qty: '10',
          estimatedPrice: 20,
        ),
        ProcurementItemModel(
          id: '2',
          name: '',
          category: ' ',
          qty: '1',
          estimatedPrice: 10,
        ),
        ProcurementItemModel(
          id: '3',
          name: '',
          category: '',
          qty: '24',
          estimatedPrice: 10,
        ),
        ProcurementItemModel(id: '4', name: '', qty: '24', estimatedPrice: 10),
        ProcurementItemModel(id: '5', name: '', qty: '1', estimatedPrice: 10),
        ProcurementItemModel(id: '6', name: '', qty: '24', estimatedPrice: 10),
        ProcurementItemModel(
          id: '7',
          name: '1',
          category: '',
          qty: '12',
          estimatedPrice: 0,
        ),
        ProcurementItemModel(
          id: '8',
          name: '500',
          category: '',
          qty: '1 2',
          estimatedPrice: 0,
        ),
        ProcurementItemModel(
          id: '9',
          name: 'किसान हुक',
          category: 'सामान्य किराना',
          qty: '1',
          estimatedPrice: 20,
        ),
        ProcurementItemModel(
          id: '10',
          name: 'उन',
          category: 'कपड़ा और सिलाई',
          qty: '10',
          estimatedPrice: 130,
        ),
        ProcurementItemModel(
          id: '11',
          name: 'बैंगनी ऊन',
          category: 'ऊन',
          qty: '20',
          estimatedPrice: 20,
        ),
        ProcurementItemModel(
          id: '12',
          name: '-',
          category: '',
          qty: '10',
          estimatedPrice: 10,
        ),
        ProcurementItemModel(id: '13', name: '', qty: '1', estimatedPrice: 0),
      ];

      final bytes = await ProcurementPdfService.generateProcurementPdf(
        shopName: 'OM CLOTHES & COSMETICS',
        items: items,
        totalBudget: 280,
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(1000));
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, equals('%PDF'));
    });

    test(
      'KhataPdfService generates valid A4 passbook PDF bytes with UPI QR',
      () async {
        final txs = <KhataTransactionModel>[
          KhataTransactionModel(
            id: 'tx1',
            customerMobile: '9876543210',
            amount: 500,
            type: 'GIVE_CREDIT',
            balanceAfter: 500,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            billNumber: '1001',
            notes: 'Groceries Udhar',
          ),
          KhataTransactionModel(
            id: 'tx2',
            customerMobile: '9876543210',
            amount: 200,
            type: 'RECEIVE_PAYMENT',
            balanceAfter: 300,
            createdAt: DateTime.now(),
            notes: 'Cash payment',
          ),
        ];

        final bytes = await KhataPdfService.generateStatementPdf(
          shopName: 'OM CLOTHES & COSMETICS',
          shopAddress: 'Dhoi, pipal chowk, Darbhanga 846009',
          shopPhone: '7979014637',
          upiId: 'merchant@upi',
          customerName: 'Ramesh Kumar',
          customerMobile: '9876543210',
          balance: 300,
          transactions: txs,
        );

        expect(bytes, isNotNull);
        expect(bytes.length, greaterThan(1000));
        final header = String.fromCharCodes(bytes.take(4));
        expect(header, equals('%PDF'));
      },
    );

    test('ThermalReceiptPdfService generates valid 80mm & 58mm thermal receipts with Hindi and blank items', () async {
      final sale = SaleModel(
        billNumber: '1001',
        paymentMethod: 'split',
        subtotal: 310,
        discountAmount: 10,
        totalAmount: 300,
        createdAt: DateTime.now(),
        customerPhone: '9876543210',
        splitPayments: PosSplitPayment(
          cashAmount: 200,
          onlineAmount: 100,
          khataAmount: 0,
        ),
        items: [
          PosCartItem(
            product: ProductModel(
              id: 'p1',
              name: 'किसान हुक',
              category: 'General',
              price: 20,
              stock: 10,
              unit: 'piece',
            ),
            quantity: 1,
            customPrice: 20,
          ),
          PosCartItem(
            product: ProductModel(
              id: 'p2',
              name: 'बैंगनी ऊन',
              category: 'Wool',
              price: 20,
              stock: 10,
              unit: 'packet',
            ),
            quantity: 5,
            customPrice: 20,
          ),
          PosCartItem(
            product: ProductModel(
              id: 'p3',
              name: '', // Empty product name resilience
              category: 'General',
              price: 10,
              stock: 10,
              unit: '',
            ),
            quantity: 2,
            customPrice: 10,
          ),
          PosCartItem(
            product: ProductModel(
              id: 'p4',
              name: 'Generic Toothbrush',
              category: 'Hygiene',
              price: 170,
              stock: 10,
              unit: 'piece',
            ),
            quantity: 1,
            customPrice: 170,
          ),
        ],
      );

      // 1. Test 80mm Roll PDF
      final bytes80 = await ThermalReceiptPdfService.generateReceiptPdf(
        sale: sale,
        shopName: 'OM CLOTHES & COSMETICS',
        shopAddress: 'Dhoi, pipal chowk, Darbhanga 846009',
        shopPhone: '7979014637',
        shopGstin: '10ABCDE1234F1Z5',
        upiId: 'merchant@upi',
        width: ThermalReceiptWidth.roll80mm,
      );

      expect(bytes80, isNotNull);
      expect(bytes80.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes80.take(4)), equals('%PDF'));

      // 2. Test 58mm Roll PDF
      final bytes58 = await ThermalReceiptPdfService.generateReceiptPdf(
        sale: sale,
        shopName: 'OM CLOTHES & COSMETICS',
        width: ThermalReceiptWidth.roll58mm,
      );

      expect(bytes58, isNotNull);
      expect(bytes58.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes58.take(4)), equals('%PDF'));
    });

    test(
      'Thermal receipt page height grows with the number of products',
      () async {
        PosCartItem createItem(String name) => PosCartItem(
          product: ProductModel(
            id: 'p1',
            name: name,
            category: 'General',
            price: 20,
            stock: 10,
          ),
          quantity: 1,
          customPrice: 20,
        );

        Future<double> pageHeightFor(List<String> productNames) async {
          final items = productNames.map(createItem).toList();
          final bytes = await ThermalReceiptPdfService.generateReceiptPdf(
            sale: SaleModel(
              customerPhone: '',
              items: items,
              subtotal: items.length * 20,
              discountAmount: 0,
              totalAmount: items.length * 20,
              paymentMethod: 'cash',
            ),
            shopName: 'Shop',
          );
          final pdfText = String.fromCharCodes(bytes);
          final mediaBox = RegExp(
            r'/MediaBox\s*\[\s*0\s+0\s+[\d.]+\s+([\d.]+)\s*\]',
          ).firstMatch(pdfText);
          expect(mediaBox, isNotNull);
          return double.parse(mediaBox!.group(1)!);
        }

        final oneItemHeight = await pageHeightFor(['Tea']);
        final manyItemsHeight = await pageHeightFor(List.filled(10, 'Tea'));
        final longNameHeight = await pageHeightFor([
          List.filled(
            3,
            'A very long product name that should wrap onto more than two lines and remain fully readable on the printed bill. ',
          ).join(),
        ]);

        expect(manyItemsHeight, greaterThan(oneItemHeight));
        expect(longNameHeight, greaterThan(oneItemHeight));
      },
    );

    test('BarcodeGeneratorService generates labels with Hindi & English names without missing glyphs', () async {
      final List<BarcodeLabelItem> labelItems = [
        BarcodeLabelItem(
          productName: 'किसान हुक (Kisan Hook)',
          shopName: 'OM CLOTHES',
          barcode: '8901234567890',
          sku: 'SKU-001',
          sellingPrice: 20,
          mrp: 25,
        ),
        BarcodeLabelItem(
          productName: 'बैंगनी ऊन (Wool Purple)',
          shopName: 'OM CLOTHES',
          barcode: '8909876543210',
          sku: 'SKU-002',
          sellingPrice: 130,
          mrp: 150,
        ),
      ];

      final bytes = await BarcodeGeneratorService.generatePdfBytes(
        items: labelItems,
        format: BarcodeLabelFormat.a4Sheet24,
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });

    test('FloorTokenCardsService generates 20 floor tokens on A4 with Hindi and English shop name', () async {
      final bytes = await FloorTokenCardsService.generateTokensPdf(
        shopName: 'ओम गारमेंट्स & शॉप्सिलो',
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });
  });
}
