import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';

class QuizTakerScreen extends StatelessWidget {
  const QuizTakerScreen({super.key});

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
        appBar: AppBar(title: const Text('Practice Quiz')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('No active quiz in session.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Quizzes'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: controller.timeRemainingSeconds < 60
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: controller.timeRemainingSeconds < 60 ? AppColors.error : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: controller.timeRemainingSeconds < 60 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: currentIndex > 0 ? () => controller.prevQuestion() : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
              if (currentIndex < totalQuestions - 1)
                ElevatedButton.icon(
                  onPressed: () => controller.nextQuestion(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: controller.isSubmitting
                      ? null
                      : () async {
                          await controller.submitActiveQuiz();
                        },
                  icon: controller.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(controller.isSubmitting ? 'Grading...' : 'Submit Exam'),
                ),
            ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Progress Bar ---
                  LinearProgressIndicator(
                    value: totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0,
                    backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${currentIndex + 1} of $totalQuestions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          question.difficulty.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- Question Body Card ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                    ),
                    child: FormattedAiText(
                      text: question.questionText,
                      isDark: isDark,
                      baseFontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Trap Alert Warning (if present) ---
                  if (question.trapWarning.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Examiner Trap & Misconception:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                                ),
                                const SizedBox(height: 2),
                                _buildMathOrText(
                                  question.trapWarning,
                                  isDark,
                                  false,
                                  style: const TextStyle(fontSize: 12, color: AppColors.warning),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- Multiple Choice Options ---
                  const Text(
                    'Select the correct answer:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < question.options.length; i++) ...[
                    _buildOptionTile(
                      index: i,
                      text: question.options[i],
                      isSelected: selectedOption == i,
                      onTap: () => controller.selectOption(question.id, i),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.getBorder(isDark),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected
                    ? null
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMathOrText(text, isDark, isSelected),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 21),
          ],
        ),
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
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildResultScreen(BuildContext context, QuizController controller, bool isDark) {
    final result = controller.lastResult!;
    final passed = result.percentage >= 60.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Assessment Results', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.pop(),
            child: const Text('Back to Course & Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  // --- Score Badge Card ---
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
                          color: (passed ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Icon(passed ? Icons.emoji_events : Icons.refresh, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${result.score} / ${result.totalScore}',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Score: ${result.percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            passed ? '🎉 Concept Mastery Achieved' : '💡 Revision Needed on Identified Weak Areas',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Weak Areas Section (if any) ---
                  if (result.weakAreasIdentified.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.biotech, size: 20, color: AppColors.error),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bloom Taxonomy Diagnostics (Weak Areas):',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: result.weakAreasIdentified.map((area) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  area,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // --- Question by Question Review ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Detailed Answers & LaTeX Derivations:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < result.feedback.length; i++) ...[
                    _buildFeedbackCard(i + 1, result.feedback[i], context, isDark),
                    const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fb.isCorrect
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fb.isCorrect ? Icons.check_circle : Icons.cancel,
                color: fb.isCorrect ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Question $qNum ${fb.isCorrect ? "(Correct)" : "(Incorrect)"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fb.isCorrect ? AppColors.success : AppColors.error,
                    fontSize: 14,
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
          if (fb.explanation.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pedagogical Explanation & Derivation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
          if (fb.trapWarning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Trap Warning: ${fb.trapWarning}',
              style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ],
          if (!fb.isCorrect) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.psychology, size: 16),
              label: const Text('Ask AI Tutor to Explain this Error'),
              onPressed: () {
                context.push(AppRoutes.aiChat, extra: {
                  'initialQuery': 'I got this question wrong in my quiz. Please teach me why:\n\nQuestion: ${fb.questionText}\nExplanation: ${fb.explanation}',
                  'noteTitle': 'Quiz Review Question $qNum',
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}
