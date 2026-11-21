import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';

/// Distraction-Free Academic Test & Examination Interface
/// Supports:
/// - Fast Question Navigation (Previous & Next buttons, Question Palette)
/// - Flexible Early Submission at any time with a Comprehensive Pre-Submission Summary
/// - Professional Full-Exam Scorecard & In-Depth Solution Review with Filters (All, Correct, Incorrect, Unanswered)
class QuizTakerScreen extends StatefulWidget {
  const QuizTakerScreen({super.key});

  @override
  State<QuizTakerScreen> createState() => _QuizTakerScreenState();
}

class _QuizTakerScreenState extends State<QuizTakerScreen> {
  final Map<String, TextEditingController> _textControllers = {};
  String _resultFilter = 'all'; // 'all' | 'correct' | 'incorrect' | 'unanswered'

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

  /// Professional Pre-Submission Confirmation Dialog
  /// Allows students to submit early from any question with full visibility of progress
  Future<void> _showSubmitConfirmDialog(
    BuildContext context,
    QuizController controller,
    QuizModel quiz,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalQuestions = quiz.questions.length;
    int answeredCount = 0;

    for (final q in quiz.questions) {
      if (q.isSubjective) {
        if (controller.writtenAnswers[q.id]?.trim().isNotEmpty ?? false) {
          answeredCount++;
        }
      } else {
        if (controller.selectedAnswers.containsKey(q.id) &&
            controller.selectedAnswers[q.id]! >= 0) {
          answeredCount++;
        }
      }
    }

    final unansweredCount = totalQuestions - answeredCount;
    final minutes = controller.timeRemainingSeconds ~/ 60;
    final seconds = controller.timeRemainingSeconds % 60;
    final timeStr = '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Submit Examination?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You can submit your examination now. Here is your current status:',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // 3-Metric Summary Cards
                  Row(
                    children: [
                      // Time Left
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(height: 4),
                              Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              const Text('Time Left', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Attempted
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(height: 4),
                              Text('$answeredCount / $totalQuestions',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
                              const Text('Attempted', style: TextStyle(fontSize: 10, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Unattempted
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: (unansweredCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (unansweredCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                unansweredCount > 0 ? Icons.error_outline_rounded : Icons.task_alt_rounded,
                                size: 18,
                                color: unansweredCount > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981),
                              ),
                              const SizedBox(height: 4),
                              Text('$unansweredCount',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: unansweredCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669))),
                              const Text('Unanswered', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (unansweredCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have $unansweredCount unattempted question(s). You can tap any number below to solve it before submitting.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'Question Palette (Tap to jump):',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(totalQuestions, (i) {
                      final q = quiz.questions[i];
                      bool isAnswered = false;
                      if (q.isSubjective) {
                        isAnswered = (controller.writtenAnswers[q.id]?.trim().isNotEmpty ?? false);
                      } else {
                        isAnswered = controller.selectedAnswers.containsKey(q.id) &&
                            controller.selectedAnswers[q.id]! >= 0;
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          controller.jumpToQuestion(i);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isAnswered
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAnswered
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isAnswered
                                  ? const Color(0xFF059669)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Review Questions'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await controller.submitActiveQuiz();
              },
              child: const Text('Submit & Finish Exam', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              margin: const EdgeInsets.only(right: 8),
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
                      fontSize: 12.5,
                      color: isTimeUrgent ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),

            // Early Submit Test Button (Always accessible at any time!)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
                onPressed: controller.isSubmitting
                    ? null
                    : () => _showSubmitConfirmDialog(context, controller, quiz),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomExamBar(context, controller, quiz, currentIndex, totalQuestions, isDark),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Quick Question Navigator Palette Bar ---
                    _buildQuestionPalette(controller, quiz, currentIndex, isDark),
                    const SizedBox(height: 16),

                    // --- Question Meta Row: Type Badge, Difficulty, Marks ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                          ],
                        ),

                        // Progress Indicator Text
                        Text(
                          'Question ${currentIndex + 1} of $totalQuestions',
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
                      child: _buildMathOrText(
                        question.questionText,
                        isDark,
                        false,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
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
    QuizModel quiz,
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
          children: [
            // Previous Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: currentIndex > 0 ? () => controller.prevQuestion() : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Previous'),
            ),
            const Spacer(),

            // If not on last question: Submit Exam button (secondary) + Next Question button (primary)
            if (!isLast) ...[
              TextButton(
                onPressed: controller.isSubmitting
                    ? null
                    : () => _showSubmitConfirmDialog(context, controller, quiz),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('Submit Exam', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => controller.nextQuestion(),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Next Question', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ] else ...[
              // On last question: Primary Submit Exam Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: controller.isSubmitting
                    ? null
                    : () => _showSubmitConfirmDialog(context, controller, quiz),
                icon: controller.isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 17),
                label: Text(
                  controller.isSubmitting ? 'Evaluating...' : 'Submit Exam',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
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

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      if (text.contains(r'$')) {
        // Normalize double-dollars $$...$$ to single $...$ for uniform inline math parsing
        final normalized = text.replaceAll(r'$$', r'$');
        final parts = normalized.split(r'$');
        final spans = <InlineSpan>[];
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          if (i % 2 == 1) {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  parts[i].trim(),
                  textStyle: baseStyle,
                  onErrorFallback: (_) => Text(LatexSanitizer.clean(parts[i]), style: baseStyle),
                ),
              ),
            );
          } else {
            spans.add(TextSpan(text: LatexSanitizer.clean(parts[i]), style: baseStyle));
          }
        }
        if (spans.isNotEmpty) {
          return Text.rich(TextSpan(children: spans));
        }
      }
    } catch (_) {
      // Safe fallback if math engine encounters any parser exception
    }

    return Text(LatexSanitizer.clean(text), style: baseStyle);
  }

  // --- Professional Full-Exam Scorecard & Solution Assessment Screen ---
  Widget _buildResultScreen(BuildContext context, QuizController controller, bool isDark) {
    final result = controller.lastResult!;
    final quiz = controller.activeQuiz;
    final totalQ = result.feedback.length;

    final correctCount = result.feedback.where((f) => f.isCorrect).length;
    final unattemptedCount = result.feedback.where((f) => !f.isAttempted).length;
    final incorrectCount = totalQ - correctCount - unattemptedCount;

    // Filter feedback list
    List<QuestionFeedbackModel> filteredFeedback = result.feedback;
    if (_resultFilter == 'correct') {
      filteredFeedback = result.feedback.where((f) => f.isCorrect).toList();
    } else if (_resultFilter == 'incorrect') {
      filteredFeedback = result.feedback.where((f) => !f.isCorrect && f.isAttempted).toList();
    } else if (_resultFilter == 'unanswered') {
      filteredFeedback = result.feedback.where((f) => !f.isAttempted).toList();
    }

    // Performance Grade Designation
    String gradeTitle;
    String gradeBadge;
    Color gradeColor;
    if (result.percentage >= 90.0) {
      gradeTitle = 'Outstanding Performance';
      gradeBadge = 'Grade A+ • Distinction 🏆';
      gradeColor = const Color(0xFF10B981);
    } else if (result.percentage >= 75.0) {
      gradeTitle = 'First Class Distinction';
      gradeBadge = 'Grade A • High Honors 🌟';
      gradeColor = const Color(0xFF2563EB);
    } else if (result.percentage >= 60.0) {
      gradeTitle = 'Qualified / Passed';
      gradeBadge = 'Grade B • Competent ✅';
      gradeColor = const Color(0xFFF59E0B);
    } else {
      gradeTitle = 'Revision Recommended';
      gradeBadge = 'Grade C • Practice Needed 💡';
      gradeColor = const Color(0xFFEF4444);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Exam Assessment & Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (quiz != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    onPressed: () {
                      controller.startQuiz(quiz);
                    },
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Re-attempt Test', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Return to Tests', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Professional Scorecard Banner ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: result.percentage >= 60.0
                            ? [const Color(0xFF0F766E), const Color(0xFF059669)]
                            : [const Color(0xFFB91C1C), const Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (result.percentage >= 60.0 ? const Color(0xFF059669) : const Color(0xFFDC2626))
                              .withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            gradeBadge,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${result.score} / ${result.totalScore} Marks',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          '${result.percentage.toStringAsFixed(1)}% Overall Score',
                          style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gradeTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 4-Metric Exam Stats Matrix ---
                  Row(
                    children: [
                      // Accuracy
                      _buildMetricCard(
                        title: 'Accuracy',
                        value: '${result.percentage.toStringAsFixed(0)}%',
                        icon: Icons.track_changes_rounded,
                        color: gradeColor,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),

                      // Correct
                      _buildMetricCard(
                        title: 'Correct',
                        value: '$correctCount Qs',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),

                      // Incorrect
                      _buildMetricCard(
                        title: 'Incorrect',
                        value: '$incorrectCount Qs',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),

                      // Unattempted
                      _buildMetricCard(
                        title: 'Skipped',
                        value: '$unattemptedCount Qs',
                        icon: Icons.help_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // --- Diagnostic Knowledge Gaps / Weak Topics ---
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
                                  'AI Identified Knowledge Gaps to Strengthen:',
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
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
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

                  // --- Solution Review Filter Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solutions & Explanations:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Showing ${filteredFeedback.length} of $totalQ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Solution Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('All ($totalQ)', 'all', isDark),
                        const SizedBox(width: 6),
                        _buildFilterChip('Correct ($correctCount)', 'correct', isDark),
                        const SizedBox(width: 6),
                        _buildFilterChip('Incorrect ($incorrectCount)', 'incorrect', isDark),
                        const SizedBox(width: 6),
                        _buildFilterChip('Unanswered ($unattemptedCount)', 'unanswered', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filtered Solution Cards
                  if (filteredFeedback.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.filter_list_off_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            'No questions match this filter.',
                            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    for (int i = 0; i < filteredFeedback.length; i++) ...[
                      _buildFeedbackCard(
                        result.feedback.indexOf(filteredFeedback[i]) + 1,
                        filteredFeedback[i],
                        quiz,
                        context,
                        isDark,
                      ),
                      const SizedBox(height: 14),
                    ],
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, bool isDark) {
    final isSelected = _resultFilter == filterKey;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _resultFilter = filterKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
    int qNum,
    QuestionFeedbackModel fb,
    QuizModel? quiz,
    BuildContext context,
    bool isDark,
  ) {
    final isSubj = fb.isSubjective;
    final isAttempted = fb.isAttempted;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (fb.isCorrect) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Correct (+${fb.score}/${fb.maxMarks} Marks)';
    } else if (isAttempted) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
      statusText = 'Incorrect (${fb.score}/${fb.maxMarks} Marks)';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.help_outline_rounded;
      statusText = 'Not Attempted (0/${fb.maxMarks} Marks)';
    }

    // Retrieve MCQ options
    List<String> options = fb.options;
    if (options.isEmpty && quiz != null) {
      final matchedQ = quiz.questions.where((q) => q.id == fb.questionId).firstOrNull;
      if (matchedQ != null) {
        options = matchedQ.options;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Q#, Type, and Status Badge
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q$qNum • ${isSubj ? "Subjective" : "MCQ"}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question Statement
          _buildMathOrText(
            fb.questionText,
            isDark,
            false,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 12),

          // For MCQ: Render All 4 Options with Student Choice & Correct Answer clearly tagged
          if (!isSubj && options.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  _buildReviewOptionTile(
                    index: i,
                    text: options[i],
                    isCorrect: i == fb.correctOptionIndex,
                    isSelectedByStudent: isAttempted && i == fb.selectedOption,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
            if (!isAttempted) ...[
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text(
                      'You skipped this question during the exam.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],

          // For Subjective: Show Candidate's Written Response & AI Examiner Evaluation
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
                  const Text('Student\'s Written Response:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(
                    fb.studentAnswer.isNotEmpty ? fb.studentAnswer : '(No response was submitted by student)',
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

            // AI Examiner Qualitative Assessment
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
                        Text('AI Examiner Assessment & Score Breakdown:',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
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

            // Points Covered
            if (fb.keyPointsCovered.isNotEmpty) ...[
              const Text('Rubric Points Successfully Addressed:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
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
                    child: Text('✓ $pt',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Points Missed
            if (fb.keyPointsMissed.isNotEmpty) ...[
              const Text('Key Concepts Missed / Incomplete:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
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
                    child: Text('✗ $pt',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Official Model Answer Card
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
                    const Text('Official Model Answer (Full Academic Credit):',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8B5CF6))),
                    const SizedBox(height: 6),
                    _buildMathOrText(
                      fb.modelAnswer,
                      isDark,
                      false,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            // For MCQ: Pedagogical Explanation & Derivation
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
                    const Text('Pedagogical Explanation & Concept Derivation:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    _buildMathOrText(
                      fb.explanation,
                      isDark,
                      false,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.4,
                      ),
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

          // 1-Tap Doubt Button: Connect with AI Tutor for Instant Clarification
          if (!fb.isCorrect) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.psychology_rounded, size: 16),
              label: const Text('Ask AI Tutor to Explain this Solution'),
              onPressed: () {
                context.push(AppRoutes.aiChat, extra: {
                  'initialQuery':
                      'I need help understanding this exam question:\n\nQuestion: ${fb.questionText}\nModel Solution / Explanation: ${isSubj ? fb.modelAnswer : fb.explanation}',
                  'noteTitle': 'Exam Review Q$qNum',
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // --- Review MCQ Option Tile with Clear Correct vs Student Choice Tags ---
  Widget _buildReviewOptionTile({
    required int index,
    required String text,
    required bool isCorrect,
    required bool isSelectedByStudent,
    required bool isDark,
  }) {
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = index < letters.length ? letters[index] : '${index + 1}';

    Color border;
    Color bg;
    Widget? badge;

    if (isCorrect && isSelectedByStudent) {
      border = const Color(0xFF10B981);
      bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08);
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Your Answer (Correct) ✓',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
      );
    } else if (isCorrect) {
      border = const Color(0xFF10B981);
      bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.06);
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: const Text('Correct Answer ✓',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
      );
    } else if (isSelectedByStudent) {
      border = const Color(0xFFEF4444);
      bg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08);
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Your Answer (Incorrect) ✗',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
      );
    } else {
      border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: (isCorrect || isSelectedByStudent) ? 1.6 : 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFF10B981)
                  : (isSelectedByStudent
                      ? const Color(0xFFEF4444)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              shape: BoxShape.circle,
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: (isCorrect || isSelectedByStudent) ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMathOrText(
              text,
              isDark,
              isCorrect || isSelectedByStudent,
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isCorrect || isSelectedByStudent) ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            badge,
          ],
        ],
      ),
    );
  }
}
