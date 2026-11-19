import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../utils/product_photo_quality.dart';

class ProductPhotoCaptureScreen extends StatefulWidget {
  final int maxPhotos;

  const ProductPhotoCaptureScreen({super.key, required this.maxPhotos});

  @override
  State<ProductPhotoCaptureScreen> createState() =>
      _ProductPhotoCaptureScreenState();
}

class _ProductPhotoCaptureScreenState extends State<ProductPhotoCaptureScreen>
    with WidgetsBindingObserver {
  final List<(XFile, Uint8List?)> _capturedPhotos = [];
  CameraController? _cameraController;
  XFile? _reviewFile;
  Uint8List? _reviewBytes;
  XFile? _originalReviewFile;
  Uint8List? _originalReviewBytes;
  ProductPhotoStyle _selectedStyle = ProductPhotoStyle.dslrBokeh;
  bool _isPortraitModeActive = true;
  bool _isApplyingStyle = false;
  Offset? _tapFocusPoint;
  Timer? _focusIndicatorTimer;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  DateTime _lastLightSample = DateTime.fromMillisecondsSinceEpoch(0);
  ProductPhotoLighting _lighting = ProductPhotoLighting.checking;
  String? _cameraError;
  int _cameraGeneration = 0;
  bool _isInitializing = false;
  bool _isCapturing = false;
  bool _isLeaving = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    _cameraGeneration++;
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || !mounted) return;
    final generation = ++_cameraGeneration;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera is available on this device.',
        );
      }

      final camera = cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException catch (error) {
        debugPrint('[ProductPhotoCapture] Flash initialization: ${error.code}');
      }

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = math.min(await controller.getMaxZoomLevel(), 4.0);
        _currentZoom = 1.0;
      } catch (_) {}

      if (!mounted || generation != _cameraGeneration) return;
      setState(() {
        _isInitializing = false;
      });
      await _startLightingMeter(controller, generation);
    } catch (error) {
      debugPrint('[ProductPhotoCapture] Camera initialization failed: $error');
      if (controller != null) await controller.dispose();
      if (!mounted || generation != _cameraGeneration) return;
      setState(() {
        _isInitializing = false;
        _cameraError = error is CameraException
            ? error.code
            : 'camera_initialization_failed';
      });
    }
  }

  Future<void> _startLightingMeter(
    CameraController controller,
    int generation,
  ) async {
    if (!controller.supportsImageStreaming() ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages ||
        generation != _cameraGeneration) {
      return;
    }
    try {
      await controller.startImageStream(_onCameraImage);
    } on CameraException catch (error) {
      debugPrint(
        '[ProductPhotoCapture] Light meter unavailable: ${error.code}',
      );
    }
  }

  void _releaseCamera() {
    _cameraGeneration++;
    final controller = _cameraController;
    _cameraController = null;
    _isInitializing = false;
    if (mounted) setState(() {});
    if (controller != null) unawaited(controller.dispose());
  }

  void _onCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastLightSample).inMilliseconds < 450) return;
    _lastLightSample = now;

    final brightness = _measureAverageLuma(image);
    final lighting = classifyProductPhotoLighting(brightness);
    if (!mounted || lighting == _lighting) return;
    setState(() {
      _lighting = lighting;
    });
  }

  double _measureAverageLuma(CameraImage image) {
    if (image.planes.isEmpty) return 0;
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return 0;

    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final pixelStride = isBgra ? 4 : 1;
    final pixelCount = bytes.length ~/ pixelStride;
    if (pixelCount == 0) return 0;
    var sampleStep = pixelCount ~/ 1200;
    if (sampleStep < 1) sampleStep = 1;

    var total = 0.0;
    var sampleCount = 0;
    for (var pixel = 0; pixel < pixelCount; pixel += sampleStep) {
      final offset = pixel * pixelStride;
      if (isBgra) {
        final blue = bytes[offset];
        final green = bytes[offset + 1];
        final red = bytes[offset + 2];
        total += 0.114 * blue + 0.587 * green + 0.299 * red;
      } else {
        total += bytes[offset];
      }
      sampleCount++;
    }
    return sampleCount == 0 ? 0 : total / sampleCount;
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        _isCapturing ||
        _reviewFile != null ||
        _capturedPhotos.length >= widget.maxPhotos) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        throw StateError('Captured photo could not be read.');
      }

      XFile finalReviewFile;
      Uint8List finalReviewBytes;
      XFile originalFile;
      Uint8List originalBytes;
      ProductPhotoStyle initialStyle = ProductPhotoStyle.normal;

      if (_isPortraitModeActive) {
        try {
          final (styledFile, styledBytes) = await applyPhotoStyle(
            file,
            rawBytes,
            ProductPhotoStyle.dslrBokeh,
          );
          finalReviewFile = styledFile;
          finalReviewBytes = styledBytes;
          originalFile = styledFile;
          originalBytes = styledBytes;
          initialStyle = ProductPhotoStyle.dslrBokeh;
        } catch (e) {
          debugPrint('[ProductPhotoCapture] Auto DSLR Bokeh error: $e');
          final (normFile, normBytes) = await normalizeXFile(file, maxDimension: 1600, quality: 90);
          finalReviewFile = normFile;
          finalReviewBytes = normBytes;
          originalFile = normFile;
          originalBytes = normBytes;
        }
      } else {
        final (normFile, normBytes) = await normalizeXFile(file, maxDimension: 1600, quality: 90);
        finalReviewFile = normFile;
        finalReviewBytes = normBytes;
        originalFile = normFile;
        originalBytes = normBytes;
      }

      if (!mounted) return;
      setState(() {
        _originalReviewFile = originalFile;
        _originalReviewBytes = originalBytes;
        _selectedStyle = initialStyle;
        _reviewFile = finalReviewFile;
        _reviewBytes = finalReviewBytes;
      });
    } on CameraException catch (error) {
      debugPrint('[ProductPhotoCapture] Capture failed: ${error.code}');
      _showCaptureError();
    } catch (error) {
      debugPrint('[ProductPhotoCapture] Photo processing failed: $error');
      _showCaptureError();
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        if (_reviewFile == null && _cameraController == controller) {
          await _startLightingMeter(controller, _cameraGeneration);
        }
      }
    }
  }

  void _showCaptureError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('product_camera_capture_error')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _reviewFile = null;
      _reviewBytes = null;
      _originalReviewFile = null;
      _originalReviewBytes = null;
      _selectedStyle = ProductPhotoStyle.normal;
      _isApplyingStyle = false;
    });
    final controller = _cameraController;
    if (controller != null) {
      await _startLightingMeter(controller, _cameraGeneration);
    }
  }

  Future<void> _usePhoto() async {
    final file = _reviewFile;
    final bytes = _reviewBytes;
    if (file == null || bytes == null) return;

    _capturedPhotos.add((file, bytes));
    setState(() {
      _reviewFile = null;
      _reviewBytes = null;
      _originalReviewFile = null;
      _originalReviewBytes = null;
      _selectedStyle = ProductPhotoStyle.normal;
      _isApplyingStyle = false;
    });

    if (_capturedPhotos.length >= widget.maxPhotos) {
      _finish();
      return;
    }

    final controller = _cameraController;
    if (controller != null) {
      await _startLightingMeter(controller, _cameraGeneration);
    }
  }

  Future<void> _applyStyle(ProductPhotoStyle style) async {
    if (_isApplyingStyle || _selectedStyle == style) return;
    final origFile = _originalReviewFile;
    final origBytes = _originalReviewBytes;
    if (origFile == null || origBytes == null) return;

    if (style == ProductPhotoStyle.normal) {
      setState(() {
        _selectedStyle = ProductPhotoStyle.normal;
        _reviewFile = origFile;
        _reviewBytes = origBytes;
      });
      return;
    }

    setState(() => _isApplyingStyle = true);
    try {
      final (styledFile, styledBytes) = await applyPhotoStyle(
        origFile,
        origBytes,
        style,
      );
      if (!mounted) return;
      setState(() {
        _selectedStyle = style;
        _reviewFile = styledFile;
        _reviewBytes = styledBytes;
      });
    } catch (e) {
      debugPrint('[ProductPhotoCapture] Apply style error: $e');
    } finally {
      if (mounted) setState(() => _isApplyingStyle = false);
    }
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clamped);
    try {
      await controller.setZoomLevel(clamped);
    } catch (e) {
      debugPrint('[ProductPhotoCapture] Set zoom error: $e');
    }
  }

  void _onTapToFocus(TapDownDetails details, Size renderSize) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final x = (details.localPosition.dx / renderSize.width).clamp(0.0, 1.0);
    final y = (details.localPosition.dy / renderSize.height).clamp(0.0, 1.0);

    setState(() {
      _tapFocusPoint = details.localPosition;
    });

    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _tapFocusPoint = null);
    });

    try {
      await controller.setFocusPoint(Offset(x, y));
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposurePoint(Offset(x, y));
      await controller.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('[ProductPhotoCapture] Tap to focus error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || _isCapturing) return;
    final nextMode = controller.value.flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    try {
      await controller.setFlashMode(nextMode);
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      debugPrint('[ProductPhotoCapture] Flash toggle failed: ${error.code}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('product_camera_flash_unavailable')),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _finish() {
    if (_isLeaving) return;
    _isLeaving = true;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context)
            .pop(List<(XFile, Uint8List?)>.of(_capturedPhotos));
      }
    });
  }

  String get _lightingText {
    return switch (_lighting) {
      ProductPhotoLighting.checking => 'product_camera_light_checking',
      ProductPhotoLighting.tooDark => 'product_camera_light_dark',
      ProductPhotoLighting.good => 'product_camera_light_good',
      ProductPhotoLighting.tooBright => 'product_camera_light_bright',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<List<(XFile, Uint8List?)>>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 560;
              return Column(
                children: [
                  _buildHeader(context),
                  _buildGuidance(context, compact: compact),
                  Expanded(child: _buildPreviewArea()),
                  _buildLightingBadge(context),
                  if (_capturedPhotos.isNotEmpty) _buildCapturedStrip(context),
                  _buildControls(context, compact: compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final controller = _cameraController;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('btn_back'),
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('product_camera_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_capturedPhotos.length}/${widget.maxPhotos} '
                  '${context.tr('product_camera_count')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('product_camera_flash'),
            onPressed: controller == null ? null : _toggleFlash,
            icon: Icon(
              controller?.value.flashMode == FlashMode.torch
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidance(BuildContext context, {required bool compact}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 7 : 10,
        ),
        color: const Color(0xE8172437),
        child: compact
            ? Text(
                context.tr('product_camera_compact_guide'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.3,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTip(
                    Icons.center_focus_strong_rounded,
                    context.tr('product_camera_tip_frame'),
                  ),
                  const SizedBox(height: 5),
                  _buildTip(
                    Icons.straighten_rounded,
                    context.tr('product_camera_tip_angle'),
                  ),
                  const SizedBox(height: 5),
                  _buildTip(
                    Icons.wb_sunny_outlined,
                    context.tr('product_camera_tip_light'),
                  ),
                  const SizedBox(height: 5),
                  _buildTip(
                    Icons.pan_tool_alt_rounded,
                    context.tr('product_camera_tip_steady'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CC2FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    final controller = _cameraController;
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return _buildCameraError(context);
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_reviewBytes != null)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(_reviewBytes!, fit: BoxFit.contain),
                if (_isApplyingStyle)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('product_camera_applying_style'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            _buildLivePreview(controller),

          // Framing Guide overlay
          if (_reviewBytes == null)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ProductFramePainter()),
              ),
            ),

          // Quick Zoom Selector (1x, 2x)
          if (_reviewBytes == null && controller.value.isInitialized)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildZoomChip(1.0, '1x'),
                      const SizedBox(width: 4),
                      _buildZoomChip(2.0, '2x'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomChip(double zoom, String label) {
    final isSelected = (_currentZoom - zoom).abs() < 0.2;
    return InkWell(
      onTap: () => _setZoom(zoom),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = constraints.maxHeight >= constraints.maxWidth;
        final aspectRatio = isPortrait
            ? 1 / controller.value.aspectRatio
            : controller.value.aspectRatio;
        final availableRatio = constraints.maxWidth / constraints.maxHeight;
        final width = availableRatio > aspectRatio
            ? constraints.maxWidth
            : constraints.maxHeight * aspectRatio;
        final height = availableRatio > aspectRatio
            ? constraints.maxWidth / aspectRatio
            : constraints.maxHeight;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _onTapToFocus(details, Size(width, height)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  if (_tapFocusPoint != null)
                    Positioned(
                      left: _tapFocusPoint!.dx - 28,
                      top: _tapFocusPoint!.dy - 28,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.add, color: Color(0xFFFFD700), size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _cameraError == 'NoCamera'
                  ? context.tr('product_camera_no_camera')
                  : context.tr('product_camera_open_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isInitializing ? null : _initializeCamera,
              child: Text(context.tr('product_camera_retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightingBadge(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: AppBadge.info(
        context.tr(_lightingText),
        icon: Icons.light_mode_outlined,
      ),
    );
  }

  Widget _buildCapturedStrip(BuildContext context) {
    final photos = _capturedPhotos.reversed.take(5).toList().reversed.toList();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.memory(
            photos[index].$2!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildStyleChip(
    ProductPhotoStyle style,
    IconData icon,
    String label,
  ) {
    final isSelected = _selectedStyle == style;
    return InkWell(
      onTap: _isApplyingStyle ? null : () => _applyStyle(style),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraModeChip(bool isPortrait, IconData icon, String label) {
    final isSelected = _isPortraitModeActive == isPortrait;
    return InkWell(
      onTap: () => setState(() => _isPortraitModeActive = isPortrait),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, {required bool compact}) {
    final previewingPhoto = _reviewBytes != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, compact ? 6 : 12),
      child: previewingPhoto
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Real-time Photo Style Switcher (Normal, DSLR Bokeh, Studio HDR)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStyleChip(
                        ProductPhotoStyle.normal,
                        Icons.photo_camera_outlined,
                        context.tr('product_camera_style_normal'),
                      ),
                      const SizedBox(width: 8),
                      _buildStyleChip(
                        ProductPhotoStyle.dslrBokeh,
                        Icons.blur_on_rounded,
                        context.tr('product_camera_style_bokeh'),
                      ),
                      const SizedBox(width: 8),
                      _buildStyleChip(
                        ProductPhotoStyle.studioHdr,
                        Icons.auto_awesome_rounded,
                        context.tr('product_camera_style_hdr'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isCapturing || _isApplyingStyle ? null : _retakePhoto,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('product_camera_retake')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isCapturing || _isApplyingStyle ? null : _usePhoto,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(context.tr('product_camera_use_photo')),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Camera Mode Selector: Standard vs DSLR Portrait (Blur BG)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCameraModeChip(false, Icons.photo_camera_outlined, 'Standard'),
                      const SizedBox(width: 4),
                      _buildCameraModeChip(true, Icons.blur_on_rounded, '🌟 DSLR Portrait (Blur BG)'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isCapturing ? null : _finish,
                        child: Text(
                          context.tr('product_camera_done'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('product_camera_capture'),
                      onPressed: _isCapturing ? null : _capturePhoto,
                      iconSize: compact ? 58 : 68,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.circle,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                    ),
                    Expanded(
                      child: Text(
                        _isPortraitModeActive ? '🌟 Portrait' : 'Standard',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProductFramePainter extends CustomPainter {
  const _ProductFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.76,
      height: size.height * 0.72,
    );
    final roundedFrame = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(18),
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    for (var part = 1; part < 3; part++) {
      final dx = frame.left + frame.width * part / 3;
      final dy = frame.top + frame.height * part / 3;
      canvas.drawLine(Offset(dx, frame.top), Offset(dx, frame.bottom), grid);
      canvas.drawLine(Offset(frame.left, dy), Offset(frame.right, dy), grid);
    }

    final corner = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arm = math.min(frame.width, frame.height) * 0.1;
    for (final signX in [-1, 1]) {
      for (final signY in [-1, 1]) {
        final x = signX < 0 ? frame.left : frame.right;
        final y = signY < 0 ? frame.top : frame.bottom;
        canvas
          ..drawLine(Offset(x, y), Offset(x + signX * arm, y), corner)
          ..drawLine(Offset(x, y), Offset(x, y + signY * arm), corner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProductFramePainter oldDelegate) => false;
}
