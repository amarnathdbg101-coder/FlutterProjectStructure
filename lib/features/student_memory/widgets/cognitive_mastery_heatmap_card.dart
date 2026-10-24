import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../models/student_memory.dart';
import 'flashcard_deck_sheet.dart';

enum MasteryLevel { weak, developing, mastered }

class MasteryTopicItem {
  final String topicName;
  final int scorePercentage;
  final MasteryLevel level;

  const MasteryTopicItem({
    required this.topicName,
    required this.scorePercentage,
    required this.level,
  });

  Color get color {
    switch (level) {
      case MasteryLevel.weak:
        return const Color(0xFFEF4444);
      case MasteryLevel.developing:
        return const Color(0xFFF59E0B);
      case MasteryLevel.mastered:
        return const Color(0xFF10B981);
    }
  }

  String get label {
    switch (level) {
      case MasteryLevel.weak:
        return 'Needs Review';
      case MasteryLevel.developing:
        return 'In Progress';
      case MasteryLevel.mastered:
        return 'Mastered';
    }
  }
}

class CognitiveMasteryHeatmapCard extends StatelessWidget {
  final StudentMemoryProfile profile;

  const CognitiveMasteryHeatmapCard({
    super.key,
    required this.profile,
  });

  List<MasteryTopicItem> _buildHeatmapItems() {
    final items = <MasteryTopicItem>[];
    final addedTopics = <String>{};

    // 1. Process explicit topicMastery map if available
    profile.topicMastery.forEach((topic, score) {
      if (addedTopics.contains(topic.toLowerCase())) return;
      addedTopics.add(topic.toLowerCase());

      MasteryLevel level;
      if (score >= 75) {
        level = MasteryLevel.mastered;
      } else if (score >= 45) {
        level = MasteryLevel.developing;
      } else {
        level = MasteryLevel.weak;
      }

      items.add(MasteryTopicItem(topicName: topic, scorePercentage: score, level: level));
    });

    // 2. Process weak topics
    for (final topic in profile.weakTopics) {
      if (addedTopics.contains(topic.toLowerCase())) continue;
      addedTopics.add(topic.toLowerCase());
      items.add(MasteryTopicItem(topicName: topic, scorePercentage: 35, level: MasteryLevel.weak));
    }

    // 3. Process strong topics
    for (final topic in profile.strongTopics) {
      if (addedTopics.contains(topic.toLowerCase())) continue;
      addedTopics.add(topic.toLowerCase());
      items.add(MasteryTopicItem(topicName: topic, scorePercentage: 90, level: MasteryLevel.mastered));
    }

    return items;
  }

  void _showTopicActionSheet(BuildContext context, MasteryTopicItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.topicName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.scorePercentage}% • ${item.label}',
                      style: TextStyle(color: item.color, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Select Learning Drill:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.psychology, color: Color(0xFF4F46E5)),
                title: const Text('Teach with AI Tutor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Step-by-step guidance on this topic'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.aiChat, extra: {
                    'initialQuery': 'Please guide me through ${item.topicName} with clear explanations and formulas.',
                    'noteTitle': item.topicName,
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.quiz_outlined, color: Color(0xFF10B981)),
                title: const Text('Practice Adaptive Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Test understanding with 5 questions'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.quizzes, extra: {'topic': item.topicName});
                },
              ),
              ListTile(
                leading: const Icon(Icons.style_rounded, color: Color(0xFF8B5CF6)),
                title: const Text('Review 3D Flashcards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Active recall flashcard practice deck'),
                onTap: () {
                  Navigator.pop(ctx);
                  FlashcardDeckSheet.show(context, topic: item.topicName);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _buildHeatmapItems();

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                const Text('Cognitive Mastery Heatmap', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('0 Tracked', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)).withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 24, color: isDark ? Colors.blue[300] : const Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 10),
            Text(
              'No Mastery Topics Tracked Yet',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Topics appear here automatically as you ask AI doubts, solve adaptive quizzes, or add custom topics.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final weakCount = items.where((i) => i.level == MasteryLevel.weak).length;
    final developingCount = items.where((i) => i.level == MasteryLevel.developing).length;
    final masteredCount = items.where((i) => i.level == MasteryLevel.mastered).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: Color(0xFF4F46E5), size: 18),
                  SizedBox(width: 8),
                  Text('Cognitive Mastery Heatmap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('${items.length} Topics Tracked', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),

          // Mastery Distribution Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendLabel('🟢 Mastered ($masteredCount)', const Color(0xFF10B981)),
              _buildLegendLabel('🟡 Developing ($developingCount)', const Color(0xFFF59E0B)),
              _buildLegendLabel('🔴 Needs Focus ($weakCount)', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),

          // Automated Revision Warning Alert
          if (weakCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automated Revision Alert: $weakCount topic(s) fell below 40% mastery threshold.',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Heatmap Grid Matrix
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return InkWell(
                onTap: () => _showTopicActionSheet(context, item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: item.color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.topicName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.scorePercentage}%',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: item.color),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
    );
  }
}
