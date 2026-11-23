import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../storage/token_storage.dart';

class ApiConstants {
  // Use the deployed API by default; local development can be explicitly enabled.
  static const bool defaultIsProduction = bool.fromEnvironment(
    'SHOP_SILO_PRODUCTION',
    defaultValue: true,
  );
  static bool get isProduction => TokenStorage.getUseProduction(defaultValue: defaultIsProduction);
  static const String productionUrl = 'https://shopsiloapi.shopsilo.in';
  static const String localUrl = 'http://localhost:8080';

  static String get baseUrl {
    final custom = TokenStorage.getCustomServerUrl();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
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
  static const String appVersionCheck = '/api/v1/app/version-check';

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
  static const String aiMandiScan = '/ai/mandi-scan';
  static const String aiParseParchi = '/ai/parse-parchi';
  static const String aiVoiceBill = '/api/ai/voice-bill';
  static const String aiMarketingCampaign = '/api/ai/marketing-campaign';
  static const String aiMerchantCopilot = '/ai/merchant-copilot';
  static const String aiSupplierInvoice = '/api/ai/supplier-invoice';
  static const String aiCrossSell = '/api/ai/cross-sell';
  static const String aiDeadStockBundles = '/api/ai/dead-stock-bundles';
  static const String aiRecoveryNudge = '/api/ai/recovery-nudge';

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
  static String shopProductByBarcode(String barcode) => '/shops/me/products/barcode/${Uri.encodeComponent(barcode)}';
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
  static const String posParseParchi = '/shops/me/pos/parse-parchi';
  static const String posWeeklyScorecard = '/shops/me/pos/weekly-scorecard';
  static String posCustomerRecentBasket(String phone) => '/shops/me/pos/customers/$phone/recent-basket';
  static const String posReturns = '/shops/me/pos/returns';

  // --- 10A. Touch Counter Hotkeys ---
  static const String posHotkeys = '/api/pos/hotkeys';
  static const String posHotkeysAutoPopulate = '/api/pos/hotkeys/auto-populate';
  static String posHotkeyById(String id) => '/api/pos/hotkeys/$id';

  // --- 10B. Cash Drawer Shift Accountability & Safe Drops ---
  static const String drawerCurrent = '/api/pos/drawer/current';
  static const String drawerOpen = '/api/pos/drawer/open';
  static const String drawerClose = '/api/pos/drawer/close';
  static const String drawerSafeDrop = '/api/pos/drawer/safe-drop';
  static const String drawerExpense = '/api/pos/drawer/expense';
  static const String drawerHistory = '/api/pos/drawer/history';

  // --- 10C. Rush-Hour Scan & Go (Queue Buster) ---
  static const String scanGoSession = '/api/v1/customer/scan-go/session';
  static String scanGoSessionItems(String id) => '/api/v1/customer/scan-go/session/$id/items';
  static String scanGoSessionItemById(String id, String itemId) => '/api/v1/customer/scan-go/session/$id/items/$itemId';
  static String scanGoSessionById(String id) => '/api/v1/customer/scan-go/session/$id';
  static String scanGoVerify(String code) => '/api/pos/scan-go/verify/$code';
  static String scanGoConvert(String code) => '/api/pos/scan-go/convert/$code';

  // --- 10D. Company Damage Claim Vault & Receiptless Return Lookup ---
  static const String claims = '/api/claims';
  static String claimStatus(String id) => '/api/claims/$id/status';
  static const String claimsDistributorSummary = '/api/claims/distributor/summary';
  static const String posReturnsLookup = '/api/pos/returns/lookup';

  // --- 10E. Batch Expiry Radar & Near-Expiry Auto-Markdown ---
  static const String batches = '/api/batches';
  static const String batchesNearExpiry = '/api/batches/near-expiry';
  static const String batchesSummary = '/api/batches/summary';
  static const String batchMarkdownScan = '/api/batches/markdown-scan';
  static String batchMarkdown(String id) => '/api/batches/$id/markdown';
  static String batchWriteOff(String id) => '/api/batches/$id/write-off';

  // --- 10F. Khata Daily Micro-Installments ---
  static const String khataMicroPlans = '/api/khata/micro-plans';
  static String khataMicroPlanById(String id) => '/api/khata/micro-plans/$id';
  static String khataMicroPlanPay(String id) => '/api/khata/micro-plans/$id/pay';

  // --- 10G. Chromedp Automated End-of-Day P&L PDF ---
  static const String posDayCloseEodPdf = '/api/pos/day-close/eod-report.pdf';

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
  static String khataUpdateTx(String id, String txId) => '/shops/me/khata/$id/transactions/$txId';
  static String khataDeleteTx(String id, String txId) => '/shops/me/khata/$id/transactions/$txId';
  static String khataResolveDispute(String id, String txId) => '/shops/me/khata/$id/dispute/$txId/resolve';
  static String khataPromiseDate(String id) => '/shops/me/khata/$id/promise-date';
  static String khataTrustScore(String mobile) => '/shops/me/khata/$mobile/trust-score';

  // --- 13. Shop Returns & VIP Offers (Shop) ---
  static const String shopReturns = '/shops/me/returns';
  static const String shopOffers = '/shops/me/offers';
  static String shopOfferById(String id) => '/shops/me/offers/$id';
  static String shopOfferToggle(String id) => '/shops/me/offers/$id/toggle';
  static const String shopOffersHistory = '/shops/me/offers/history';
  static String storefrontOffers(String slug) => '/shops/$slug/offers';

  // --- 14. Counter Pickup Reservations (Shop) ---
  static const String shopReservations = '/shops/me/reservations';
  static const String shopReservationVerify = '/shops/me/reservations/verify';
  static String shopReservationCancel(String id) => '/shops/me/reservations/$id/cancel';

  // --- 15. Shop Procurement & Mandi Purchase Checklists (Shop) ---
  static const String shopProcurement = '/shops/me/procurement';
  static String shopProcurementById(String id) => '/shops/me/procurement/$id';
  static String shopProcurementToggle(String id) => '/shops/me/procurement/toggle/$id';
  static const String shopProcurementClearCompleted = '/shops/me/procurement/clear-completed';

  // --- 16. AI Retail Merchant Co-Pilot & Autonomous Merchandising Engine ---
  static const String copilotDailyPrescriptions = '/shops/me/copilot/daily-prescriptions';
  static String copilotExecutePrescription(String id) => '/shops/me/copilot/prescriptions/$id/execute';
  static const String copilotDeadCapital = '/shops/me/copilot/dead-capital';
  static const String copilotEvaluateBargain = '/shops/me/copilot/evaluate-bargain';
  static const String copilotSearchSubstitute = '/shops/me/copilot/search-substitute';
  static const String copilotRecalculate = '/shops/me/copilot/recalculate';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
