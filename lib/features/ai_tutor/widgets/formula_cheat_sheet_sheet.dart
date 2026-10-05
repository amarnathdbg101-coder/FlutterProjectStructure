import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../repositories/ai_tutor_repository.dart';
import 'formatted_ai_text.dart';

/// Pure-AI Formula & Equation Cheat-Sheet Studio
/// Generates and presents exhaustive LaTeX formulas, SI units,
/// assumptions, conditions, and exam shortcuts for any topic or subject.
class FormulaCheatSheetSheet extends StatefulWidget {
  final String? initialTopic;
  final String? initialContent;
  final void Function(String formulaText)? onSaveFormula;

  const FormulaCheatSheetSheet({
    super.key,
    this.initialTopic,
    this.initialContent,
    this.onSaveFormula,
  });

  static Future<void> show(
    BuildContext context, {
    String? topic,
    String? content,
    void Function(String formulaText)? onSaveFormula,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FormulaCheatSheetSheet(
        initialTopic: topic,
        initialContent: content,
        onSaveFormula: onSaveFormula,
      ),
    );
  }

  @override
  State<FormulaCheatSheetSheet> createState() => _FormulaCheatSheetSheetState();
}

class _FormulaCheatSheetSheetState extends State<FormulaCheatSheetSheet> {
  final AiTutorRepository _aiRepo = AiTutorRepository();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _cheatSheetContent;
  List<String> _extractedLocalFormulas = [];
  bool _isLoading = false;
  String? _errorMessage;
  final String _searchQuery = '';

  final List<String> _popularTopics = [
    'Calculus (Derivatives & Integrals)',
    'Rotational Dynamics & Mechanics',
    'Thermodynamics & Heat Transfer',
    'Electromagnetism & Maxwell Equations',
    'Optics & Wave Physics',
    'Trigonometry Identities',
    'Chemical Kinetics & Equilibrium',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      _topicController.text = widget.initialTopic!;
    }
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _extractLocalFormulas(widget.initialContent!);
    } else if (_topicController.text.isNotEmpty) {
      _generateAiFormulas();
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentTopic {
    final t = _topicController.text.trim();
    return t.isNotEmpty ? t : 'Academic Science & Mathematics';
  }

  void _extractLocalFormulas(String content) {
    final List<String> list = [];
    final blockRegex = RegExp(r'\$\$([\s\S]*?)\$\$');
    for (final match in blockRegex.allMatches(content)) {
      final f = match.group(1)?.trim();
      if (f != null && f.isNotEmpty && !list.contains(f)) {
        list.add(f);
      }
    }

    final inlineRegex = RegExp(r'\$([^\$\n]+?)\$');
    for (final match in inlineRegex.allMatches(content)) {
      final f = match.group(1)?.trim();
      if (f != null && f.length > 2 && (f.contains('=') || f.contains('\\')) && !list.contains(f)) {
        list.add(f);
      }
    }

    setState(() {
      _extractedLocalFormulas = list;
    });
  }

  Future<void> _generateAiFormulas() async {
    final topic = _currentTopic;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prompt = 'Generate an exhaustive, high-yield Formula & Equation Cheat-Sheet for "$topic". '
          'Include all core mathematical/physics formulas in LaTeX (\$\$...\$\$), SI units of variables, '
          'limitations/assumptions, and high-frequency exam shortcuts.';

      final doubt = await _aiRepo.askDoubt(
        question: prompt,
        mode: 'derivation',
      );

      if (mounted) {
        setState(() {
          _cheatSheetContent = doubt.content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.functions_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Formula & Equation Studio',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _currentTopic,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_cheatSheetContent != null && _cheatSheetContent!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF6366F1)),
                    tooltip: 'Copy Full Cheat-Sheet',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _cheatSheetContent!));
                      CustomSnackbar.showSuccess(context, 'Full formula sheet copied to clipboard!');
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Topic Input Bar & AI Generate Trigger
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _topicController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Enter topic or chapter (e.g. Calculus, Kinematics)...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(Icons.functions_rounded, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _generateAiFormulas(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('Synthesize', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  onPressed: _isLoading ? null : _generateAiFormulas,
                ),
              ],
            ),
          ),

          // Quick Topic Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _popularTopics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final t = _popularTopics[index];
                return ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 11.5)),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  onPressed: () {
                    _topicController.text = t;
                    _generateAiFormulas();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text(
                          'Synthesizing formula sheet with KaTeX...',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _generateAiFormulas,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildContentList(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(BuildContext context, bool isDark) {
    if (_cheatSheetContent != null && _cheatSheetContent!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: FormattedAiText(
          text: _cheatSheetContent!,
          isDark: isDark,
          baseFontSize: 13.5,
        ),
      );
    }

    // Otherwise show extracted local formulas or prompt state
    final filtered = _extractedLocalFormulas.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate_outlined, size: 40, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Formula & Derivation Studio',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Type any subject, chapter, or theorem above and tap "Synthesize" to generate exhaustive LaTeX equations, variable legends, and shortcuts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate for Calculus & Physics'),
                onPressed: () {
                  _topicController.text = 'Calculus & Physics Core Formulas';
                  _generateAiFormulas();
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final formula = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    formula,
                    textStyle: TextStyle(
                      fontSize: 16,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      fontWeight: FontWeight.w600,
                    ),
                    mathStyle: MathStyle.display,
                    onErrorFallback: (_) => Text(
                      formula,
                      style: GoogleFonts.firaCode(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                tooltip: 'Copy LaTeX',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '\$\$$formula\$\$'));
                  CustomSnackbar.showSuccess(context, 'Formula copied to clipboard!');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
