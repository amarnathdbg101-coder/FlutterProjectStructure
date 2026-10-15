import 'package:flutter/material.dart';

/// Clean, spacious Omni Prompt Bar (Perplexity / ChatGPT Focus Hub style)
class OmniSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onVoiceTap;
  final ValueChanged<String>? onSuggestionTap;
  final List<String> suggestions;
  final bool isDark;

  const OmniSearchBar({
    super.key,
    this.controller,
    required this.onChanged,
    this.onSubmitted,
    required this.onVoiceTap,
    this.onSuggestionTap,
    this.suggestions = const [
      'Ask AI Tutor',
      '5-min Quiz',
      'Formula Studio',
      'Concept Map',
    ],
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final chipBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final chipBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primary = Color(0xFF2563EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Perplexity-style prompt box
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask anything, solve equations, or search...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.mic_none_rounded, size: 20, color: textSecondary),
                onPressed: onVoiceTap,
                tooltip: 'Voice Prompt',
              ),
              InkWell(
                onTap: () {
                  final text = controller?.text.trim() ?? '';
                  if (text.isNotEmpty && onSubmitted != null) {
                    onSubmitted!(text);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (onSuggestionTap != null) {
                        onSuggestionTap!(s);
                      } else if (onSubmitted != null) {
                        onSubmitted!(s);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.contains('Quiz')
                                ? Icons.quiz_outlined
                                : s.contains('Map')
                                    ? Icons.account_tree_outlined
                                    : s.contains('Formula')
                                        ? Icons.functions_outlined
                                        : Icons.bolt_outlined,
                            size: 13,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
