import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../core/widgets/custom_snackbar.dart';

/// Single step model in a mathematical, physical, or logical derivation sequence.
class DerivationStepItem {
  final int stepNumber;
  final String title;
  final String? equation;
  final String explanation;
  final String? intuition;
  final String? ruleOrTheorem;

  const DerivationStepItem({
    required this.stepNumber,
    required this.title,
    this.equation,
    required this.explanation,
    this.intuition,
    this.ruleOrTheorem,
  });
}

/// Studio-grade interactive Collapsible Math Derivation Card with step-by-step accordions,
/// math equation formatting, intuition insights, and "Expand / Collapse All" toggle.
class CollapsibleDerivationCard extends StatefulWidget {
  final String? derivationTitle;
  final List<DerivationStepItem> steps;
  final bool isDark;
  final double baseFontSize;
  final bool initialExpanded;

  const CollapsibleDerivationCard({
    super.key,
    this.derivationTitle,
    required this.steps,
    required this.isDark,
    this.baseFontSize = 13.5,
    this.initialExpanded = false,
  });

  @override
  State<CollapsibleDerivationCard> createState() => _CollapsibleDerivationCardState();
}

class _CollapsibleDerivationCardState extends State<CollapsibleDerivationCard> {
  late final Set<int> _expandedSteps;
  bool _isAllExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandedSteps = {};
    if (widget.initialExpanded || widget.steps.length <= 2) {
      for (int i = 0; i < widget.steps.length; i++) {
        _expandedSteps.add(i);
      }
      _isAllExpanded = true;
    } else {
      _expandedSteps.add(0);
    }
  }

  void _toggleAll() {
    setState(() {
      if (_isAllExpanded) {
        _expandedSteps.clear();
        _isAllExpanded = false;
      } else {
        for (int i = 0; i < widget.steps.length; i++) {
          _expandedSteps.add(i);
        }
        _isAllExpanded = true;
      }
    });
  }

  void _toggleStep(int index) {
    setState(() {
      if (_expandedSteps.contains(index)) {
        _expandedSteps.remove(index);
      } else {
        _expandedSteps.add(index);
      }
      _isAllExpanded = _expandedSteps.length == widget.steps.length;
    });
  }

  String _formatMathSymbols(String input) {
    return input
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll(r'\left[', '[')
        .replaceAll(r'\right]', ']')
        .replaceAll(r'\left\{', '{')
        .replaceAll(r'\right\}', '}')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}')
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\frac', '')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\partial', '∂')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\epsilon', 'ε')
        .replaceAll(r'\varepsilon', 'ε')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\gamma', 'γ')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\Theta', 'Θ')
        .replaceAll(r'\lambda', 'λ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\omega', 'ω')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\nabla', '∇')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'$$', '')
        .replaceAll(r'$', '');
  }

  void _copyFullDerivation() {
    final buffer = StringBuffer();
    if (widget.derivationTitle != null && widget.derivationTitle!.isNotEmpty) {
      buffer.writeln('📐 ${widget.derivationTitle}\n');
    }
    for (final step in widget.steps) {
      buffer.writeln('Step ${step.stepNumber}: ${step.title}');
      if (step.equation != null && step.equation!.isNotEmpty) {
        buffer.writeln('Formula: ${step.equation}');
      }
      buffer.writeln('Explanation: ${step.explanation}');
      if (step.intuition != null && step.intuition!.isNotEmpty) {
        buffer.writeln('Intuition: ${step.intuition}');
      }
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    CustomSnackbar.showSuccess(context, 'Complete derivation copied!');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isDark;
    final totalSteps = widget.steps.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Title & Action Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1B4B).withValues(alpha: 0.4)
                  : const Color(0xFFEEF2FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.architecture_rounded, size: 16, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.derivationTitle ?? 'Mathematical & Logical Derivation',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$totalSteps Sequential Steps • Interactive Accordion',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Expand / Collapse All Toggle Button
                TextButton.icon(
                  onPressed: _toggleAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _isAllExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                    size: 14,
                    color: const Color(0xFF6366F1),
                  ),
                  label: Text(
                    _isAllExpanded ? 'Collapse' : 'Expand All',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF6366F1)),
                  tooltip: 'Copy Full Derivation',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _copyFullDerivation,
                ),
              ],
            ),
          ),

          // Derivation Steps
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: totalSteps,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final step = widget.steps[index];
              final isExpanded = _expandedSteps.contains(index);

              return _buildStepAccordionItem(step, index, isExpanded, totalSteps, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepAccordionItem(
    DerivationStepItem step,
    int index,
    bool isExpanded,
    int totalSteps,
    bool isDark,
  ) {
    final cleanEquation = step.equation != null ? _formatMathSymbols(step.equation!) : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF6366F1).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header Tile
          InkWell(
            onTap: () => _toggleStep(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Step Number Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Step ${step.stepNumber}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isExpanded ? Colors.white : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Step Title / Summary
                  Expanded(
                    child: Text(
                      _formatMathSymbols(step.title),
                      style: TextStyle(
                        fontSize: widget.baseFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      ),
                      maxLines: isExpanded ? null : 1,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),

                  // Rule / Theorem Chip if present
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
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ],

                  // Chevron indicator
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

          // Expanded Content Body
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mathematical Transformation Box (if equation exists)
                  if (cleanEquation != null && cleanEquation.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              physics: const BouncingScrollPhysics(),
                              child: SelectionArea(
                                child: Math.tex(
                                  step.equation!,
                                  textStyle: TextStyle(
                                    fontSize: widget.baseFontSize + 1.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  ),
                                  mathStyle: MathStyle.display,
                                  onErrorFallback: (err) => SelectableText(
                                    cleanEquation,
                                    style: GoogleFonts.firaCode(
                                      fontSize: widget.baseFontSize + 0.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF38BDF8)),
                            tooltip: 'Copy Step Equation',
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

                  // Step Explanation
                  if (step.explanation.isNotEmpty) ...[
                    SelectableText(
                      step.explanation,
                      style: TextStyle(
                        fontSize: widget.baseFontSize - 0.5,
                        height: 1.45,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],

                  // Intuition / "Why this works" Box
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
                            child: SelectableText(
                              '💡 Intuition: ${step.intuition}',
                              style: TextStyle(
                                fontSize: widget.baseFontSize - 1.5,
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

                  // Theorem / Rule Badge in footer if present
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
