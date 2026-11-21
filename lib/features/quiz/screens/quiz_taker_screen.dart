import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';

/// Distraction-Free Academic Test & Examination Interface
/// Supports both Multiple Choice Questions (MCQ) and In-Depth Written Subjective Questions.
class QuizTakerScreen extends StatefulWidget {
  const QuizTakerScreen({super.key});

  @override
  State<QuizTakerScreen> createState() => _QuizTakerScreenState();
}

class _QuizTakerScreenState extends State<QuizTakerScreen> {
  final Map<String, TextEditingController> _textControllers = {};

  TextEditingController _getControllerFor(String qId, String initialText) {
    if (!_textControllers.containsKey(qId)) {
      _textControllers[qId] = TextEditingController(text: initialText);
    }
    return _textControllers[qId]!;
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _onWillPop(BuildContext context) async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Examination?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to exit? Your current test progress will be lost unless submitted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resume Test'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (controller.lastResult != null) {
      return _buildResultScreen(context, controller, isDark);
    }

    final quiz = controller.activeQuiz;
    final question = controller.currentQuestion;

    if (quiz == null || question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Academic Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 56, color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              const Text('No active test session.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Tests'),
              ),
            ],
          ),
        ),
      );
    }

    final totalQuestions = quiz.questions.length;
    final currentIndex = controller.currentQuestionIndex;
    final selectedOption = controller.selectedAnswers[question.id];
    final minutes = controller.timeRemainingSeconds ~/ 60;
    final seconds = controller.timeRemainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isTimeUrgent = controller.timeRemainingSeconds < 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop(context);
        if (shouldExit && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Exit Test',
            onPressed: () async {
              final shouldExit = await _onWillPop(context);
              if (shouldExit && context.mounted) {
                context.pop();
              }
            },
          ),
          title: Text(
            quiz.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Live Countdown Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: isTimeUrgent
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isTimeUrgent
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : const Color(0xFF2563EB).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: isTimeUrgent ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isTimeUrgent ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomExamBar(context, controller, currentIndex, totalQuestions, isDark),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: SafeScrollable(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Quick Question Navigator Bar ---
                    _buildQuestionPalette(controller, quiz, currentIndex, isDark),
                    const SizedBox(height: 16),

                    // --- Question Meta Row: Type Badge, Difficulty, Marks ---
                    Row(
                      children: [
                        // Question Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: question.isSubjective
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                : const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: question.isSubjective
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                  : const Color(0xFF2563EB).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                question.isSubjective ? Icons.edit_note_rounded : Icons.radio_button_checked_rounded,
                                size: 13,
                                color: question.isSubjective ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                question.isSubjective
                                    ? 'SUBJECTIVE • ${question.maxMarks} MARKS'
                                    : 'MCQ • ${question.maxMarks} MARK',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: question.isSubjective ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Difficulty Badge
                        _buildDifficultyBadge(question.difficulty),

                        const Spacer(),

                        // Progress Indicator Text
                        Text(
                          '${currentIndex + 1} of $totalQuestions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- Clean Question Problem Card ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormattedAiText(
                            text: question.questionText,
                            isDark: isDark,
                            baseFontSize: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Subtle Trap Warning (if present) ---
                    if (question.trapWarning.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 17, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Examiner Trap: ${question.trapWarning}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- Answer Section (MCQ vs Subjective) ---
                    if (question.isSubjective)
                      _buildSubjectiveEditor(context, controller, question, isDark)
                    else
                      _buildMCQOptions(controller, question, selectedOption, isDark),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Quick Question Palette Widget ---
  Widget _buildQuestionPalette(QuizController controller, QuizModel quiz, int currentIdx, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(quiz.questions.length, (i) {
          final q = quiz.questions[i];
          final isCurrent = i == currentIdx;
          bool isAnswered = false;
          if (q.isSubjective) {
            isAnswered = (controller.writtenAnswers[q.id]?.trim().isNotEmpty ?? false);
          } else {
            isAnswered = controller.selectedAnswers.containsKey(q.id) && controller.selectedAnswers[q.id]! >= 0;
          }

          Color bg;
          Color border;
          Color textColor;

          if (isCurrent) {
            bg = const Color(0xFF2563EB);
            border = const Color(0xFF2563EB);
            textColor = Colors.white;
          } else if (isAnswered) {
            bg = const Color(0xFF10B981).withValues(alpha: 0.15);
            border = const Color(0xFF10B981);
            textColor = const Color(0xFF059669);
          } else {
            bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
            border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
            textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          }

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.jumpToQuestion(i);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: isCurrent ? 1.5 : 1.0),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Subjective Writing Canvas ---
  Widget _buildSubjectiveEditor(
    BuildContext context,
    QuizController controller,
    QuizQuestionModel question,
    bool isDark,
  ) {
    final writtenText = controller.writtenAnswers[question.id] ?? '';
    final textController = _getControllerFor(question.id, writtenText);

    final words = writtenText.trim().isEmpty ? 0 : writtenText.trim().split(RegExp(r'\s+')).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  Text(
                    'Your Written Answer & Derivation',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$words words',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Write your step-by-step logic, definitions, equations, or code. AI will grade rigorously based on the academic rubric.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            maxLines: 10,
            minLines: 5,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter your comprehensive answer here...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              ),
            ),
            onChanged: (val) {
              controller.setWrittenAnswer(question.id, val);
            },
          ),
        ],
      ),
    );
  }

  // --- MCQ Options Builder ---
  Widget _buildMCQOptions(
    QuizController controller,
    QuizQuestionModel question,
    int? selectedOption,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select the correct option:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < question.options.length; i++) ...[
          _buildOptionTile(
            index: i,
            text: question.options[i],
            isSelected: selectedOption == i,
            onTap: () => controller.selectOption(question.id, i),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = index < letters.length ? letters[index] : '${index + 1}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMathOrText(text, isDark, isSelected),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
          ],
        ),
      ),
    );
  }

  // --- Bottom Examination Navigation Bar ---
  Widget _buildBottomExamBar(
    BuildContext context,
    QuizController controller,
    int currentIndex,
    int totalQuestions,
    bool isDark,
  ) {
    final isLast = currentIndex == totalQuestions - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: currentIndex > 0 ? () => controller.prevQuestion() : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Previous'),
            ),
            if (!isLast)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => controller.nextQuestion(),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Next Question'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: controller.isSubmitting
                    ? null
                    : () async {
                        await controller.submitActiveQuiz();
                      },
                icon: controller.isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(controller.isSubmitting ? 'Evaluating...' : 'Submit Exam'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    String label;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = const Color(0xFF10B981);
        label = 'EASY';
        break;
      case 'hard':
        color = const Color(0xFFEF4444);
        label = 'HARD';
        break;
      default:
        color = const Color(0xFFF59E0B);
        label = 'MEDIUM';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  static Widget _buildMathOrText(
    String text,
    bool isDark,
    bool isSelected, {
    TextStyle? style,
  }) {
    final baseStyle = style ??
        TextStyle(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        );

    if (text.contains(r'$')) {
      final parts = text.split(r'$');
      final spans = <InlineSpan>[];
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        if (i % 2 == 1) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                parts[i],
                textStyle: baseStyle,
                onErrorFallback: (_) => Text(LatexSanitizer.clean(parts[i]), style: baseStyle),
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: LatexSanitizer.clean(parts[i]), style: baseStyle));
        }
      }
      return Text.rich(TextSpan(children: spans));
    }

    return Text(LatexSanitizer.clean(text), style: baseStyle);
  }

  // --- Detailed Results Assessment Screen ---
  Widget _buildResultScreen(BuildContext context, QuizController controller, bool isDark) {
    final result = controller.lastResult!;
    final passed = result.percentage >= 60.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Exam Assessment Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.pop(),
            child: const Text('Done & Return to Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SafeScrollable(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- Score Summary Hero Card ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: passed
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Icon(passed ? Icons.emoji_events_rounded : Icons.replay_rounded, size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${result.score} / ${result.totalScore} Marks',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          '${result.percentage.toStringAsFixed(1)}% Score',
                          style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            passed ? '🎉 Concept Mastery Achieved' : '💡 Revision Recommended on Weak Topics',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Diagnostic Weak Areas Section ---
                  if (result.weakAreasIdentified.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.biotech_rounded, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Identified Knowledge Gaps (Bloom Taxonomy):',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: result.weakAreasIdentified.map((area) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  area,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- Detailed Feedback Breakdown ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Question Evaluations & Model Solutions:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < result.feedback.length; i++) ...[
                    _buildFeedbackCard(i + 1, result.feedback[i], context, isDark),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(int qNum, QuestionFeedbackModel fb, BuildContext context, bool isDark) {
    final isSubj = fb.isSubjective;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fb.isCorrect
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fb.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: fb.isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q$qNum • ${isSubj ? "Subjective" : "MCQ"} (${fb.score}/${fb.maxMarks} Marks)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: fb.isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMathOrText(
            fb.questionText,
            isDark,
            false,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          // For Subjective: Show candidate's written response & AI evaluation
          if (isSubj) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Student\'s Written Response:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(
                    fb.studentAnswer.isNotEmpty ? fb.studentAnswer : '(No answer submitted)',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: fb.studentAnswer.isEmpty ? FontStyle.italic : FontStyle.normal,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // AI Feedback / Critique
            if (fb.feedback.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text('AI Examiner Assessment:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fb.feedback,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Key Points Covered
            if (fb.keyPointsCovered.isNotEmpty) ...[
              const Text('Points Addressed:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: fb.keyPointsCovered.map((pt) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('✓ $pt', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Key Points Missed
            if (fb.keyPointsMissed.isNotEmpty) ...[
              const Text('Points Missed:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: fb.keyPointsMissed.map((pt) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('✗ $pt', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Model Answer Card
            if (fb.modelAnswer.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Official Model Answer (Full Marks):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8B5CF6))),
                    const SizedBox(height: 6),
                    FormattedAiText(
                      text: fb.modelAnswer,
                      isDark: isDark,
                      baseFontSize: 12.5,
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // For MCQ: Show Explanation
            if (fb.explanation.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pedagogical Explanation & Derivation:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    FormattedAiText(
                      text: fb.explanation,
                      isDark: isDark,
                      baseFontSize: 13,
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (fb.trapWarning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Trap Warning: ${fb.trapWarning}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
            ),
          ],

          if (!fb.isCorrect) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.psychology_rounded, size: 16),
              label: const Text('Ask AI Tutor to Explain this Solution'),
              onPressed: () {
                context.push(AppRoutes.aiChat, extra: {
                  'initialQuery': 'I need help understanding this exam question:\n\nQuestion: ${fb.questionText}\nModel Solution / Explanation: ${isSubj ? fb.modelAnswer : fb.explanation}',
                  'noteTitle': 'Exam Review Q$qNum',
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}
