import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/features/pos/models/ai_features_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();
  });

  group('ShopSilo AI Features & Intelligence Engine Suite Tests', () {
    test('1. SupplierInvoiceResponse (Photo-to-Inventory OCR) parses correctly', () {
      final json = {
        'distributor_name': 'Hindustan Unilever Distributor Pvt Ltd',
        'distributor_phone': '9876543210',
        'invoice_number': 'HUL/2026/OCT/9021',
        'invoice_date': '2026-10-24',
        'total_amount': 18500.0,
        'extracted_notes': 'Verified stamp from central warehouse',
        'items': [
          {
            'product_name': 'Surf Excel Quick Wash 1kg',
            'quantity': 24,
            'unit_cost': 120.0,
            'suggested_mrp': 150.0,
            'gst_percent': 18.0,
            'total_price': 2880.0,
            'batch_number': 'B-7729',
            'expiry_date': '2028-10-01',
          },
          {
            'product_name': 'Lifebuoy Total Soap 125g',
            'quantity': 72,
            'unit_cost': 28.5,
            'suggested_mrp': 38.0,
            'gst_percent': 12.0,
            'total_price': 2052.0,
            'batch_number': 'LB-091',
            'expiry_date': '2027-06-15',
          }
        ],
      };

      final res = SupplierInvoiceResponse.fromJson(json);

      expect(res.distributorName, 'Hindustan Unilever Distributor Pvt Ltd');
      expect(res.distributorPhone, '9876543210');
      expect(res.invoiceNumber, 'HUL/2026/OCT/9021');
      expect(res.invoiceDate, '2026-10-24');
      expect(res.totalAmount, 18500.0);
      expect(res.extractedNotes, 'Verified stamp from central warehouse');
      expect(res.items.length, 2);

      final item1 = res.items.first;
      expect(item1.productName, 'Surf Excel Quick Wash 1kg');
      expect(item1.quantity, 24);
      expect(item1.unitCost, 120.0);
      expect(item1.suggestedMRP, 150.0);
      expect(item1.gstPercent, 18.0);
      expect(item1.totalPrice, 2880.0);
      expect(item1.batchNumber, 'B-7729');
      expect(item1.expiryDate, '2028-10-01');
    });

    test('2. CrossSellResponse (Real-Time Counter Pitch) parses correctly', () {
      final json = {
        'scanned_product': 'Tata Tea Gold 500g',
        'recommendations': [
          {
            'suggested_product_name': 'Parle-G Gold Biscuits 1kg Pack',
            'category': 'Snacks & Biscuits',
            'estimated_price': 110.0,
            'margin_boost': 14.5,
            'cashier_script_hinglish': 'Bhaiya, chai ke sath naya Parle-G Gold pack sirf ₹110 me add kar du? Mast crispy combo ban jayega!',
            'reason': 'High co-purchase correlation (78%) with Premium Tea',
          }
        ]
      };

      final res = CrossSellResponse.fromJson(json);

      expect(res.scannedProduct, 'Tata Tea Gold 500g');
      expect(res.recommendations.length, 1);

      final rec = res.recommendations.first;
      expect(rec.suggestedProductName, 'Parle-G Gold Biscuits 1kg Pack');
      expect(rec.category, 'Snacks & Biscuits');
      expect(rec.estimatedPrice, 110.0);
      expect(rec.marginBoost, 14.5);
      expect(rec.cashierScriptHinglish, contains('Bhaiya, chai ke sath'));
      expect(rec.reason, contains('High co-purchase correlation'));
    });

    test('3. DeadStockResponse (Combo Liquidation Bundles) parses correctly', () {
      final json = {
        'suggested_bundles': [
          {
            'bundle_name': 'Morning Breakfast Saver Pack',
            'slow_moving_item': 'Kellogg Chocos 375g (Unsold 45 days)',
            'fast_moving_anchor': 'Amul Taaza Milk 1L',
            'original_total': 255.0,
            'bundle_price': 210.0,
            'customer_savings': 45.0,
            'estimated_profit': 32.0,
            'pitch_line_hinglish': 'Slow stock Chocos ko roz bikne wale Amul Taaza ke sath combine karke fast liquidate karein.',
          }
        ]
      };

      final res = DeadStockResponse.fromJson(json);

      expect(res.suggestedBundles.length, 1);
      final b = res.suggestedBundles.first;
      expect(b.bundleName, 'Morning Breakfast Saver Pack');
      expect(b.slowMovingItem, contains('Kellogg Chocos'));
      expect(b.fastMovingAnchor, 'Amul Taaza Milk 1L');
      expect(b.originalTotal, 255.0);
      expect(b.bundlePrice, 210.0);
      expect(b.customerSavings, 45.0);
      expect(b.estimatedProfit, 32.0);
      expect(b.pitchLineHinglish, contains('Slow stock Chocos'));
    });

    test('4. RecoveryNudgeResponse (WhatsApp Psychology + UPI) parses correctly', () {
      final json = {
        'customer_name': 'Vikas Sharma',
        'gentle_nudge': 'Namaste Vikas ji, ShopSilo store se aapka ₹1,450 ka hisab baaki hai. Suvidha anusar settle kar lein.',
        'micro_plan_nudge': 'Bhaiya, ek sath ₹1,450 na ho toh koi baat nahi! Sirf ₹100 roz UPI se dekar bina bojh ke khata clear karein.',
        'formal_notice': 'M/s ShopSilo Account Notice: Balance ₹1,450 overdue by 18 days. Please clear via link to keep credit line open.',
        'upi_payment_link': 'upi://pay?pa=shopsilo@upi&pn=ShopSilo&am=1450&cu=INR',
      };

      final res = RecoveryNudgeResponse.fromJson(json);

      expect(res.customerName, 'Vikas Sharma');
      expect(res.gentleNudge, contains('Namaste Vikas ji'));
      expect(res.microPlanNudge, contains('Sirf ₹100 roz UPI'));
      expect(res.formalNotice, contains('overdue by 18 days'));
      expect(res.upiPaymentLink, startsWith('upi://pay'));
    });

    test('5. VoiceBillResponse (Hinglish Mic Speech-to-Bill) parses correctly', () {
      final json = {
        'spoken_text': '2 packet doodh, ek butter aur teen Tata salt laga do',
        'matched_items': [
          {
            'product_id': 'prod-milk-01',
            'product_name': 'Amul Taaza Milk 500ml',
            'quantity': 2.0,
            'unit': 'pkt',
            'unit_price': 27.0,
            'total_price': 54.0,
          },
          {
            'product_id': 'prod-butter-01',
            'product_name': 'Amul Pasteurised Butter 100g',
            'quantity': 1.0,
            'unit': 'pc',
            'unit_price': 58.0,
            'total_price': 58.0,
          },
          {
            'product_id': 'prod-salt-01',
            'product_name': 'Tata Salt Vacuum Evaporated 1kg',
            'quantity': 3.0,
            'unit': 'pkt',
            'unit_price': 28.0,
            'total_price': 84.0,
          }
        ],
        'unmatched_text': ['laga do'],
        'total_amount': 196.0,
      };

      final res = VoiceBillResponse.fromJson(json);

      expect(res.spokenText, '2 packet doodh, ek butter aur teen Tata salt laga do');
      expect(res.matchedItems.length, 3);
      expect(res.matchedItems[0].productName, 'Amul Taaza Milk 500ml');
      expect(res.matchedItems[0].quantity, 2.0);
      expect(res.matchedItems[0].totalPrice, 54.0);
      expect(res.matchedItems[1].productName, 'Amul Pasteurised Butter 100g');
      expect(res.matchedItems[2].quantity, 3.0);
      expect(res.matchedItems[2].unitPrice, 28.0);
      expect(res.matchedItems[2].totalPrice, 84.0);
      expect(res.unmatchedText, contains('laga do'));
      expect(res.totalAmount, 196.0);
    });

    test('6. MarketingCampaignResponse (Festive Posters & WhatsApp Broadcast) parses correctly', () {
      final json = {
        'headline': '🎇 Is Diwali, ShopSilo Ke Sath Khushiyan Aur Bada Bachat!',
        'whatsapp_message': 'Namaste Padosiyo! 🪔\nDiwali Special Dhamaka me paayein:\n✨ Flat 20% OFF Sabhi Grocery items par!\n🎁 ₹2,000 ki shopping par Free Surprise Gift Box!\nVisit karein aaj hi aapki apni dukaan ShopSilo par!',
        'social_post_text': 'Ghar sajao, mithai khao aur ShopSilo ke bumper festive offers ka faayda uthao! Available till stocks last. #DiwaliSale',
        'suggested_hashtags': ['#DiwaliOffers', '#ShopLocal', '#GroceryDeals', '#BachatHiBachat'],
      };

      final res = MarketingCampaignResponse.fromJson(json);

      expect(res.headline, contains('Is Diwali'));
      expect(res.whatsappMessage, contains('Namaste Padosiyo'));
      expect(res.socialPostText, contains('Ghar sajao'));
      expect(res.suggestedHashtags.length, 4);
      expect(res.suggestedHashtags, contains('#ShopLocal'));
    });
  });
}
