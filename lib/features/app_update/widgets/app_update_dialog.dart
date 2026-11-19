import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_update_controller.dart';

/// Premium in-app OTA update dialog with progress indicators and force-update guard.
class AppUpdateDialog extends ConsumerWidget {
  const AppUpdateDialog({super.key});

  static bool _dialogShownThisSession = false;

  /// Static helper to trigger the update check and display dialog if a new version is available.
  static Future<void> showIfAvailable(BuildContext context, [WidgetRef? ref]) async {
    if (!context.mounted || _dialogShownThisSession) return;

    final notifier = ref != null
        ? ref.read(appUpdateProvider.notifier)
        : ProviderScope.containerOf(context, listen: false).read(appUpdateProvider.notifier);

    await notifier.checkForUpdates();
    if (!context.mounted) return;

    final state = ref != null
        ? ref.read(appUpdateProvider)
        : ProviderScope.containerOf(context, listen: false).read(appUpdateProvider);

    if (state.status == UpdateStatus.available && state.versionInfo != null && context.mounted) {
      _dialogShownThisSession = true;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (_) => const AppUpdateDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(appUpdateProvider);
    final version = updateState.versionInfo;

    if (version == null) return const SizedBox.shrink();

    final isDownloading = updateState.status == UpdateStatus.downloading;
    final isReadyToInstall = updateState.status == UpdateStatus.readyToInstall;
    final isError = updateState.status == UpdateStatus.error;
    final isForce = version.isForceUpdate;

    final receivedMb = (updateState.bytesReceived / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (updateState.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final percent = (updateState.progress * 100).toInt();

    return PopScope(
      canPop: !isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 20,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Icon & Version Header + Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isForce
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isForce ? Icons.warning_amber_rounded : Icons.system_update_rounded,
                      color: isForce ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isForce
                              ? '⚠️ नया ऐप अपडेट (Available)'
                              : '🚀 नया अपडेट उपलब्ध है!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isForce ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${version.latestVersion}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (version.fileSizeBytes > 0)
                              Text(
                                '~${(version.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isDownloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'बंद करें (Close)',
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Subtitle
              Text(
                isForce
                  ? 'शॉप डेटा और बिलिंग सुरक्षा के लिए इस वर्जन को अपडेट करना अनिवार्य है।'
                  : 'दुकान की बिलिंग को तेज व त्रुटिरहित रखने के लिए नवीनतम वर्जन इंस्टॉल करें।',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Release Notes Box
              if (version.releaseNotes.isNotEmpty) ...[
                const Text(
                  'नए फीचर्स व सुधार (What’s New):',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: version.releaseNotes.map((note) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Downloading Progress Indicator
              if (isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: updateState.progress > 0 ? updateState.progress : null,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$receivedMb MB / $totalMb MB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Error Banner
              if (isError && updateState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          updateState.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDownloading)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'बाद में (Later)',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: isDownloading
                        ? () => ref.read(appUpdateProvider.notifier).cancelDownload()
                        : isReadyToInstall
                            ? () {
                                final path = updateState.downloadedFilePath;
                                if (path != null) {
                                  ref.read(appUpdateProvider.notifier).installApk(path);
                                }
                              }
                            : () {
                                ref.read(appUpdateProvider.notifier).startDownloadAndInstall();
                              },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDownloading
                          ? const Color(0xFF64748B)
                          : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDownloading
                              ? Icons.close
                              : isReadyToInstall
                                  ? Icons.install_mobile
                                  : Icons.download_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDownloading
                              ? 'रद्द करें (Cancel)'
                              : isReadyToInstall
                                  ? 'इंस्टॉल करें (Install)'
                                  : isError
                                      ? 'पुनः प्रयास करें (Retry)'
                                      : 'अभी अपडेट करें (Update Now)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
