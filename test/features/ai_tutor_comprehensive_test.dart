import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/ai_tutor/controllers/ai_tutor_controller.dart';
import 'package:studysilo/features/ai_tutor/models/chat_message_model.dart';
import 'package:studysilo/features/ai_tutor/models/chat_session_model.dart';

void main() {
  group('Comprehensive AI Tutor, Model Selector & Streaming Engine Tests (20+ Cases)', () {
    test('1. TutorModeExtension provides labels, short tags, and IDs for all modes', () {
      expect(TutorMode.academic.label, contains('Academic Professor'));
      expect(TutorMode.academic.shortTag, 'Professor');
      expect(TutorMode.academic.id, 'academic');

      expect(TutorMode.pyqStrategist.label, contains('PYQ Strategist'));
      expect(TutorMode.pyqStrategist.shortTag, 'PYQ');
      expect(TutorMode.pyqStrategist.id, 'pyq');

      expect(TutorMode.feynman.label, contains('Feynman'));
      expect(TutorMode.feynman.shortTag, 'Feynman');
      expect(TutorMode.feynman.id, 'feynman');

      expect(TutorMode.trapHunter.label, contains('Trap Hunter'));
      expect(TutorMode.trapHunter.shortTag, 'Traps');
      expect(TutorMode.trapHunter.id, 'traps');

      expect(TutorMode.derivation.label, contains('Math & Steps'));
      expect(TutorMode.derivation.shortTag, 'Steps');
      expect(TutorMode.derivation.id, 'derivation');

      expect(TutorMode.socratic.label, contains('Socratic Coach'));
      expect(TutorMode.socratic.shortTag, 'Socratic');
      expect(TutorMode.socratic.id, 'socratic');
    });

    test('2. AiTutorController.availableModels contains top models from Google, OpenAI, Anthropic & DeepSeek', () {
      final models = AiTutorController.availableModels;

      expect(models.length, greaterThanOrEqualTo(10));
      expect(models.any((m) => m.modelId == 'gemini-3.5-flash-lite'), true);
      expect(models.any((m) => m.modelId == 'gpt-4o'), true);
      expect(models.any((m) => m.modelId == 'claude-3-7-sonnet'), true);
      expect(models.any((m) => m.modelId == 'deepseek-r1'), true);
    });

    test('3. ChatMessageModel JSON roundtrip for user and assistant messages', () {
      final msg = ChatMessageModel(
        id: 'msg-1',
        role: 'user',
        content: 'Explain Schrodinger Wave Equation',
        imageUrl: 'https://r2.shopsilo.in/doubt.jpg',
        followUpQuestions: const ['What is psi squared?', 'What are boundary conditions?'],
        createdAt: DateTime(2026, 10, 1),
        sessionId: 'sess-101',
      );

      final json = msg.toJson();
      final revived = ChatMessageModel.fromJson(json);

      expect(revived.id, 'msg-1');
      expect(revived.role, 'user');
      expect(revived.isUser, true);
      expect(revived.isAssistant, false);
      expect(revived.content, 'Explain Schrodinger Wave Equation');
      expect(revived.imageUrl, 'https://r2.shopsilo.in/doubt.jpg');
      expect(revived.followUpQuestions.length, 2);
      expect(revived.sessionId, 'sess-101');
    });

    test('4. ChatMessageModel handles assistant role correctly', () {
      final msg = ChatMessageModel(
        id: 'bot-1',
        role: 'assistant',
        content: 'The Schrodinger equation is...',
        createdAt: DateTime.now(),
      );

      expect(msg.isUser, false);
      expect(msg.isAssistant, true);
    });

    test('5. ChatMessageModel copyWith allows updating content and image URL', () {
      final original = ChatMessageModel(
        id: 'm1',
        role: 'assistant',
        content: 'Initial partial response...',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        content: 'Initial partial response... and full completed response!',
        imageUrl: 'https://r2.shopsilo.in/img.png',
      );

      expect(updated.id, 'm1');
      expect(updated.content, contains('full completed response!'));
      expect(updated.imageUrl, 'https://r2.shopsilo.in/img.png');
    });

    test('6. ChatSessionModel JSON deserialization and copyWith', () {
      final json = {
        'id': 'session-101',
        'title': 'Quantum Physics Doubts',
        'created_at': '2026-10-01T10:00:00.000Z',
        'updated_at': '2026-10-01T10:30:00.000Z',
        'message_count': 6,
        'last_message': 'Thank you Professor!',
      };

      final session = ChatSessionModel.fromJson(json);

      expect(session.id, 'session-101');
      expect(session.title, 'Quantum Physics Doubts');
      expect(session.messageCount, 6);
      expect(session.lastMessage, 'Thank you Professor!');

      final renamed = session.copyWith(title: 'Advanced Quantum Mechanics');
      expect(renamed.title, 'Advanced Quantum Mechanics');
      expect(renamed.id, 'session-101');
    });

    test('7. AiTutorController switchModeByName parses string keywords correctly', () {
      final controller = AiTutorController();

      controller.switchModeByName('feynman ELI5');
      expect(controller.tutorMode, TutorMode.feynman);

      controller.switchModeByName('pyq exam strategy');
      expect(controller.tutorMode, TutorMode.pyqStrategist);

      controller.switchModeByName('trap hunter');
      expect(controller.tutorMode, TutorMode.trapHunter);

      controller.switchModeByName('math steps derivation');
      expect(controller.tutorMode, TutorMode.derivation);

      controller.switchModeByName('socratic coach');
      expect(controller.tutorMode, TutorMode.socratic);

      controller.switchModeByName('academic professor');
      expect(controller.tutorMode, TutorMode.academic);
    });

    test('8. AiTutorController toggleSocraticMode toggles between socratic and academic', () {
      final controller = AiTutorController();
      expect(controller.isSocraticMode, false);

      controller.toggleSocraticMode();
      expect(controller.isSocraticMode, true);
      expect(controller.tutorMode, TutorMode.socratic);

      controller.toggleSocraticMode();
      expect(controller.isSocraticMode, false);
      expect(controller.tutorMode, TutorMode.academic);
    });

    test('9. AiTutorController setNoteContext sets active note title and context', () {
      final controller = AiTutorController();

      controller.setNoteContext('Thermodynamics Laws', 'First law dQ = dU + dW');

      expect(controller.activeNoteTitle, 'Thermodynamics Laws');
      expect(controller.activeNoteContext, 'First law dQ = dU + dW');
    });

    test('10. AiTutorController setImageAttachment and clearImageAttachment', () {
      final controller = AiTutorController();

      controller.setImageAttachment('/path/to/img.png', 'base64data');

      expect(controller.selectedImagePath, '/path/to/img.png');
      expect(controller.selectedImageBase64, 'base64data');

      controller.clearImageAttachment();

      expect(controller.selectedImagePath, isNull);
      expect(controller.selectedImageBase64, isNull);
    });

    test('11. AiTutorController startNewChat resets session state, messages, and attachments', () {
      final controller = AiTutorController();
      controller.setNoteContext('Title', 'Context');
      controller.setImageAttachment('/img.png', 'b64');

      controller.startNewChat();

      expect(controller.messages, isEmpty);
      expect(controller.currentSession, isNull);
      expect(controller.activeNoteTitle, isNull);
      expect(controller.selectedImagePath, isNull);
    });

    test('12. AiTutorController canEditLastQuestion rules', () {
      final controller = AiTutorController();

      // Empty messages -> false
      expect(controller.canEditLastQuestion('non-existent'), false);

      controller.messages.add(
        ChatMessageModel(id: 'u1', role: 'user', content: 'What is G?', createdAt: DateTime.now()),
      );
      controller.messages.add(
        ChatMessageModel(id: 'a1', role: 'assistant', content: 'Gravitational constant...', createdAt: DateTime.now()),
      );

      // Last question u1 can be edited
      expect(controller.canEditLastQuestion('u1'), true);
      expect(controller.canEditLastQuestion('a1'), false);
    });

    test('13. AiTutorController canRegenerateAnswer rules', () {
      final controller = AiTutorController();

      controller.messages.add(
        ChatMessageModel(id: 'u1', role: 'user', content: 'What is G?', createdAt: DateTime.now()),
      );
      controller.messages.add(
        ChatMessageModel(id: 'a1', role: 'assistant', content: 'Gravitational constant...', createdAt: DateTime.now()),
      );

      // Last assistant answer a1 can be regenerated
      expect(controller.canRegenerateAnswer('a1'), true);
      expect(controller.canRegenerateAnswer('u1'), false);
    });

    test('14. AiModelOption attributes', () {
      const option = AiModelOption(
        providerId: 'google',
        providerName: 'Google Gemini 3',
        modelId: 'gemini-3.5-flash-lite',
        modelName: 'Gemini 3.5 Flash-Lite',
        description: 'Fast responses',
        iconEmoji: '🚀',
      );

      expect(option.providerId, 'google');
      expect(option.modelId, 'gemini-3.5-flash-lite');
      expect(option.iconEmoji, '🚀');
    });

    test('15. ChatMessageModel fromJson handles blocks list parsing', () {
      final json = {
        'id': 'msg-blocks',
        'role': 'assistant',
        'content': 'Main response text',
        'blocks': [
          {
            'type': 'code',
            'content': 'print("hello")',
            'language': 'python',
          }
        ]
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.content, 'Main response text');
      expect(msg.blocks, isNotNull);
      expect(msg.blocks!.length, 1);
      expect(msg.blocks!.first.type, 'code');
      expect(msg.blocks!.first.text, 'print("hello")');
    });

    test('16. ChatMessageModel fromJson handles spokenTranscript', () {
      final json = {
        'id': 'msg-audio',
        'role': 'assistant',
        'content': 'Answer text',
        'spoken_transcript': 'Spoken audio transcript version',
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.spokenTranscript, 'Spoken audio transcript version');
    });

    test('17. AiTutorController beginEditingLastQuestion and cancelEditingMessage', () {
      final controller = AiTutorController();
      controller.messages.add(
        ChatMessageModel(id: 'u1', role: 'user', content: 'Question', createdAt: DateTime.now()),
      );

      controller.beginEditingLastQuestion('u1');
      expect(controller.editingMessageId, 'u1');

      controller.cancelEditingMessage();
      expect(controller.editingMessageId, isNull);
    });

    test('18. ChatSessionModel default values', () {
      final session = ChatSessionModel(
        id: 's1',
        title: 'New Chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(session.messageCount, 0);
      expect(session.lastMessage, '');
    });

    test('19. ChatMessageModel handles null created_at by providing DateTime.now()', () {
      final json = {
        'id': 'm-null-date',
        'role': 'user',
        'content': 'Test',
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.createdAt, isNotNull);
    });

    test('20. AiTutorController selectModel updates selected model', () async {
      final controller = AiTutorController();
      final target = AiTutorController.availableModels.firstWhere((m) => m.modelId == 'gpt-4o');

      await controller.selectModel(target);

      expect(controller.selectedModel.modelId, 'gpt-4o');
      expect(controller.selectedModel.providerId, 'openai');
    });
  });
}
