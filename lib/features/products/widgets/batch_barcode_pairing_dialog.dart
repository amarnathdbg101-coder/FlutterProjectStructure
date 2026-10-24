import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../models/product_model.dart';

/// Assembly-Line High-Speed Continuous Camera Barcode Pairing Station.
/// Enables merchants to sit with a bulk batch of unmapped products and rapidly
/// scan physical packets one after another without closing or reopening the camera.
class BatchBarcodePairingDialog extends StatefulWidget {
  final List<ProductModel> unmappedProducts;
  final Future<bool> Function(ProductModel product, String barcode) onAssignBarcode;
  final Future<bool> Function(ProductModel product)? onAutoGenerate;
  final bool Function(String barcode)? onCheckDuplicate;

  const BatchBarcodePairingDialog({
    super.key,
    required this.unmappedProducts,
    required this.onAssignBarcode,
    this.onAutoGenerate,
    this.onCheckDuplicate,
  });

  /// Static helper to launch batch pairing station
  static Future<void> show(
    BuildContext context, {
    required List<ProductModel> unmappedProducts,
    required Future<bool> Function(ProductModel product, String barcode) onAssignBarcode,
    Future<bool> Function(ProductModel product)? onAutoGenerate,
    bool Function(String barcode)? onCheckDuplicate,
  }) {
    if (unmappedProducts.isEmpty) return Future.value();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchBarcodePairingDialog(
        unmappedProducts: unmappedProducts,
        onAssignBarcode: onAssignBarcode,
        onAutoGenerate: onAutoGenerate,
        onCheckDuplicate: onCheckDuplicate,
      ),
    );
  }

  @override
  State<BatchBarcodePairingDialog> createState() => _BatchBarcodePairingDialogState();
}

