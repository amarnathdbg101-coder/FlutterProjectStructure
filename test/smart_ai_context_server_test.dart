import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/student_memory.dart';
import 'package:studysilo/features/student_memory/services/smart_ai_context_helper.dart';

void main() {
  group('Server-Side Smart Context Fast Path Tests', () {
    tearDown(() {
      SmartAiContextHelper.clearServerContext();
    });

    test('Consumes server-calculated smart context with O(1) instant resolution', () {
      final serverResponse = SmartContextResponse(
        targetExam: 'GATE CS 2026',
        quickChips: const [
          SmartPromptItem(
            label: '🎯 Deadlocks Traps',
            prompt: 'Server computed prompt for Deadlocks',
          ),
          SmartPromptItem(
            label: '💡 Intuition: B+ Trees',
            prompt: 'Server computed prompt for B+ Trees',
          ),
        ],
        tutorSuggestions: const [
          SmartPromptItem(
            label: '🧠 Socratic Inquiry: Deadlocks',
            prompt: 'Server computed socratic prompt',
          ),
        ],
        suggestedTopics: const ['Deadlocks', 'B+ Trees', 'TCP Congestion'],
        focusTopic: 'Deadlocks',
        inputHint: 'Server hint: Ask about Deadlocks',
        topicHint: 'e.g. Deadlocks, B+ Trees, TCP Congestion...',
      );

      SmartAiContextHelper.setServerContext(serverResponse);

      final profile = StudentMemoryProfile(
        userId: 'gate_student',
        targetExam: 'GATE CS 2026',
        weakTopics: ['Deadlocks'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify fast path consumes server response
      final chips = SmartAiContextHelper.getDashboardQuickChips(profile);
      expect(chips.length, 2);
      expect(chips.first.label, '🎯 Deadlocks Traps');
      expect(chips.first.prompt, 'Server computed prompt for Deadlocks');

      final suggestions = SmartAiContextHelper.getSmartTutorSuggestions(profile: profile);
      expect(suggestions.first.label, '🧠 Socratic Inquiry: Deadlocks');

      final inputHint = SmartAiContextHelper.getSmartInputHint(profile);
      expect(inputHint, 'Server hint: Ask about Deadlocks');

      final focusTopic = SmartAiContextHelper.getPriorityFocusTopic(profile);
      expect(focusTopic, 'Deadlocks');
    });

    test('Gracefully falls back to client heuristics if server context is cleared', () {
      SmartAiContextHelper.clearServerContext();

      final profile = StudentMemoryProfile(
        userId: 'gate_student',
        targetExam: 'GATE Computer Science Entrance',
        weakTopics: ['B+ Trees'],
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chips = SmartAiContextHelper.getDashboardQuickChips(profile);
      expect(chips.length, 4);
      expect(chips.first.label, contains('B+ Trees'));
    });
  });
}
