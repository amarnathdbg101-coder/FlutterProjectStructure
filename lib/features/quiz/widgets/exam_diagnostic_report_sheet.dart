import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../ai_tutor/widgets/formatted_ai_text.dart';
import '../../student_memory/widgets/flashcard_deck_sheet.dart';
import '../models/exam_simulator_model.dart';

class ExamDiagnosticReportSheet extends StatelessWidget {
  final ExamDiagnosticReportModel report;

  const ExamDiagnosticReportSheet({
    super.key,
    required this.report,
  });

  static Future<void> show(BuildContext context, ExamDiagnosticReportModel report) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExamDiagnosticReportSheet(report: report),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Exam Diagnostic Forensic Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${report.examTitle} • ${report.accuracyPercentage.toInt()}% Accuracy',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Score & Accuracy Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x331E1B4B), blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL MARKS AWARDED', style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.totalScore.toStringAsFixed(1)} / ${report.maxPossibleScore.toInt()}',
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: (report.accuracyPercentage >= 70 ? const Color(0xFF10B981) : AppColors.error).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: report.accuracyPercentage >= 70 ? const Color(0xFF10B981) : AppColors.error),
                              ),
                              child: Text(
                                '${report.accuracyPercentage.toInt()}% Accuracy',
                                style: TextStyle(
                                  color: report.accuracyPercentage >= 70 ? const Color(0xFF10B981) : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),

                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildScoreStat('Correct', '🟢 ${report.correctCount}'),
                            _buildScoreStat('Incorrect', '🔴 ${report.incorrectCount}'),
                            _buildScoreStat('Skipped', '⚪ ${report.skippedCount}'),
                            _buildScoreStat('Speed', '${report.averageSecondsPerQuestion.toInt()}s/q'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Forensics Section
                  const Text('Diagnostic Error Forensics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildErrorForensicCard(
                          title: 'Conceptual Gap',
                          count: report.conceptualErrorCount,
                          color: const Color(0xFFEF4444),
                          icon: Icons.psychology_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildErrorForensicCard(
                          title: 'Examiner Trap',
                          count: report.examinerTrapCount,
                          color: const Color(0xFFF59E0B),
                          icon: Icons.warning_amber_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildErrorForensicCard(
                          title: 'Calculation Slip',
                          count: report.calculationErrorCount,
                          color: const Color(0xFF3B82F6),
                          icon: Icons.calculate_outlined,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weak Topics Action Items
                  if (report.weakTopics.isNotEmpty) ...[
                    const Text('Weak Topics Identified for Remediation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: report.weakTopics.map((topic) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Text('⚠️ $topic', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Questions Solutions & Explanations Breakdown
                  const Text('Question Forensic Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  ...report.feedbackList.map((fb) {
                    final q = fb.question;
                    Color statusColor;
                    String statusText;

                    if (fb.isCorrect) {
                      statusColor = const Color(0xFF10B981);
                      statusText = 'CORRECT (+${q.positiveMarks.toInt()})';
                    } else if (fb.isSkipped) {
                      statusColor = Colors.grey;
                      statusText = 'SKIPPED (0)';
                    } else {
                      statusColor = const Color(0xFFEF4444);
                      statusText = 'INCORRECT (-${q.negativeMarks.toInt()})';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(statusText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                              Text(q.topic, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          FormattedAiText(text: q.questionText, isDark: isDark, baseFontSize: 13.5),
                          const SizedBox(height: 10),

                          if (!fb.isCorrect && q.explanation.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡 AI Solution & Explanation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                  const SizedBox(height: 4),
                                  FormattedAiText(text: q.explanation, isDark: isDark, baseFontSize: 12.5),
                                  if (q.trapWarning.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text('⚠️ ${q.trapWarning}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // 1-Tap Remediation Actions
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.psychology, size: 14, color: Color(0xFF4F46E5)),
                                label: const Text('Teach with AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push(AppRoutes.aiChat, extra: {
                                    'initialQuery': 'Please explain this exam doubt step-by-step:\n\nQuestion: ${q.questionText}\nSolution: ${q.explanation}',
                                    'noteTitle': q.topic,
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.style_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                label: const Text('3D Flashcard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                onPressed: () {
                                  Navigator.pop(context);
                                  FlashcardDeckSheet.show(context, topic: q.topic);
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.functions_rounded, size: 14, color: Color(0xFF0284C7)),
                                label: const Text('Formula Studio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push(AppRoutes.formulaStudio, extra: {'topic': q.topic});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11)),
      ],
    );
  }

  Widget _buildErrorForensicCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
