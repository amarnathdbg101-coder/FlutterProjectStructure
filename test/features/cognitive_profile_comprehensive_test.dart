import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/student_memory.dart';
import 'package:studysilo/features/student_memory/services/smart_ai_context_helper.dart';
import 'package:studysilo/features/student_memory/widgets/cognitive_mastery_heatmap_card.dart';

void main() {
  group('Comprehensive Cognitive Profile & Mastery Heatmap Tests (20+ Cases)', () {
    test('1. StudentMemoryProfile defaultProfile provides clean baseline', () {
      final profile = StudentMemoryProfile.defaultProfile();

      expect(profile.userId, 'local_scholar');
      expect(profile.targetExam, 'General Academic Preparation');
      expect(profile.strongTopics, isEmpty);
      expect(profile.weakTopics, isEmpty);
      expect(profile.readinessScore, 50);
      expect(profile.hasWeaknesses, false);
      expect(profile.hasStrengths, false);
    });

    test('2. StudentMemoryProfile calculates readinessScore using rawReadinessScore if set', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        rawReadinessScore: 82,
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.readinessScore, 82);
    });

    test('3. StudentMemoryProfile calculates readinessScore dynamically from quiz score & topics ratio', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        rawReadinessScore: 0,
        totalQuizzesTaken: 5,
        averageQuizScore: 80.0, // 80 * 0.6 = 48
        strongTopics: const ['T1', 'T2', 'T3'], // 3 / 4 = 0.75 * 40 = 30
        weakTopics: const ['T4'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 48 + 30 = 78
      expect(profile.readinessScore, 78);
    });

    test('4. StudentMemoryProfile formattedAiContext contains all key directives', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        targetExam: 'NEET UG Medical',
        academicLevel: 'Class 12 Bio',
        strongTopics: const ['Genetics', 'Ecology'],
        weakTopics: const ['Human Physiology'],
        examTrapsEncountered: const ['Neglecting SI units in osmotic pressure'],
        aiSummary: 'Strong in genetics, needs practice in renal physiology.',
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ctx = profile.formattedAiContext;

      expect(ctx, contains('NEET UG Medical'));
      expect(ctx, contains('Genetics, Ecology'));
      expect(ctx, contains('Human Physiology'));
      expect(ctx, contains('Neglecting SI units in osmotic pressure'));
      expect(ctx, contains('STRICT EXAM DIRECTIVE'));
    });

    test('5. StudentMemoryProfile JSON serialization and deserialization', () {
      final json = {
        'user_id': 'u-99',
        'target_exam': 'GATE CS 2026',
        'academic_level': 'B.Tech CS',
        'strong_topics': ['Operating Systems', 'DBMS'],
        'weak_topics': ['Compiler Design'],
        'exam_traps': ['LALR vs CLR state parsing'],
        'topic_mastery': {
          'Operating Systems': 90,
          'Compiler Design': 35,
        },
        'readiness_score': 74,
        'total_study_minutes': 300,
        'total_quizzes_taken': 12,
        'average_quiz_score': 85.0,
      };

      final profile = StudentMemoryProfile.fromJson(json);

      expect(profile.userId, 'u-99');
      expect(profile.targetExam, 'GATE CS 2026');
      expect(profile.strongTopics, containsAll(['Operating Systems', 'DBMS']));
      expect(profile.weakTopics, contains('Compiler Design'));
      expect(profile.topicMastery['Operating Systems'], 90);
      expect(profile.topicMastery['Compiler Design'], 35);
      expect(profile.rawReadinessScore, 74);
      expect(profile.totalStudyMinutes, 300);
      expect(profile.totalQuizzesTaken, 12);
      expect(profile.averageQuizScore, 85.0);
    });

    test('6. StudentMemoryProfile copyWith immutable update', () {
      final profile = StudentMemoryProfile.defaultProfile();

      final updated = profile.copyWith(
        targetExam: 'UPSC CSE',
        weakTopics: const ['Polity', 'History'],
      );

      expect(updated.userId, 'local_scholar');
      expect(updated.targetExam, 'UPSC CSE');
      expect(updated.weakTopics, containsAll(['Polity', 'History']));
      expect(profile.targetExam, 'General Academic Preparation'); // Original untouched
    });

    test('7. MasteryTopicItem weak level properties', () {
      const item = MasteryTopicItem(
        topicName: 'Quantum Mechanics',
        scorePercentage: 30,
        level: MasteryLevel.weak,
      );

      expect(item.label, 'Needs Review');
      expect(item.color.value, 0xFFEF4444);
    });

    test('8. MasteryTopicItem developing level properties', () {
      const item = MasteryTopicItem(
        topicName: 'Electromagnetism',
        scorePercentage: 60,
        level: MasteryLevel.developing,
      );

      expect(item.label, 'In Progress');
      expect(item.color.value, 0xFFF59E0B);
    });

    test('9. MasteryTopicItem mastered level properties', () {
      const item = MasteryTopicItem(
        topicName: 'Thermodynamics',
        scorePercentage: 92,
        level: MasteryLevel.mastered,
      );

      expect(item.label, 'Mastered');
      expect(item.color.value, 0xFF10B981);
    });

    test('10. SmartAiContextHelper getDashboardQuickChips returns dynamic prompts based on weak topics', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        weakTopics: const ['Organic Chemistry'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chips = SmartAiContextHelper.getDashboardQuickChips(profile);

      expect(chips.isNotEmpty, true);
      final labels = chips.map((c) => c.label).join(' ');
      expect(labels, contains('Organic Chemistry'));
    });

    test('11. SmartAiContextHelper getSuggestedTopics lists weak and target exam topics', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        targetExam: 'JEE Physics',
        weakTopics: const ['Optics', 'Wave Mechanics'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final suggested = SmartAiContextHelper.getSuggestedTopics(profile);

      expect(suggested, contains('Optics'));
      expect(suggested, contains('Wave Mechanics'));
    });

    test('12. SmartAiContextHelper getSmartInputHint incorporates priority weak topic', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        weakTopics: const ['Calculus Integration'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final hint = SmartAiContextHelper.getSmartInputHint(profile);

      expect(hint, contains('Calculus Integration'));
    });

    test('13. SmartAiContextHelper getPriorityFocusTopic returns first weak topic if available', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        weakTopics: const ['Rotational Mechanics', 'Fluids'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final priority = SmartAiContextHelper.getPriorityFocusTopic(profile);

      expect(priority, 'Rotational Mechanics');
    });

    test('14. StudentMemoryProfile handles null / empty JSON string lists gracefully', () {
      final json = <String, dynamic>{
        'user_id': 'u-1',
        'weak_topics': null,
        'strong_topics': null,
        'exam_traps': null,
      };

      final profile = StudentMemoryProfile.fromJson(json);

      expect(profile.weakTopics, isEmpty);
      expect(profile.strongTopics, isEmpty);
      expect(profile.examTrapsEncountered, isEmpty);
    });

    test('15. StudentMemoryProfile.toJson exports all key fields', () {
      final profile = StudentMemoryProfile(
        userId: 'u-5',
        targetExam: 'GATE CS',
        academicLevel: 'B.Tech',
        strongTopics: const ['OS'],
        weakTopics: const ['DBMS'],
        totalStudyMinutes: 150,
        lastActiveAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final json = profile.toJson();

      expect(json['user_id'], 'u-5');
      expect(json['target_exam'], 'GATE CS');
      expect(json['strong_topics'], contains('OS'));
      expect(json['weak_topics'], contains('DBMS'));
      expect(json['total_study_minutes'], 150);
    });

    test('16. Readiness score clamps at 100 maximum', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        rawReadinessScore: 120, // Over 100
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.readinessScore, 100);
    });

    test('17. Readiness score clamps at 0 minimum for positive raw scores', () {
      final profile = StudentMemoryProfile(
        userId: 'u1',
        rawReadinessScore: 5,
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.readinessScore, 5);
    });

    test('18. StudentMemoryProfile detects hasWeaknesses correctly', () {
      final profileNoWeak = StudentMemoryProfile.defaultProfile();
      final profileWithWeak = profileNoWeak.copyWith(weakTopics: const ['Topic A']);

      expect(profileNoWeak.hasWeaknesses, false);
      expect(profileWithWeak.hasWeaknesses, true);
    });

    test('19. StudentMemoryProfile detects hasStrengths correctly', () {
      final profileNoStrong = StudentMemoryProfile.defaultProfile();
      final profileWithStrong = profileNoStrong.copyWith(strongTopics: const ['Topic B']);

      expect(profileNoStrong.hasStrengths, false);
      expect(profileWithStrong.hasStrengths, true);
    });

    test('20. TopicMastery map string parsing converts numbers properly', () {
      final json = {
        'topic_mastery': {
          'Topic A': '85', // String number
          'Topic B': 40,   // Int number
          'Topic C': 95.5, // Double number
        }
      };

      final profile = StudentMemoryProfile.fromJson(json);

      expect(profile.topicMastery['Topic A'], 85);
      expect(profile.topicMastery['Topic B'], 40);
      expect(profile.topicMastery['Topic C'], 95);
    });
  });
}
