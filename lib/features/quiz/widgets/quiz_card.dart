import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../models/quiz_model.dart';

/// Reusable clean Quiz Card adhering to the 60-30-10 design system
class QuizCard extends StatelessWidget {
  final QuizModel quiz;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  final bool isDark;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.onStart,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color difficultyColor;
    String badgeText;

    switch (quiz.difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = const Color(0xFF10B981);
        badgeText = 'Easy';
        break;
      case 'hard':
        difficultyColor = const Color(0xFFEF4444);
        badgeText = 'Hard';
        break;
      case 'medium':
        difficultyColor = const Color(0xFFF59E0B);
        badgeText = 'Medium';
        break;
      default:
        difficultyColor = const Color(0xFF2563EB);
        badgeText = 'Adaptive';
    }

    String formatBadgeText = 'MCQ';
    Color formatColor = const Color(0xFF2563EB);
    if (quiz.testType == 'subjective') {
      formatBadgeText = 'Subjective';
      formatColor = const Color(0xFF8B5CF6);
    } else if (quiz.testType == 'mixed') {
      formatBadgeText = 'Mixed';
      formatColor = const Color(0xFF06B6D4);
    }

    final estimatedMinutes = (quiz.totalQuestions * (quiz.isSubjective ? 3.0 : 1.5)).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Monochrome Icon Container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: formatColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formatBadgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: formatColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: difficultyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: difficultyColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${quiz.totalQuestions} Questions  •  ~$estimatedMinutes mins',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) async {
                  if (val == 'delete') {
                    final confirm = await CustomDialog.confirm(
                      context,
                      title: 'Delete Quiz',
                      message: 'Are you sure you want to delete "${quiz.title}"?',
                      confirmText: 'Delete',
                      isDestructive: true,
                    );
                    if (confirm) {
                      onDelete();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('Delete Quiz', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Topic: ${quiz.topic}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Start Quiz', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
