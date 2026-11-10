import 'dart:convert';
import 'dart:typed_data';
import '../../../core/network/base_controller.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../models/ai_features_model.dart';
import '../repositories/ai_service_repository.dart';

class AIFeaturesController extends BaseController {
  final AIServiceRepository _repo = AIServiceRepository();

  // 1. Supplier Invoice OCR Ingestion
  SupplierInvoiceResponse? _lastInvoice;
  SupplierInvoiceResponse? get lastInvoice => _lastInvoice;

  bool _isParsingInvoice = false;
  bool get isParsingInvoice => _isParsingInvoice;

  Future<SupplierInvoiceResponse?> parseSupplierInvoice({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String distributorHint = '',
  }) async {
    _isParsingInvoice = true;
    notifyListeners();

    final base64Img = base64Encode(imageBytes);
    final res = await _repo.parseSupplierInvoice(
      imageBase64: base64Img,
      mimeType: mimeType,
      distributorHint: distributorHint,
    );
    _isParsingInvoice = false;

    if (res.success && res.data != null) {
      _lastInvoice = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(
        null,
        'Parsed ${_lastInvoice!.items.length} line items from ${res.data!.distributorName} invoice!',
      );
      return _lastInvoice;
    } else {
      setError(res.error ?? 'Failed to parse supplier invoice image');
      return null;
    }
  }

  void clearInvoice() {
    _lastInvoice = null;
    notifyListeners();
  }

  // 2. Real-Time Counter Cross-Sell
  List<CrossSellSuggestion> _crossSellSuggestions = [];
  List<CrossSellSuggestion> get crossSellSuggestions => List.unmodifiable(_crossSellSuggestions);

  bool _isLoadingCrossSell = false;
  bool get isLoadingCrossSell => _isLoadingCrossSell;

  Future<void> fetchCrossSell({
    required String scannedProductName,
    String categoryHint = '',
    double price = 0.0,
  }) async {
    _isLoadingCrossSell = true;
    notifyListeners();

    final res = await _repo.getCrossSellRecommendations(
      scannedProductName: scannedProductName,
      categoryHint: categoryHint,
      price: price,
    );
    _isLoadingCrossSell = false;

    if (res.success && res.data != null) {
      _crossSellSuggestions = res.data!.recommendations;
      notifyListeners();
    } else {
      _crossSellSuggestions = [];
      notifyListeners();
    }
  }

  void clearCrossSell() {
    _crossSellSuggestions = [];
    notifyListeners();
  }

  // 3. Dead-Stock Smart Bundler
  List<DeadStockBundle> _deadStockBundles = [];
  List<DeadStockBundle> get deadStockBundles => List.unmodifiable(_deadStockBundles);

  bool _isLoadingBundles = false;
  bool get isLoadingBundles => _isLoadingBundles;

  Future<void> loadDeadStockBundles({String? shopId}) async {
    _isLoadingBundles = true;
    notifyListeners();

    final res = await _repo.getDeadStockBundles(shopId: shopId);
    _isLoadingBundles = false;

    if (res.success && res.data != null) {
      _deadStockBundles = res.data!.suggestedBundles;
      notifyListeners();
    } else {
      setError(res.error ?? 'Failed to load dead stock bundles');
    }
  }

  // 4. Respectful Psychology-Based Khata Recovery Nudges
  RecoveryNudgeResponse? _lastRecoveryNudge;
  RecoveryNudgeResponse? get lastRecoveryNudge => _lastRecoveryNudge;

  bool _isGeneratingNudge = false;
  bool get isGeneratingNudge => _isGeneratingNudge;

  Future<RecoveryNudgeResponse?> generateRecoveryNudge({
    required String customerName,
    required String customerPhone,
    required double totalDebt,
    int daysOverdue = 0,
    double dailyMicroAmount = 0.0,
    String shopUPIID = '',
    String shopName = '',
  }) async {
    _isGeneratingNudge = true;
    notifyListeners();

    final res = await _repo.generateRecoveryNudge(
      customerName: customerName,
      customerPhone: customerPhone,
      totalDebt: totalDebt,
      daysOverdue: daysOverdue,
      dailyMicroAmount: dailyMicroAmount,
      shopUPIID: shopUPIID,
      shopName: shopName,
    );
    _isGeneratingNudge = false;

    if (res.success && res.data != null) {
      _lastRecoveryNudge = res.data;
      notifyListeners();
      return _lastRecoveryNudge;
    } else {
      setError(res.error ?? 'Failed to generate smart recovery nudges');
      return null;
    }
  }

  void clearRecoveryNudge() {
    _lastRecoveryNudge = null;
    notifyListeners();
  }

  // 5. Voice-to-Bill Assistant
  VoiceBillResponse? _lastVoiceBill;
  VoiceBillResponse? get lastVoiceBill => _lastVoiceBill;

  bool _isProcessingVoice = false;
  bool get isProcessingVoice => _isProcessingVoice;

  Future<VoiceBillResponse?> processVoiceInput(String spokenText) async {
    if (spokenText.trim().isEmpty) return null;

    _isProcessingVoice = true;
    notifyListeners();

    final res = await _repo.voiceBill(spokenText: spokenText.trim());
    _isProcessingVoice = false;

    if (res.success && res.data != null) {
      _lastVoiceBill = res.data;
      notifyListeners();
      return _lastVoiceBill;
    } else {
      setError(res.error ?? 'Could not parse spoken items');
      return null;
    }
  }

  void clearVoiceBill() {
    _lastVoiceBill = null;
    notifyListeners();
  }

  // 6. Festive Marketing Campaign
  MarketingCampaignResponse? _lastMarketingCampaign;
  MarketingCampaignResponse? get lastMarketingCampaign => _lastMarketingCampaign;

  bool _isGeneratingCampaign = false;
  bool get isGeneratingCampaign => _isGeneratingCampaign;

  Future<MarketingCampaignResponse?> generateMarketingCampaign({
    String festivalName = '',
    String offerDetails = '',
    String targetAudience = '',
  }) async {
    _isGeneratingCampaign = true;
    notifyListeners();

    final res = await _repo.generateMarketingCampaign(
      festivalName: festivalName,
      offerDetails: offerDetails,
      targetAudience: targetAudience,
    );
    _isGeneratingCampaign = false;

    if (res.success && res.data != null) {
      _lastMarketingCampaign = res.data;
      notifyListeners();
      CustomSnackbar.showSuccess(null, 'Festive campaign & social copy generated!');
      return _lastMarketingCampaign;
    } else {
      setError(res.error ?? 'Failed to generate marketing campaign');
      return null;
    }
  }

  void clearCampaign() {
    _lastMarketingCampaign = null;
    notifyListeners();
  }
}

