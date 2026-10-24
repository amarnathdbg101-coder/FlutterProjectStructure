import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';
import '../localization/language_controller.dart';
import '../../features/products/services/smart_barcode_catalog_service.dart';

/// Interactive Mobile Camera Barcode Scanner Dialog.
/// Allows floor staff & cashiers to scan physical product barcodes directly
/// using their smartphone's back camera with 0ms detection, audio beep,
/// flashlight toggle, and continuous multi-scan mode.
class MobileBarcodeScannerDialog extends StatefulWidget {
  final Future<bool> Function(String barcode) onBarcodeScanned;
  final Future<bool> Function(String barcode, String name, double price, double mrp)? onRegisterNewProduct;
  final String? initialToken;
  final String? title;
  final String? subtitle;
  final String? targetProductName;
  final bool autoCloseOnSuccess;
  final String? successMessage;

  const MobileBarcodeScannerDialog({
    super.key,
    required this.onBarcodeScanned,
    this.onRegisterNewProduct,
    this.initialToken,
    this.title,
    this.subtitle,
    this.targetProductName,
    this.autoCloseOnSuccess = false,
    this.successMessage,
  });

  /// Static helper to launch camera scanner modal from anywhere in the app
  static Future<void> show(
    BuildContext context, {
    required Future<bool> Function(String barcode) onBarcodeScanned,
    Future<bool> Function(String barcode, String name, double price, double mrp)? onRegisterNewProduct,
    String? initialToken,
    String? title,
    String? subtitle,
    String? targetProductName,
    bool autoCloseOnSuccess = false,
    String? successMessage,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MobileBarcodeScannerDialog(
        onBarcodeScanned: onBarcodeScanned,
        onRegisterNewProduct: onRegisterNewProduct,
        initialToken: initialToken,
        title: title,
        subtitle: subtitle,
        targetProductName: targetProductName,
        autoCloseOnSuccess: autoCloseOnSuccess,
        successMessage: successMessage,
      ),
    );
  }

  @override
  State<MobileBarcodeScannerDialog> createState() => _MobileBarcodeScannerDialogState();
}

