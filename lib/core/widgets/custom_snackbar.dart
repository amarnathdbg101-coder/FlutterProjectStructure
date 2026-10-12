import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../routes/app_router.dart';
import '../storage/token_storage.dart';

enum SnackbarType { error, success, warning, info }

/// Enterprise-grade, Universal Notification & Toast Engine for ShopSilo Merchant App.
/// Delivers zero-clutter, minimalist, high-contrast floating toasts that work seamlessly
/// across all screens, both with [BuildContext] and globally via [rootScaffoldMessengerKey].
class CustomSnackbar {
  static String? _lastMessage;
  static DateTime? _lastTime;

  /// Display a user-friendly error toast anywhere in the app.
  static void showError(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    _show(
      context: context,
      message: message,
      title: title,
      duration: duration,
      type: SnackbarType.error,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }

  /// Display a user-friendly success toast.
  static void showSuccess(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      title: title,
      duration: duration,
      type: SnackbarType.success,
    );
  }

  /// Display a warning toast.
  static void showWarning(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      title: title,
      duration: duration,
      type: SnackbarType.warning,
    );
  }

  /// Display an informative toast.
  static void showInfo(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      title: title,
      duration: duration,
      type: SnackbarType.info,
    );
  }

  static void _show({
    required BuildContext? context,
    required String message,
    required SnackbarType type,
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    final cleanMsg = message.trim();
    if (cleanMsg.isEmpty) return;

    // Deduplication filter: Avoid spamming duplicate toasts within 2.2 seconds
    final now = DateTime.now();
    if (_lastMessage == cleanMsg &&
        _lastTime != null &&
        now.difference(_lastTime!) < const Duration(milliseconds: 2200)) {
      return;
    }
    _lastMessage = cleanMsg;
    _lastTime = now;

    // Locate active ScaffoldMessenger
    final messenger = (context != null && context.mounted)
        ? ScaffoldMessenger.maybeOf(context) ?? rootScaffoldMessengerKey.currentState
        : rootScaffoldMessengerKey.currentState;

    if (messenger == null) return;

    final isHindi = TokenStorage.getLanguage() == 'hi';

    // Status colors and icons
    Color accentColor;
    Color iconBgColor;
    IconData iconData;
    String defaultTitle;

    switch (type) {
      case SnackbarType.error:
        accentColor = AppColors.error;
        iconBgColor = AppColors.error.withValues(alpha: 0.2);
        iconData = Icons.error_outline_rounded;
        defaultTitle = isHindi ? 'त्रुटि' : 'Error';
        break;
      case SnackbarType.success:
        accentColor = AppColors.success;
        iconBgColor = AppColors.success.withValues(alpha: 0.2);
        iconData = Icons.check_circle_rounded;
        defaultTitle = isHindi ? 'सफल' : 'Success';
        break;
      case SnackbarType.warning:
        accentColor = const Color(0xFFF59E0B);
        iconBgColor = const Color(0xFFF59E0B).withValues(alpha: 0.2);
        iconData = Icons.warning_amber_rounded;
        defaultTitle = isHindi ? 'सूचना' : 'Notice';
        break;
      case SnackbarType.info:
        accentColor = AppColors.primary;
        iconBgColor = AppColors.primary.withValues(alpha: 0.2);
        iconData = Icons.info_outline_rounded;
        defaultTitle = isHindi ? 'जानकारी' : 'Info';
        break;
    }

    final displayTitle = title ?? (cleanMsg.length > 50 ? defaultTitle : null);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        padding: EdgeInsets.zero,
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Minimalist deep Slate-900
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconData, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayTitle != null) ...[
                          Text(
                            displayTitle,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          cleanMsg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        messenger.hideCurrentSnackBar();
                        onRetry();
                      },
                      child: Text(
                        retryLabel ?? (isHindi ? 'पुनः प्रयास' : 'Retry'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => messenger.hideCurrentSnackBar(),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
