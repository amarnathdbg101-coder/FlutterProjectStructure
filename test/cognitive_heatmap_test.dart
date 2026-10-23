import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/student_memory.dart';
import 'package:studysilo/features/student_memory/widgets/cognitive_mastery_heatmap_card.dart';

void main() {
  group('Cognitive Mastery Heatmap & Profile Tests', () {
    test('StudentMemoryProfile computes readiness score and formats AI prompt context', () {
      final profile = StudentMemoryProfile(
        userId: 'student-101',
        targetExam: 'JEE Advanced Physics',
        academicLevel: 'Class 12',
        strongTopics: const ['Rotational Dynamics', 'Electrostatics'],
        weakTopics: const ['Wave Optics', 'Thermodynamics'],
        topicMastery: const {
          'Rotational Dynamics': 90,
          'Wave Optics': 35,
        },
        rawReadinessScore: 78,
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.readinessScore, 78);
      expect(profile.hasWeaknesses, true);
      expect(profile.hasStrengths, true);
      expect(profile.formattedAiContext, contains('JEE Advanced Physics'));
      expect(profile.formattedAiContext, contains('Wave Optics'));
    });

    test('MasteryTopicItem assigns correct colors and status labels', () {
      const weakItem = MasteryTopicItem(
        topicName: 'Wave Optics',
        scorePercentage: 30,
        level: MasteryLevel.weak,
      );

      const masterItem = MasteryTopicItem(
        topicName: 'Rotational Dynamics',
        scorePercentage: 92,
        level: MasteryLevel.mastered,
      );

      expect(weakItem.label, 'Needs Review');
      expect(masterItem.label, 'Mastered');
      expect(weakItem.color.value, 0xFFEF4444);
      expect(masterItem.color.value, 0xFF10B981);
    });
  });
}
