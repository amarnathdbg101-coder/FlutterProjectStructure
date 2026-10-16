import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/ai_tutor/models/chat_message_model.dart';

void main() {
  group('AI Tutor Model Tests', () {
    test('ChatMessageModel serialization with LaTeX and follow-up chips', () {
      final json = {
        'id': 'msg-1',
        'role': 'assistant',
        'content': r'Here is the step-by-step derivation of $\int x \cos(x) dx$',
        'image_url': null,
        'latex_formulas': [r'\int u \, dv = uv - \int v \, du', r'x \sin(x) + \cos(x) + C'],
        'follow_up_questions': ['How do we choose u and dv?', 'Can you show with tabular integration?'],
        'key_concepts': ['Integration by parts', 'LIATE rule'],
        'created_at': '2026-10-03T10:15:00Z',
      };

      final msg = ChatMessageModel.fromJson(json);
      expect(msg.id, 'msg-1');
      expect(msg.role, 'assistant');
      expect(msg.isAssistant, true);
      expect(msg.isUser, false);
      expect(msg.latexFormulas.length, 2);
      expect(msg.followUpQuestions.length, 2);
      expect(msg.keyConcepts, contains('LIATE rule'));

      final serialized = msg.toJson();
      expect(serialized['role'], 'assistant');
      expect((serialized['latex_formulas'] as List).length, 2);
    });

    test('User ChatMessageModel with image attachment', () {
      final userMsg = ChatMessageModel(
        id: 'u-1',
        role: 'user',
        content: 'Solve question 4 from this photo',
        imageUrl: '/storage/photo.jpg',
        createdAt: DateTime.now(),
      );

      expect(userMsg.isUser, true);
      expect(userMsg.imageUrl, '/storage/photo.jpg');
    });
  });
}
