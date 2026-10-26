import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // ⚡ Environment Switcher:
  // Set isProduction to false for local Go backend testing (http://localhost:8080)
  // Set isProduction to true for live production deployment
  static const bool isProduction = true;
  static const String productionUrl = 'https://shopsiloapi.shopsilo.in';
  static const String localUrl = 'http://localhost:8080';

  static String get baseUrl {
    if (isProduction) {
      return productionUrl;
    }
    // Web:
    if (kIsWeb) {
      return localUrl;
    }
    // Android Emulator (10.0.2.2 maps to host PC localhost):
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    // Windows Desktop, macOS, Linux:
    return localUrl;
  }

  static String get wsUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return '${httpUrl.replaceFirst('https://', 'wss://')}/shops/me/ws';
    } else {
      return '${httpUrl.replaceFirst('http://', 'ws://')}/shops/me/ws';
    }
  }

  // --- 1. General & System (Both) ---
  static const String health = '/health';
  static const String reports = '/reports';
  static const String telemetryError = '/reports/telemetry-error';

  // --- 2. Auth Routes (Both & Shop) ---
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String staffLogin = '/auth/staff-login';
  static const String googleLogin = '/auth/google';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String refreshToken = '/auth/refresh';

  // --- 3. Categories & AI Assistants (Both & Shop) ---
  static const String categories = '/categories';
  static const String shopCategories = '/shops/me/categories';
  static const String merchantCategories = '/api/v1/merchant/categories';
  static const String aiScanProduct = '/ai/scan-product';
  static const String aiParseParchi = '/ai/parse-parchi';
  static const String aiVoiceBill = '/ai/voice-bill';
  static const String aiMarketingCampaign = '/ai/marketing-campaign';
  static const String aiBargainAssist = '/ai/bargain-assist';
  static const String aiMerchantCopilot = '/ai/merchant-copilot';

  // --- 4. User Profile (Both) ---
  static const String profile = '/user/me';
  static const String updateProfile = '/user/profile';
  static const String userAvatar = '/user/avatar';

  // --- 5. Shop Owner Management (Shop) ---
  static const String shops = '/shops';
  static const String createShop = '/shops';
  static const String myShop = '/shops/me';
  static const String shopDashboard = '/shops/me/dashboard';
  static const String shopQr = '/shops/me/qr';
  static const String shopDigest = '/shops/me/digest';
  static const String updateShopStatus = '/shops/me/status';
  static const String restoreShop = '/shops/me/restore';
  static const String shopImages = '/shops/me/images';

  // --- 6. Shop Staff & Cashiers (Shop) ---
  static const String shopStaff = '/shops/me/staff';
  static String staffById(String id) => '/shops/me/staff/$id';

  // --- 7. Products Management (Shop) ---
  static const String myProducts = '/shops/me/products';
  static const String products = '/shops/me/products';
  static const String createProduct = '/products';
  static const String productById = '/products';
  static String productDetail(String id) => '/products/$id';
  static const String productImages = '/products/images';
  static String productMarkdown(String id) => '/shops/me/products/$id/markdown';
  static const String productsBulkImport = '/shops/me/products/bulk-import';
  static const String productsImportTemplate = '/shops/me/products/import-template.csv';
  static const String productsImportTemplateCsv = '/shops/me/products/import-template.csv';
  static const String productsImportTemplateXlsx = '/shops/me/products/import-template.xlsx';
  static const String scanBarcode = '/products/scan';
  static String masterCatalogBarcode(String code) => '/catalog/barcode/${Uri.encodeComponent(code)}';
  static const String masterCatalogLookup = '/catalog/lookup'; // ?barcode=... fallback

  // --- 8. Inventory & Stock Restock (Shop) ---
  static const String adjustStock = '/shops/me/inventory/adjust';
  static const String lowStockAlerts = '/shops/me/inventory/low-stock';
  static String dismissStockAlert(String id) => '/shops/me/inventory/alerts/$id/dismiss';
  static const String demandWatchlist = '/shops/me/inventory/demand-watchlist';
  static const String reorderSheetPdf = '/shops/me/inventory/reorder-sheet.pdf';
  static const String procurementPdf = '/shops/me/inventory/procurement-pdf';
  static const String supplierReorderWhatsapp = '/shops/me/inventory/reorder/whatsapp';

  // --- 9. Shop Analytics & Profit (Shop) ---
  static const String analyticsProfit = '/shops/me/analytics/profit';
  static const String analyticsProducts = '/shops/me/analytics/products';

  // --- 10. Counter POS Billing (Shop) ---
  static const String posSale = '/shops/me/pos/sale';
  static const String posSales = '/shops/me/pos/sales';
  static String posCancelBill(String billNumber) => '/shops/me/pos/sales/$billNumber/cancel';
  static const String posDailySummary = '/shops/me/pos/daily-summary';
  static const String posSummary = '/shops/me/pos/summary';
  static String posScanSku(String sku) => '/shops/me/pos/scan/$sku';
  static String posReceiptPdf(String billNumber) => '/shops/me/pos/receipts/$billNumber';
  static String posReceiptShare(String billNumber) => '/shops/me/pos/receipts/$billNumber/share';
  static const String posDayClose = '/shops/me/pos/day-close';
  static const String posGstReport = '/shops/me/pos/gst-report';
  static const String posPark = '/shops/me/pos/park';
  static String posParkById(String id) => '/shops/me/pos/park/$id';
  static const String posBargainAssist = '/shops/me/pos/bargain-assist';
  static const String posParseParchi = '/shops/me/pos/parse-parchi';
  static const String posWeeklyScorecard = '/shops/me/pos/weekly-scorecard';
  static String posCustomerRecentBasket(String phone) => '/shops/me/pos/customers/$phone/recent-basket';
  static const String posReturns = '/shops/me/pos/returns';

  // --- 11. Store Expenses (Shop) ---
  static const String expenses = '/shops/me/expenses';
  static String expenseById(String id) => '/shops/me/expenses/$id';

  // --- 12. Customer Khata Ledger (Shop) ---
  static const String khata = '/shops/me/khata';
  static const String khataSummary = '/shops/me/khata/summary';
  static const String khataAging = '/shops/me/khata/aging';
  static String khataCustomerHistory(String mobile) => '/shops/me/khata/$mobile';
  static String khataCustomerStatement(String mobile) => '/shops/me/khata/$mobile/statement';
  static String khataPaymentReminder(String mobile) => '/shops/me/khata/$mobile/reminder';
  static String khataStatementPdf(String mobile) => '/shops/me/khata/$mobile/statement.pdf';
  static String khataStatementShare(String mobile) => '/shops/me/khata/$mobile/statement/share';
  static String khataCreditLimit(String mobile) => '/shops/me/khata/$mobile/credit-limit';
  static String khataRecordPayment(String mobile) => '/shops/me/khata/$mobile/payment';
  static String khataRequestClosure(String id) => '/shops/me/khata/$id/request-closure';
  static String khataVerifyClosureOtp(String id) => '/shops/me/khata/$id/verify-closure-otp';
  static String khataReverseTx(String id, String txId) => '/shops/me/khata/$id/transactions/$txId/reverse';
  static String khataResolveDispute(String id, String txId) => '/shops/me/khata/$id/dispute/$txId/resolve';
  static String khataPromiseDate(String id) => '/shops/me/khata/$id/promise-date';
  static String khataTrustScore(String mobile) => '/shops/me/khata/$mobile/trust-score';

  // --- 13. Shop Returns & VIP Offers (Shop) ---
  static const String shopReturns = '/shops/me/returns';
  static const String shopOffers = '/shops/me/offers';
  static String shopOfferById(String id) => '/shops/me/offers/$id';
  static const String shopOffersHistory = '/shops/me/offers/history';

  // --- 14. Counter Pickup Reservations (Shop) ---
  static const String shopReservations = '/shops/me/reservations';
  static const String shopReservationVerify = '/shops/me/reservations/verify';
  static String shopReservationCancel(String id) => '/shops/me/reservations/$id/cancel';

  // --- 15. Shop Procurement & Mandi Purchase Checklists (Shop) ---
  static const String shopProcurement = '/shops/me/procurement';
  static String shopProcurementById(String id) => '/shops/me/procurement/$id';
  static String shopProcurementToggle(String id) => '/shops/me/procurement/toggle/$id';
  static const String shopProcurementClearCompleted = '/shops/me/procurement/clear-completed';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