class _MobileBarcodeScannerDialogState extends State<MobileBarcodeScannerDialog> with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  final TextEditingController _manualController = TextEditingController();

  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _isProcessing = false;
  bool _continuousMode = true;
  String _lastScannedCode = '';
  String _feedbackMessage = '';
  bool _feedbackSuccess = false;
  int _scannedCount = 0;
  Timer? _sameCodeDebounce;

  @override
  void initState() {
    super.initState();
    _continuousMode = !widget.autoCloseOnSuccess;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sameCodeDebounce?.cancel();
    _laserAnimCtrl.dispose();
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String rawBarcode) async {
    final clean = rawBarcode.trim();
    if (clean.isEmpty) return;

    // Debounce exact same barcode if scanned in quick succession (1.2s cooldown)
    if (_isProcessing || clean == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = clean;
    });

    _sameCodeDebounce?.cancel();
    _sameCodeDebounce = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _lastScannedCode = '';
        });
      }
    });

    // 1. Audio and Haptic feedback
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Invoke callback to add item to POS or lookup
    final success = await widget.onBarcodeScanned(clean);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _feedbackSuccess = success;
        if (success) {
          _scannedCount++;
          if (widget.successMessage != null && widget.successMessage!.isNotEmpty) {
            _feedbackMessage = widget.successMessage!;
          } else if (widget.targetProductName != null && widget.targetProductName!.isNotEmpty) {
            _feedbackMessage = context.isHindi
                ? '✓ ${widget.targetProductName} में बारकोड ($clean) जुड़ गया!'
                : '✓ Attached Barcode ($clean) to ${widget.targetProductName}!';
          } else {
            final upper = clean.toUpperCase();
            if (upper.startsWith('SHOP-TOKEN:') || upper.startsWith('TOKEN:') || RegExp(r'^T-\d{2}$').hasMatch(upper)) {
              String token = upper;
              if (token.startsWith('SHOP-TOKEN:')) {
                token = token.substring('SHOP-TOKEN:'.length).trim();
              } else if (token.startsWith('TOKEN:')) {
                token = token.substring('TOKEN:'.length).trim();
              }
              _feedbackMessage = context.isHindi
                  ? '✓ टोकन $token सक्रिय हुआ!'
                  : '✓ Switched to Token $token!';
            } else {
              _feedbackMessage = context.isHindi
                  ? '✓ वस्तु बिल में जुड़ गई! (कोड: $clean)'
                  : '✓ Item Added to Bill! (Code: $clean)';
            }
          }
        } else {
          _feedbackMessage = context.isHindi
              ? '⚠️ उत्पाद नहीं मिला (कोड: $clean)'
              : '⚠️ Product Not Found (Code: $clean)';
        }
      });

      // If continuous mode is disabled or autoCloseOnSuccess, close after brief confirmation
      if ((!_continuousMode || widget.autoCloseOnSuccess) && success) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.isHindi;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
        child: Container(
          width: isMobile ? size.width : 520,
          height: isMobile ? size.height : 680,
          color: Colors.black,
          child: Stack(
            children: [
              // 1. Live Camera Viewfinder
              Positioned.fill(
                child: MobileScanner(
                  controller: _scannerController,
                  errorBuilder: (ctx, error) {
                    return _buildErrorState(ctx, error);
                  },
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final val = barcode.rawValue ?? barcode.displayValue;
                      if (val != null && val.trim().isNotEmpty) {
                        _handleBarcode(val.trim());
                        break;
                      }
                    }
                  },
                ),
              ),

              // 2. Scanning Reticle Overlay & Laser Beam
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _feedbackSuccess ? AppColors.success : Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      // Target corner brackets
                      _buildCorner(Alignment.topLeft),
                      _buildCorner(Alignment.topRight),
                      _buildCorner(Alignment.bottomLeft),
                      _buildCorner(Alignment.bottomRight),

                      // Animated Laser Scanning Line
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (ctx, child) {
                          return Positioned(
                            top: 260 * _laserAnimation.value,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: _feedbackSuccess ? AppColors.success : AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_feedbackSuccess ? AppColors.success : AppColors.primary).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Top Action Bar: Torch, Flip Camera, Title & Close
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? (isHindi ? 'कैमरा बारकोड स्कैनर' : 'Camera Barcode Scanner'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (widget.initialToken != null)
                            Text(
                              '${isHindi ? "टोकन" : "Token"}: ${widget.initialToken}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    // Torch / Flashlight Toggle
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? AppColors.warning : Colors.white,
                      ),
                      tooltip: isHindi ? 'टॉर्च चालू/बंद करें' : 'Toggle Flashlight',
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      },
                    ),
                    // Camera Switch (Back / Front)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      tooltip: isHindi ? 'कैमरा बदलें' : 'Switch Camera',
                      onPressed: () => _scannerController.switchCamera(),
                    ),
                  ],
                ),
              ),

              // 4. Floating Guidance Subtitle / Target Product Banner
              Positioned(
                top: (size.height / 2) - 170,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.targetProductName != null ? Icons.label_important_rounded : Icons.crop_free_rounded,
                          size: 14,
                          color: widget.targetProductName != null ? AppColors.primary : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.targetProductName != null
                                ? '${isHindi ? "लक्ष्य" : "Target"}: ${widget.targetProductName}'
                                : (isHindi
                                    ? 'बारकोड को चौकोर बॉक्स के अंदर लाएं'
                                    : 'Align barcode inside square frame'),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Feedback Toast Card
              if (_feedbackMessage.isNotEmpty)
                Positioned(
                  top: (size.height / 2) + 140,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _feedbackSuccess ? AppColors.success.withValues(alpha: 0.95) : AppColors.error.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _feedbackSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _feedbackMessage,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (!_feedbackSuccess && widget.onRegisterNewProduct != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.flash_on_rounded, size: 16),
                              label: Text(
                                isHindi ? 'तुरंत नया उत्पाद जोड़ें' : 'Quick Add New Product',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _showQuickAddDialog(context, _lastScannedCode),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 6. Bottom Controls: Continuous Scan & Manual Barcode Input
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Continuous Scan Pill & Count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _continuousMode ? Icons.repeat_rounded : Icons.filter_1_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isHindi ? 'निरंतर स्कैनिंग (एक के बाद एक)' : 'Continuous Scan Mode',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: _continuousMode,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _continuousMode = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Manual Type Fallback Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _manualController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: isHindi ? 'मैन्युअल बारकोड कोड...' : 'Type barcode manually...',
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  _handleBarcode(val.trim());
                                  _manualController.clear();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final val = _manualController.text.trim();
                            if (val.isNotEmpty) {
                              _handleBarcode(val);
                              _manualController.clear();
                            }
                          },
                          child: Text(isHindi ? 'जोड़ें' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            _scannedCount > 0
                                ? (isHindi ? 'हो गया ($_scannedCount)' : 'Done ($_scannedCount)')
                                : (isHindi ? 'बंद करें' : 'Close'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, MobileScannerException error) {
    final isHindi = context.isHindi;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, size: 54, color: AppColors.warning),
            const SizedBox(height: 14),
            Text(
              isHindi ? 'कैमरा चालू नहीं हो सका' : 'Camera Unavailable',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isHindi
                  ? 'कृपया डिवाइस सेटिंग्स में कैमरा परमिशन दें या USB स्कैनर / नीचे दिए गए बॉक्स का उपयोग करें।'
                  : 'Please check camera permissions or use a USB barcode gun / manual entry below.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => _scannerController.start(),
              child: Text(isHindi ? 'दोबारा प्रयास करें' : 'Retry Camera'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context, String rawBarcode) {
    final isHindi = context.isHindi;
    final masterMatch = SmartBarcodeCatalogService.lookupSync(rawBarcode);
    final nameCtrl = TextEditingController(text: masterMatch?.name ?? '');
    final priceCtrl = TextEditingController(
      text: masterMatch != null && masterMatch.sellingPrice > 0 ? masterMatch.sellingPrice.toStringAsFixed(0) : '',
    );
    final mrpCtrl = TextEditingController(
      text: masterMatch != null && masterMatch.mrp > 0 ? masterMatch.mrp.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          top: 16,
          left: 20,
          right: 20,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
          maxWidth: 540,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: sheetCtx.colorBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sheetCtx.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? 'नया उत्पाद तुरंत जोड़ें' : 'Quick Add New Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sheetCtx.colorTextPrimary,
                          ),
                        ),
                        Text(
                          '${isHindi ? "बारकोड" : "Barcode"}: $rawBarcode',
                          style: TextStyle(fontSize: 11, color: sheetCtx.colorTextMuted, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              if (masterMatch != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.success, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isHindi
                              ? '⚡ मास्टर कैटलॉग से विवरण लोड हुआ (${masterMatch.brand})'
                              : '⚡ Master Catalog Auto-Match (${masterMatch.brand})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isHindi ? 'उत्पाद का नाम *' : 'Product Name *',
                  hintText: isHindi ? 'उदा. पारले-जी 100 ग्राम' : 'e.g. Parle-G 100g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isHindi ? 'बिक्री मूल्य (₹) *' : 'Selling Price (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: mrpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isHindi ? 'एमआरपी (₹)' : 'MRP (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final mrp = double.tryParse(mrpCtrl.text.trim()) ?? price;
                  if (name.isEmpty || price <= 0) return;

                  Navigator.pop(sheetCtx);
                  if (widget.onRegisterNewProduct != null) {
                    final ok = await widget.onRegisterNewProduct!(rawBarcode, name, price, mrp);
                    if (ok && mounted) {
                      setState(() {
                        _scannedCount++;
                        _feedbackSuccess = true;
                        _feedbackMessage = isHindi
                            ? '✓ $name बिल में जुड़ गया!'
                            : '✓ $name Added to Bill!';
                      });
                    }
                  }
                },
                child: Text(
                  isHindi ? 'जोड़ें और बिल में शामिल करें' : 'Save & Add to Bill',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