class _BatchBarcodePairingDialogState extends State<BatchBarcodePairingDialog>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final List<ProductModel> _queue;

  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnimation;

  int _currentIndex = 0;
  int _pairedCount = 0;
  bool _isTorchOn = false;
  bool _isProcessing = false;
  bool _isFinished = false;
  String _lastScannedCode = '';
  String _feedbackMessage = '';
  bool _feedbackSuccess = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _queue = List.from(widget.unmappedProducts);

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
    _debounceTimer?.cancel();
    _laserAnimCtrl.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  ProductModel? get _currentProduct {
    if (_currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  Future<void> _handleBarcode(String rawBarcode) async {
    final clean = rawBarcode.trim();
    if (clean.isEmpty || _isProcessing || clean == _lastScannedCode) return;

    final target = _currentProduct;
    if (target == null) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = clean;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _lastScannedCode = '');
      }
    });

    // 1. Audio and Haptic Feedback
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Duplicate Check
    if (widget.onCheckDuplicate != null && widget.onCheckDuplicate!(clean)) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _feedbackSuccess = false;
          _feedbackMessage = context.isHindi
              ? '⚠️ यह बारकोड ($clean) पहले से किसी उत्पाद में जुड़ा है'
              : '⚠️ Barcode ($clean) is already assigned to another item';
        });
      }
      return;
    }

    // 3. Assign to Current Product
    final success = await widget.onAssignBarcode(target, clean);

    if (mounted) {
      if (success) {
        _pairedCount++;
        setState(() {
          _isProcessing = false;
          _feedbackSuccess = true;
          _feedbackMessage = context.isHindi
              ? '✓ "${target.name}" में बारकोड ($clean) जुड़ गया!'
              : '✓ Barcode ($clean) linked to "${target.name}"!';
        });

        // Auto advance to next item after 400ms confirmation
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          _advanceToNext();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _feedbackSuccess = false;
          _feedbackMessage = context.isHindi
              ? '⚠️ बारकोड सेव करने में विफल'
              : '⚠️ Failed to save barcode';
        });
      }
    }
  }

  void _advanceToNext() {
    setState(() {
      _feedbackMessage = '';
      _isProcessing = false;
      _currentIndex++;
      if (_currentIndex >= _queue.length) {
        _isFinished = true;
      }
    });
  }

  void _skipCurrent() {
    if (_currentIndex >= _queue.length) return;
    setState(() {
      _feedbackMessage = '';
      final item = _queue.removeAt(_currentIndex);
      _queue.add(item); // push to back of queue
    });
  }

  Future<void> _handleAutoGenerate() async {
    final target = _currentProduct;
    if (target == null || _isProcessing) return;

    setState(() => _isProcessing = true);
    if (widget.onAutoGenerate != null) {
      final success = await widget.onAutoGenerate!(target);
      if (success && mounted) {
        _pairedCount++;
        setState(() {
          _isProcessing = false;
          _feedbackSuccess = true;
          _feedbackMessage = context.isHindi
              ? '✓ "${target.name}" का ऑटो बारकोड तैयार हुआ!'
              : '✓ Auto Barcode Generated for "${target.name}"!';
        });
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) _advanceToNext();
        return;
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  void _showManualEntrySheet() {
    final target = _currentProduct;
    if (target == null) return;
    final textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: sheetCtx.colorSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.keyboard_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sheetCtx.isHindi ? 'मैन्युअल बारकोड कोड दर्ज करें' : 'Enter Barcode Manually',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sheetCtx.colorTextPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${sheetCtx.isHindi ? "उत्पाद" : "Product"}: ${target.name}',
              style: TextStyle(fontSize: 12, color: sheetCtx.colorTextSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textCtrl,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'e.g. 8901234567890',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final val = textCtrl.text.trim();
                if (val.isNotEmpty) {
                  Navigator.pop(sheetCtx);
                  _handleBarcode(val);
                }
              },
              child: Text(
                sheetCtx.isHindi ? 'सहेजें और अगला उत्पाद लाएं' : 'Save & Next Product',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
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
          width: isMobile ? size.width : 540,
          height: isMobile ? size.height : 720,
          color: Colors.black,
          child: _isFinished ? _buildCelebrationScreen(context) : _buildActiveStation(context, size, isHindi),
        ),
      ),
    );
  }

  Widget _buildActiveStation(BuildContext context, Size size, bool isHindi) {
    final target = _currentProduct;
    final total = _queue.length;
    final progress = total > 0 ? (_currentIndex / total).clamp(0.0, 1.0) : 1.0;

    return Stack(
      children: [
        // 1. Live Camera Viewfinder
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
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

        // 2. Center Reticle & Scanning Laser Beam
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
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),

                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (ctx, child) {
                    return Positioned(
                      top: 260 * _laserAnimation.value,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _feedbackSuccess ? AppColors.success : AppColors.primary,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_feedbackSuccess ? AppColors.success : AppColors.primary).withValues(alpha: 0.7),
                              blurRadius: 6,
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

        // 3. Top Interactive Progress & Active Product Card
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 14,
          right: 14,
          child: Column(
            children: [
              // Header Row: Close, Title, Torch, Flip
              Row(
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
                          isHindi ? '⚡ असेंबली लाइन बारकोड पेयरिंग' : '⚡ Batch Barcode Pairing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${isHindi ? "उत्पाद" : "Product"} ${_currentIndex + 1} / $total (${isHindi ? "सफल" : "Paired"}: $_pairedCount)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isTorchOn ? AppColors.warning : Colors.white,
                    ),
                    onPressed: () async {
                      await _scannerController.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                    onPressed: () => _scannerController.switchCamera(),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 10),

              // Active Target Product Card
              if (target != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Product Thumbnail
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (target.images.isNotEmpty && target.images.first.startsWith('http'))
                              ? Image.network(
                                  target.images.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 22),
                                )
                              : const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name, Category & Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '₹${target.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (target.category.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${target.category}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 4. Feedback Toast
        if (_feedbackMessage.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _feedbackSuccess ? AppColors.success.withValues(alpha: 0.95) : AppColors.error.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
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
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 5. Bottom Action Controls
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              // Skip Current Item
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    isHindi ? 'छोड़ें (Skip)' : 'Skip',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _skipCurrent,
                ),
              ),
              const SizedBox(width: 8),

              // Auto Generate Code
              if (widget.onAutoGenerate != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      isHindi ? 'ऑटो कोड' : 'Auto Code',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleAutoGenerate,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Manual Code Input
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.keyboard_rounded, size: 16),
                  label: Text(
                    isHindi ? 'मैन्युअल' : 'Manual',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showManualEntrySheet,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationScreen(BuildContext context) {
    final isHindi = context.isHindi;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            ),
            const SizedBox(height: 20),
            Text(
              isHindi ? '🎉 बहुत बढ़िया!' : '🎉 Batch Completed!',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'सभी $_pairedCount उत्पादों में बारकोड सफलतापूर्वक जुड़ चुके हैं।'
                  : 'Successfully paired $_pairedCount products with barcodes.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                isHindi ? 'कैटलॉग देखें' : 'View Updated Catalog',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment align) {
    return Align(
      alignment: align,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: align == Alignment.topLeft || align == Alignment.topRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left: align == Alignment.topLeft || align == Alignment.bottomLeft
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
