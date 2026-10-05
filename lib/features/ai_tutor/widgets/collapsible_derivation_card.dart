import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_snackbar.dart';

/// Single step model inside a mathematical or physics derivation
class DerivationStep {
  final int stepNumber;
  final String title;
  final String? equation;
  final String explanation;
  final String? intuition;
  final String? ruleOrTheorem;

  const DerivationStep({
    required this.stepNumber,
    required this.title,
    this.equation,
    required this.explanation,
    this.intuition,
    this.ruleOrTheorem,
  });

  factory DerivationStep.fromJson(Map<String, dynamic> json) {
    return DerivationStep(
      stepNumber: json['stepNumber'] as int? ?? (json['step'] as int? ?? 1),
      title: json['title'] as String? ?? 'Step',
      equation: json['equation'] as String?,
      explanation: json['explanation'] as String? ?? '',
      intuition: json['intuition'] as String?,
      ruleOrTheorem: json['ruleOrTheorem'] as String? ?? json['rule'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepNumber': stepNumber,
    'title': title,
    'equation': equation,
    'explanation': explanation,
    'intuition': intuition,
    'ruleOrTheorem': ruleOrTheorem,
  };
}

/// A collapsible, step-by-step derivation card.
/// Renders mathematical derivations step-by-step with KaTeX formulas,
/// intuition tips, and applied theorem tags.
class CollapsibleDerivationCard extends StatefulWidget {
  final String derivationTitle;
  final List<DerivationStep> steps;
  final String? finalResult;
  final bool initiallyExpanded;
  final double baseFontSize;

  const CollapsibleDerivationCard({
    super.key,
    required this.derivationTitle,
    required this.steps,
    this.finalResult,
    this.initiallyExpanded = false,
    this.baseFontSize = 14.0,
  });

  @override
  State<CollapsibleDerivationCard> createState() => _CollapsibleDerivationCardState();
}

class _CollapsibleDerivationCardState extends State<CollapsibleDerivationCard> {
  late bool _isCardExpanded;
  final Set<int> _expandedSteps = {};

  @override
  void initState() {
    super.initState();
    _isCardExpanded = widget.initiallyExpanded;
    // By default, keep step 1 open if the main card is expanded
    if (_isCardExpanded && widget.steps.isNotEmpty) {
      _expandedSteps.add(1);
    }
  }

  void _toggleStep(int stepNum) {
    setState(() {
      if (_expandedSteps.contains(stepNum)) {
        _expandedSteps.remove(stepNum);
      } else {
        _expandedSteps.add(stepNum);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            onTap: () {
              setState(() {
                _isCardExpanded = !_isCardExpanded;
                if (_isCardExpanded && _expandedSteps.isEmpty && widget.steps.isNotEmpty) {
                  _expandedSteps.add(1);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: _isCardExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'MATHEMATICAL DERIVATION',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.steps.length} Steps',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.derivationTitle,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isCardExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Steps Body
          if (_isCardExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final step in widget.steps)
                    _DerivationStepItem(
                      step: step,
                      isExpanded: _expandedSteps.contains(step.stepNumber),
                      onToggle: () => _toggleStep(step.stepNumber),
                      baseFontSize: widget.baseFontSize,
                      isDark: isDark,
                    ),

                  // Final Result Banner if provided
                  if (widget.finalResult != null && widget.finalResult!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FINAL RESULT / THEOREM FORMULA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Math.tex(
                                    widget.finalResult!,
                                    textStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                    ),
                                    mathStyle: MathStyle.display,
                                    onErrorFallback: (_) => Text(
                                      widget.finalResult!,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF10B981)),
                            tooltip: 'Copy Final Result',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.finalResult!));
                              CustomSnackbar.showSuccess(context, 'Final result copied to clipboard!');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DerivationStepItem extends StatelessWidget {
  final DerivationStep step;
  final bool isExpanded;
  final VoidCallback onToggle;
  final double baseFontSize;
  final bool isDark;

  const _DerivationStepItem({
    required this.step,
    required this.isExpanded,
    required this.onToggle,
    required this.baseFontSize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cleanEquation = step.equation?.replaceAll(r'$$', '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isExpanded ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${step.stepNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isExpanded ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: isExpanded ? null : 1,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (step.ruleOrTheorem != null && step.ruleOrTheorem!.isNotEmpty && !isExpanded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.ruleOrTheorem!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Formula Box
                  if (cleanEquation != null && cleanEquation.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B192C) : const Color(0xFFEEF7FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Math.tex(
                                cleanEquation,
                                textStyle: TextStyle(
                                  fontSize: baseFontSize + 1,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                ),
                                mathStyle: MathStyle.display,
                                onErrorFallback: (_) => Text(
                                  cleanEquation,
                                  style: GoogleFonts.firaCode(
                                    fontSize: baseFontSize,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF38BDF8)),
                            tooltip: 'Copy Equation',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: cleanEquation));
                              CustomSnackbar.showSuccess(context, 'Step equation copied!');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Explanation Text
                  if (step.explanation.isNotEmpty) ...[
                    Text(
                      step.explanation,
                      style: TextStyle(
                        fontSize: baseFontSize - 0.5,
                        height: 1.45,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],

                  // Intuition Callout
                  if (step.intuition != null && step.intuition!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '💡 Intuition: ${step.intuition}',
                              style: TextStyle(
                                fontSize: baseFontSize - 1.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Theorem / Rule Badge
                  if (step.ruleOrTheorem != null && step.ruleOrTheorem!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.bookmark_border_rounded, size: 12, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          'Applied Rule: ${step.ruleOrTheorem}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
