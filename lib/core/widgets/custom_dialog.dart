import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
