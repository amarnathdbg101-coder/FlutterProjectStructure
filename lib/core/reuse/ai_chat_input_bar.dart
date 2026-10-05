import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'voice_record_button.dart';

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
    this.hintText = 'Ask any question, formula or theorem...',
    required this.isDark,
    this.showAttachment = true,
    this.showVoice = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
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
                  size: 22,
                ),
                tooltip: 'Attach Image / Handwritten Math',
                onPressed: isLoading ? null : onAttachImage,
              ),
            ),

          // Animated Voice Record Button (Tap: Voice Typing, Long Press: Voice Doubt Assistant)
          if (showVoice && onToggleVoiceRecord != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: VoiceRecordButton(
                isRecording: isRecordingVoice,
                onPressed: isLoading ? () {} : onToggleVoiceRecord!,
                onLongPress: isLoading ? null : onLongPressVoiceRecord,
                tooltip: isRecordingVoice
                    ? 'Stop listening (Tap to finish)'
                    : 'Tap to Speak / Voice Typing (Long-press for Assistant)',
              ),
            ),

          // Main Text Input Field
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
              tooltip: 'Send Doubt to AI',
              onPressed: isLoading ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
