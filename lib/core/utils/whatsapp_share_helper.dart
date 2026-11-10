import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';

/// Universal, robust WhatsApp & Storefront Link sharing utility for ShopSilo.
/// Implements multi-tier fallback:
/// 1. Native WhatsApp App URI Scheme (whatsapp://send)
/// 2. Universal wa.me Web Link
/// 3. Direct wa.me launch
/// 4. api.whatsapp.com Web Link
/// 5. Graceful Clipboard Copy with clear user feedback
class WhatsAppShareHelper {
  WhatsAppShareHelper._();

  /// Shares a message or customer slip directly to WhatsApp.
  /// If [phone] is supplied, opens chat directly with that number.
  /// If [phone] is omitted, opens WhatsApp conversation picker / status share.
  static Future<bool> shareToWhatsApp({
    required BuildContext context,
    String phone = '',
    required String message,
    String? successToast,
    String? fallbackToast,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.isNotEmpty
        ? (cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone)
        : '';

    final encodedMsg = Uri.encodeComponent(message);

    // 1. Native WhatsApp App URI Scheme
    final nativeUri = formattedPhone.isNotEmpty
        ? Uri.parse('whatsapp://send?phone=$formattedPhone&text=$encodedMsg')
        : Uri.parse('whatsapp://send?text=$encodedMsg');

    // 2. Universal wa.me Web Link
    final waMeUri = formattedPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$formattedPhone?text=$encodedMsg')
        : Uri.parse('https://wa.me/?text=$encodedMsg');

    // 3. Official WhatsApp API Web Link
    final apiUri = formattedPhone.isNotEmpty
        ? Uri.parse('https://api.whatsapp.com/send?phone=$formattedPhone&text=$encodedMsg')
        : Uri.parse('https://api.whatsapp.com/send?text=$encodedMsg');

    // Tier 1: Try Native WhatsApp App Scheme
    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched = await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
        if (launched) return true;
      }
    } catch (_) {
      // Continue to Tier 2
    }

    // Tier 2: Try wa.me with canLaunchUrl
    try {
      if (await canLaunchUrl(waMeUri)) {
        final launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {
      // Continue to Tier 3
    }

    // Tier 3: Direct launch waMeUri without checking canLaunchUrl (some devices restrict canLaunchUrl)
    try {
      final launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {
      // Continue to Tier 4
    }

    // Tier 4: Try api.whatsapp.com
    try {
      final launched = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {
      // Continue to Clipboard Fallback
    }

    // Tier 5: Fallback to Clipboard Copy with clear explanatory feedback
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      final isHindi = context.isHindi;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fallbackToast ??
                (isHindi
                    ? 'WhatsApp नहीं खुला - लिंक/विवरण क्लिपबोर्ड पर कॉपी हो गया!'
                    : 'WhatsApp not available - Details copied to clipboard!'),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  /// 1-Tap Share Storefront Website & Online Store Link
  static Future<bool> shareStorefront({
    required BuildContext context,
    required String shopName,
    required String shopSlug,
    String? customMessage,
  }) async {
    final storefrontUrl = 'https://shopsilo.in/shop/$shopSlug';
    final isHindi = context.isHindi;

    final message = customMessage ??
        (isHindi
            ? '🛍️ *नमस्ते! $shopName की ऑनलाइन दुकान पर आपका स्वागत है!*\n\n'
                'हमारे सभी उत्पाद देखें, लाइव रेट चेक करें और 15-मिनट काउंटर पिकअप के लिए ऑर्डर करें:\n'
                '👉 ऑनलाइन स्टोर लिंक: $storefrontUrl\n\n'
                'ShopSilo द्वारा संचालित डिजिटल स्टोर'
            : '🛍️ *Welcome to $shopName Online Store!*\n\n'
                'Browse our live catalog, check prices & reserve items for instant counter pickup:\n'
                '👉 Store Link: $storefrontUrl\n\n'
                'Powered by ShopSilo');

    return shareToWhatsApp(
      context: context,
      message: message,
    );
  }

  /// 1-Tap Share Product Link from Storefront
  static Future<bool> shareProduct({
    required BuildContext context,
    required String productName,
    required double price,
    double? comparePrice,
    required String productId,
    required String shopSlug,
    String? shopName,
  }) async {
    final isHindi = context.isHindi;
    final productUrl = shopSlug.isNotEmpty
        ? 'https://shopsilo.in/shop/$shopSlug/product/$productId'
        : 'https://shopsilo.in/product/$productId';

    String priceStr = '₹${price.toStringAsFixed(0)}';
    if (comparePrice != null && comparePrice > price) {
      final disc = (((comparePrice - price) / comparePrice) * 100).round();
      priceStr += isHindi ? ' (MRP: ₹${comparePrice.toStringAsFixed(0)}, $disc% छूट)' : ' (MRP: ₹${comparePrice.toStringAsFixed(0)}, $disc% OFF)';
    }

    final storeLine = (shopName != null && shopName.isNotEmpty)
        ? (isHindi ? '🏪 दुकान: $shopName\n' : '🏪 Store: $shopName\n')
        : '';

    final message = isHindi
        ? '🛒 *$productName*\n'
            '💰 कीमत: $priceStr\n'
            '$storeLine'
            '👉 ShopSilo पर ऑनलाइन देखें व ऑर्डर करें:\n$productUrl\n\n'
            'ShopSilo 15-Minute Counter Pickup'
        : '🛒 *$productName*\n'
            '💰 Price: $priceStr\n'
            '$storeLine'
            '👉 View & Order online on ShopSilo:\n$productUrl\n\n'
            'ShopSilo 15-Minute Counter Pickup';

    return shareToWhatsApp(
      context: context,
      message: message,
    );
  }
}

