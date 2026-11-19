import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/app_version_model.dart';

/// Represents lifecycle state of the in-app OTA updater.
enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  error,
}

/// Immutable state container for OTA update progress and metadata.
class AppUpdateState {
  final UpdateStatus status;
  final AppVersionModel? versionInfo;
  final double progress; // 0.0 to 1.0
  final int bytesReceived;
  final int totalBytes;
  final String? errorMessage;
  final String? downloadedFilePath;

  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.versionInfo,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.downloadedFilePath,
  });

  AppUpdateState copyWith({
    UpdateStatus? status,
    AppVersionModel? versionInfo,
    double? progress,
    int? bytesReceived,
    int? totalBytes,
    String? errorMessage,
    String? downloadedFilePath,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      versionInfo: versionInfo ?? this.versionInfo,
      progress: progress ?? this.progress,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
    );
  }
}

/// StateNotifier that coordinates version checking, APK streaming, and native installation.
class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final Dio _dio;
  CancelToken? _cancelToken;

  AppUpdateNotifier(this._dio) : super(const AppUpdateState());

  /// Checks GoBackend for published updates matching current client build number.
  Future<void> checkForUpdates() async {
    // Only check for Android or Desktop platforms (web does not use APK updater)
    if (kIsWeb) return;

    try {
      state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      final res = await ApiClient().get(
        ApiConstants.appVersionCheck,
        queryParameters: {
          'app': 'merchant_pos',
          'platform': Platform.isAndroid ? 'android' : 'windows',
          'version_code': currentCode,
        },
      );

      if (res.success && res.data != null) {
        final dynamic dataMap = res.data is Map<String, dynamic>
            ? res.data
            : (res.data as Map?)?.cast<String, dynamic>();

        if (dataMap != null) {
          final versionModel = AppVersionModel.fromJson(dataMap);
          if (versionModel.updateAvailable) {
            state = state.copyWith(
              status: UpdateStatus.available,
              versionInfo: versionModel,
            );
            return;
          }
        }
      }

      state = state.copyWith(status: UpdateStatus.idle);
    } catch (e) {
      debugPrint('[OTA Updater] Version check failed: $e');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'अपडेट चेक करने में असमर्थ: $e',
      );
    }
  }

  /// Downloads the release APK with chunked streaming and progress reporting.
  Future<void> startDownloadAndInstall() async {
    final v = state.versionInfo;
    if (v == null || v.downloadUrl.isEmpty) return;

    try {
      _cancelToken = CancelToken();
      state = state.copyWith(
        status: UpdateStatus.downloading,
        progress: 0.0,
        bytesReceived: 0,
        totalBytes: v.fileSizeBytes > 0 ? v.fileSizeBytes : 0,
        errorMessage: null,
      );

      // Resolve absolute download URL
      var targetUrl = v.downloadUrl;
      if (!targetUrl.startsWith('http')) {
        final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final path = targetUrl.startsWith('/') ? targetUrl : '/$targetUrl';
        targetUrl = '$base$path';
      }

      // Determine local cache destination
      final tempDir = await getTemporaryDirectory();
      final sanitizedVersion = v.latestVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = 'ShopSilo_Merchant_v${sanitizedVersion}_${v.latestCode}.apk';
      final filePath = '${tempDir.path}/$fileName';

      // Remove any previously corrupted or incomplete file
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        try {
          await existingFile.delete();
        } catch (_) {}
      }

      // Download with progress callback
      await _dio.download(
        targetUrl,
        filePath,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'application/vnd.android.package-archive'},
        ),
        onReceiveProgress: (received, total) {
          final effectiveTotal = total > 0 ? total : v.fileSizeBytes;
          final double computedProgress = effectiveTotal > 0
              ? (received / effectiveTotal).clamp(0.0, 1.0)
              : 0.0;

          state = state.copyWith(
            progress: computedProgress,
            bytesReceived: received,
            totalBytes: effectiveTotal,
          );
        },
      );

      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadedFilePath: filePath,
        progress: 1.0,
      );

      // Automatically trigger Android PackageInstaller
      await installApk(filePath);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        state = state.copyWith(status: UpdateStatus.available, progress: 0.0);
        return;
      }
      debugPrint('[OTA Updater] Download failed: $e');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'APK डाउनलोड विफल रहा। आप ब्राउज़र से भी डाउनलोड कर सकते हैं।',
      );
      // Fallback: Try opening download URL directly in phone browser
      await openInBrowser();
    }
  }

  /// Cancels in-progress download.
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    state = state.copyWith(status: UpdateStatus.available, progress: 0.0);
  }

  /// Launches the Android system package installer for the downloaded APK file.
  Future<void> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'डाउनलोड की गई APK फ़ाइल नहीं मिली।',
        );
        return;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'इंस्टॉलेशन शुरू नहीं हो सका: ${result.message}',
        );
      }
    } catch (e) {
      debugPrint('[OTA Updater] Install execution error: $e');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'इंस्टॉलर खोलने में त्रुटि: $e',
      );
    }
  }

  /// Opens the APK download URL directly in the device's external browser.
  Future<void> openInBrowser() async {
    final v = state.versionInfo;
    if (v == null || v.downloadUrl.isEmpty) return;
    try {
      var targetUrl = v.downloadUrl;
      if (!targetUrl.startsWith('http')) {
        final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final path = targetUrl.startsWith('/') ? targetUrl : '/$targetUrl';
        targetUrl = '$base$path';
      }
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[OTA Updater] Failed to launch browser: $e');
    }
  }

  /// Resets state back to available after an error or dismissal.
  void resetToAvailable() {
    state = state.copyWith(status: UpdateStatus.available, errorMessage: null);
  }
}

/// Global Riverpod Provider for managing in-app OTA updates.
final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5), // Allow sufficient time for 30MB downloads
    ),
  );
  return AppUpdateNotifier(dio);
});
