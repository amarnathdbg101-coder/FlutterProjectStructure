import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/student_memory/models/student_memory.dart';
import 'package:flutter_project_structure/features/student_memory/services/smart_ai_context_helper.dart';

void main() {
  group('SmartAiContextHelper Tests', () {
    test('Prioritizes student weak topics in Dashboard quick chips', () {
      final profile = StudentMemoryProfile(
        userId: 'test_user',
        targetExam: 'GATE CS 2026',
        weakTopics: ['Deadlocks', 'B+ Trees'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chips = SmartAiContextHelper.getDashboardQuickChips(profile);
      expect(chips.length, 4);
      // First chip should target the first weak topic
      expect(chips[0].label, contains('Deadlocks'));
      expect(chips[0].prompt, contains('Deadlocks'));
      // Second chip should target the second weak topic
      expect(chips[1].label, contains('B+ Trees'));
      expect(chips[1].prompt, contains('B+ Trees'));
    });

    test('Generates exam-aligned syllabus topics when weak topics are empty', () {
      // 1. GATE CS
      final csProfile = StudentMemoryProfile(
        userId: 'cs_user',
        targetExam: 'GATE Computer Science Entrance',
        weakTopics: [],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final csChips = SmartAiContextHelper.getDashboardQuickChips(csProfile);
      expect(csChips.length, 4);
      expect(csChips.any((c) => c.label.contains('Data Structures') || c.label.contains('Operating Systems')), isTrue);

      // 2. NEET Medical
      final medProfile = StudentMemoryProfile(
        userId: 'med_user',
        targetExam: 'NEET Medical Entrance',
        weakTopics: [],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final medChips = SmartAiContextHelper.getDashboardQuickChips(medProfile);
      expect(medChips.length, 4);
      expect(medChips.any((c) => c.label.contains('Inheritance') || c.label.contains('Physiology')), isTrue);

      // 3. UPSC
      final upscProfile = StudentMemoryProfile(
        userId: 'upsc_user',
        targetExam: 'UPSC Civil Services',
        weakTopics: [],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final upscChips = SmartAiContextHelper.getDashboardQuickChips(upscProfile);
      expect(upscChips.length, 4);
      expect(upscChips.any((c) => c.label.contains('Constitutional') || c.label.contains('Monsoon')), isTrue);
    });

    test('Adapts AI Tutor suggestions dynamically based on Tutor Mode', () {
      final profile = StudentMemoryProfile(
        userId: 'test_user',
        targetExam: 'JEE Advanced',
        weakTopics: ['Rotational Dynamics'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Feynman Mode
      final feynmanPrompts = SmartAiContextHelper.getSmartTutorSuggestions(
        profile: profile,
        tutorModeKey: 'feynman',
      );
      expect(feynmanPrompts.isNotEmpty, isTrue);
      expect(feynmanPrompts.first.prompt, contains('like I am 12'));

      // Exam Cram / PYQ Mode
      final pyqPrompts = SmartAiContextHelper.getSmartTutorSuggestions(
        profile: profile,
        tutorModeKey: 'pyqStrategist',
      );
      expect(pyqPrompts.isNotEmpty, isTrue);
      expect(pyqPrompts.first.prompt, contains('exam traps'));

      // Derivation Mode
      final derivPrompts = SmartAiContextHelper.getSmartTutorSuggestions(
        profile: profile,
        tutorModeKey: 'derivation',
      );
      expect(derivPrompts.isNotEmpty, isTrue);
      expect(derivPrompts.first.prompt, contains('LaTeX derivation'));
    });

    test('Generates smart input hint and topic suggestions', () {
      final profile = StudentMemoryProfile(
        userId: 'test_user',
        targetExam: 'Class 12 Boards',
        weakTopics: ['Electromagnetic Induction'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final hint = SmartAiContextHelper.getSmartInputHint(profile);
      expect(hint, contains('Electromagnetic Induction'));

      final focusTopic = SmartAiContextHelper.getPriorityFocusTopic(profile);
      expect(focusTopic, 'Electromagnetic Induction');

      final suggestedTopics = SmartAiContextHelper.getSuggestedTopics(profile);
      expect(suggestedTopics.first, 'Electromagnetic Induction');
    });
  });
}
