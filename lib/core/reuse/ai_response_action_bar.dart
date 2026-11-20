import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_snackbar.dart';

/// Reusable Bottom Action Bar for AI Assistant responses
/// Provides one-tap Copy, Feynman Simplification, Practice Generation, Summary, and Retry
class AiResponseActionBar extends StatelessWidget {
  final String solutionContent;
  final String? spokenTranscript;
  final VoidCallback onSimplify;
  final VoidCallback onPractice;
  final VoidCallback? onSummarize;
  final VoidCallback? onRegenerate;
  final bool isDark;

  const AiResponseActionBar({
    super.key,
    required this.solutionContent,
    this.spokenTranscript,
    required this.onSimplify,
    required this.onPractice,
    this.onSummarize,
    this.onRegenerate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy Solution Button
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: solutionContent));
                CustomSnackbar.showSuccess(context, 'Solution copied to clipboard! 📋');
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 12,
              width: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // Simplify (Feynman) Button
            InkWell(
              onTap: onSimplify,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      'Simplify',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[200] : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 12,
              width: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // Practice Problem Button
            InkWell(
              onTap: onPractice,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.quiz_outlined, size: 13, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(
                      'Practice',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onSummarize != null) ...[
              Container(
                height: 12,
                width: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              InkWell(
                onTap: onSummarize,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.summarize_outlined, size: 13, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 4),
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (onRegenerate != null) ...[
              Container(
                height: 12,
                width: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              InkWell(
                onTap: onRegenerate,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 13, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
