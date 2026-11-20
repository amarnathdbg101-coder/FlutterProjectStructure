import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable AI Chat & Doubt Input Bar
/// Standardized across AiTutorChatScreen, DashboardScreen, and Modal Sheets.
class AiChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onSend;
  final VoidCallback? onAttachImage;
  final VoidCallback? onToggleVoiceRecord;
  final VoidCallback? onLongPressVoiceRecord;
  final bool isRecordingVoice;
  final bool isLoading;
  final bool isStreaming;
  final VoidCallback? onStop;
  final String hintText;
  final bool isDark;
  final bool showAttachment;
  final bool showVoice;
  final FocusNode? focusNode;

  const AiChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onSubmitted,
    this.onAttachImage,
    this.onToggleVoiceRecord,
    this.onLongPressVoiceRecord,
    this.isRecordingVoice = false,
    this.isLoading = false,
    this.isStreaming = false,
    this.onStop,
    this.hintText = 'Ask any question, formula or theorem...',
    required this.isDark,
    this.showAttachment = true,
    this.showVoice = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.getBorder(isDark),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image / Math Attachment Button
          if (showAttachment && onAttachImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton(
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
                tooltip: 'Attach Image / Handwritten Math',
                onPressed: isLoading ? null : onAttachImage,
              ),
            ),

          // Main Text Input Field
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: onSubmitted ?? (_) => onSend(),
              ),
            ),
          ),

          // Send / Loading Action Button
          Padding(
            padding: const EdgeInsets.only(bottom: 3, right: 4),
            child: Container(
              decoration: BoxDecoration(
                gradient: isStreaming
                    ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (isStreaming ? const Color(0xFFEF4444) : AppColors.primary).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: isStreaming
                    ? const Icon(Icons.stop_rounded, color: Colors.white, size: 20)
                    : isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                tooltip: isStreaming ? 'Stop generating' : 'Send Doubt to AI',
                onPressed: isStreaming ? onStop : (isLoading ? null : onSend),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
