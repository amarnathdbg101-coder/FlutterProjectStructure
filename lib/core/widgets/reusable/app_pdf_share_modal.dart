import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../localization/language_controller.dart';

/// Industrial-Grade Universal PDF Action & Native Share Sheet
/// Empowers merchants to share generated PDFs across Bluetooth, WhatsApp,
/// Instagram, Quick Share / Nearby Share, Gmail, Google Drive, and Thermal/A4 Printers.
class AppPdfShareModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String filename;
  final Future<Uint8List> Function() getPdfBytes;
  final String? customerPhone;
  final String? customerName;

  const AppPdfShareModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.filename,
    required this.getPdfBytes,
    this.customerPhone,
    this.customerName,
  });

  /// Opens the industrial PDF action modal with 1-tap Native Sharing & Printing
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String filename,
    required Future<Uint8List> Function() getPdfBytes,
    String? customerPhone,
    String? customerName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppPdfShareModal(
        title: title,
        subtitle: subtitle,
        filename: filename,
        getPdfBytes: getPdfBytes,
        customerPhone: customerPhone,
        customerName: customerName,
      ),
    );
  }

  /// Directly invokes the OS native share sheet (Bluetooth, WhatsApp, Instagram, etc.)
  static Future<void> shareBytes({
    required Uint8List bytes,
    required String filename,
    String? subject,
    String? body,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename.endsWith('.pdf') ? filename : '$filename.pdf',
      subject: subject,
      body: body,
    );
  }

  /// Directly sends the PDF bytes to the system printer spooler
  static Future<void> printBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename.endsWith('.pdf') ? filename : '$filename.pdf',
    );
  }

  @override
  State<AppPdfShareModal> createState() => _AppPdfShareModalState();
}

class _AppPdfShareModalState extends State<AppPdfShareModal> {
  Uint8List? _cachedBytes;
  bool _isLoading = false;
  String _activeAction = ''; // 'share', 'print', 'load'

  Future<Uint8List> _resolveBytes() async {
    if (_cachedBytes != null) return _cachedBytes!;
    setState(() => _isLoading = true);
    try {
      final bytes = await widget.getPdfBytes();
      _cachedBytes = bytes;
      return bytes;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _activeAction = 'share');
    try {
      final bytes = await _resolveBytes();
      if (!mounted) return;
      await AppPdfShareModal.shareBytes(
        bytes: bytes,
        filename: widget.filename,
        subject: widget.title,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.isHindi ? 'PDF शेयर करने में त्रुटि: $e' : 'Failed to share PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeAction = '');
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _activeAction = 'print');
    try {
      final bytes = await _resolveBytes();
      if (!mounted) return;
      await AppPdfShareModal.printBytes(
        bytes: bytes,
        filename: widget.filename,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.isHindi ? 'प्रिंट करने में त्रुटि: $e' : 'Failed to print PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeAction = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.isHindi;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 580,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header with PDF Icon & Document Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                const SizedBox(height: 16),

                // Primary Action 1: Native Share Sheet (Bluetooth, WhatsApp, Instagram, etc.)
                InkWell(
                  onTap: _isLoading ? null : _handleShare,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _activeAction == 'share'
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isHindi ? 'शेयर करें (Share PDF)' : 'Share PDF Document',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isHindi ? 'ब्लूटूथ • व्हाट्सएप' : 'All Apps',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isHindi
                                    ? 'ब्लूटूथ, व्हाट्सएप, इंस्टाग्राम, क्विक शेयर, ड्राइव, ईमेल आदि'
                                    : 'Bluetooth, WhatsApp, Instagram, Quick Share, Drive, Email',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Primary Action 2: Print / Preview Spooler
                InkWell(
                  onTap: _isLoading ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.border,
                            ),
                          ),
                          child: _activeAction == 'print'
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.print_rounded,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isHindi ? 'प्रिंट करें (Print / Preview)' : 'Print Document',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isHindi
                                    ? 'थर्मल या सामान्य A4 प्रिंटर पर प्रिंट निकालें'
                                    : 'Send to Thermal or standard A4 printer',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
