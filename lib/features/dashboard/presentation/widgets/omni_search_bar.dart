import 'package:flutter/material.dart';

/// Ultra-Premium Omni Prompt Bar (Perplexity / ChatGPT Focus Hub style)
/// Features glassmorphic container, subtle ambient border glow, voice action,
/// and interactive quick-start suggestion pills.
class OmniSearchBar extends StatefulWidget {
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
    this.suggestions = const [],
    this.isDark = false,
  });

  @override
  State<OmniSearchBar> createState() => _OmniSearchBarState();
}

class _OmniSearchBarState extends State<OmniSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    const primary = Color(0xFF2563EB);

    final bgColor = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = _isFocused
        ? primary
        : (isDark ? const Color(0xFF24324D) : const Color(0xFFE2E8F0));
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Perplexity-style focus prompt card
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 1.6 : 1.1,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask any doubt, derive formulas, or search...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.mic_none_rounded, size: 20, color: textSecondary),
                onPressed: widget.onVoiceTap,
                tooltip: 'Voice Doubt Prompt',
              ),
              InkWell(
                onTap: () {
                  final text = widget.controller?.text.trim() ?? '';
                  if (text.isNotEmpty && widget.onSubmitted != null) {
                    widget.onSubmitted!(text);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(right: 9),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

        // Quick Suggestion Chips
        if (widget.suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: widget.suggestions.map((sug) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (widget.onSuggestionTap != null) {
                        widget.onSuggestionTap!(sug);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF24324D) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        sug,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          letterSpacing: -0.1,
                        ),
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
