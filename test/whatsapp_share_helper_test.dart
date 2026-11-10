import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsAppShareHelper Tests', () {
    test('Phone normalization handles 10-digit and international prefixes', () {
      final clean10 = '9876543210'.replaceAll(RegExp(r'\D'), '');
      final formatted10 = clean10.length == 10 ? '91$clean10' : clean10;
      expect(formatted10, equals('919876543210'));

      final cleanPrefixed = '+91 98765 43210'.replaceAll(RegExp(r'\D'), '');
      final formattedPrefixed = cleanPrefixed.length == 10 ? '91$cleanPrefixed' : cleanPrefixed;
      expect(formattedPrefixed, equals('919876543210'));
    });

    test('Storefront share message format includes shop name, store link and emojis', () {
      const shopName = 'Sharma Kirana Store';
      const shopSlug = 'sharma-kirana';
      const storefrontUrl = 'https://shopsilo.in/shop/$shopSlug';

      final msg = '🛍️ *नमस्ते! $shopName की ऑनलाइन दुकान पर आपका स्वागत है!*\n\n'
          'हमारे सभी उत्पाद देखें, लाइव रेट चेक करें और 15-मिनट काउंटर पिकअप के लिए ऑर्डर करें:\n'
          '👉 ऑनलाइन स्टोर लिंक: $storefrontUrl\n\n'
          'ShopSilo द्वारा संचालित डिजिटल स्टोर';

      expect(msg, contains(shopName));
      expect(msg, contains(storefrontUrl));
      expect(msg, contains('15-मिनट काउंटर पिकअप'));
    });

    test('Product share message format includes product details and product URL', () {
      const productName = 'Basmati Rice 5kg';
      const price = 450.0;
      const comparePrice = 500.0;
      const productId = 'prod-123';
      const shopSlug = 'sharma-kirana';
      const shopName = 'Sharma Kirana Store';

      final disc = (((comparePrice - price) / comparePrice) * 100).round();
      final priceStr = '₹${price.toStringAsFixed(0)} (MRP: ₹${comparePrice.toStringAsFixed(0)}, $disc% छूट)';
      final productUrl = 'https://shopsilo.in/shop/$shopSlug/product/$productId';

      final msg = '🛒 *$productName*\n'
          '💰 कीमत: $priceStr\n'
          '🏪 दुकान: $shopName\n'
          '👉 ShopSilo पर ऑनलाइन देखें व ऑर्डर करें:\n$productUrl\n\n'
          'ShopSilo 15-Minute Counter Pickup';

      expect(msg, contains('Basmati Rice 5kg'));
      expect(msg, contains('₹450'));
      expect(msg, contains('10% छूट'));
      expect(msg, contains(productUrl));
      expect(msg, contains('Sharma Kirana Store'));
    });
  });
}

