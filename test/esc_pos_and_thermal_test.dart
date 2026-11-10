import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/pos/models/pos_model.dart';
import 'package:flutter_project_structure/features/pos/services/esc_pos_service.dart';
import 'package:flutter_project_structure/features/products/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSale = SaleModel(
    billNumber: 'BIL-TEST-001',
    customerPhone: '9876543210',
    paymentMethod: 'cash',
    subtotal: 306.0,
    discountAmount: 20.0,
    totalAmount: 286.0,
    items: [
      PosCartItem(
        product: ProductModel(
          id: 'p1',
          name: 'Aashirvaad Atta 5kg',
          price: 250.0,
          costPrice: 210.0,
          stock: 10,
          unit: 'pkt',
          category: 'Grocery',
        ),
        quantity: 1,
      ),
      PosCartItem(
        product: ProductModel(
          id: 'p2',
          name: 'Tata Salt 1kg',
          price: 28.0,
          costPrice: 22.0,
          stock: 20,
          unit: 'pkt',
          category: 'Grocery',
        ),
        quantity: 2,
      ),
    ],
  );

  test('EscPosService generates correct 80mm ESC/POS bytes with cut paper command', () {
    final bytes = EscPosService.generateReceiptBytes(
      sale: testSale,
      shopName: 'Sharma General Store',
      shopAddress: 'Gandhi Chowk, Kanpur',
      shopPhone: '9876543210',
      upiId: 'sharma@upi',
      rollWidth: EscPosRollWidth.roll80mm,
    );

    expect(bytes, isNotEmpty);
    // Begins with ESC @ (0x1B, 0x40) printer initialization
    expect(bytes[0], equals(0x1B));
    expect(bytes[1], equals(0x40));

    // Ends with paper cut command (GS V A 3 -> 0x1D, 0x56, 0x41, 0x03)
    final len = bytes.length;
    expect(bytes[len - 4], equals(0x1D));
    expect(bytes[len - 3], equals(0x56));
    expect(bytes[len - 2], equals(0x41));
    expect(bytes[len - 1], equals(0x03));
  });

  test('EscPosService generates correct 58mm ESC/POS bytes', () {
    final bytes = EscPosService.generateReceiptBytes(
      sale: testSale,
      shopName: 'Sharma Store',
      rollWidth: EscPosRollWidth.roll58mm,
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
  });
}
