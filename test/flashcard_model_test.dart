import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/flashcard_model.dart';

void main() {
  group('FlashcardModel & FlashcardDeckModel Tests', () {
    test('FlashcardModel serializes and deserializes correctly', () {
      final card = FlashcardModel(
        id: 'card-101',
        topic: 'Operating Systems Deadlocks',
        questionFront: 'What are the 4 necessary conditions for Deadlock?',
        answerBack: '1. Mutual Exclusion\n2. Hold and Wait\n3. No Preemption\n4. Circular Wait',
        difficulty: 'medium',
        isMastered: true,
        isReviewed: true,
        createdAt: DateTime(2026, 10, 1),
      );

      final json = card.toJson();
      final revived = FlashcardModel.fromJson(json);

      expect(revived.id, 'card-101');
      expect(revived.topic, 'Operating Systems Deadlocks');
      expect(revived.questionFront, contains('4 necessary conditions'));
      expect(revived.answerBack, contains('Circular Wait'));
      expect(revived.isMastered, true);
      expect(revived.isReviewed, true);
    });

    test('FlashcardDeckModel computes mastery percentage accurately', () {
      final cards = [
        FlashcardModel(
          id: 'c1',
          topic: 'Calculus',
          questionFront: 'Derivative of sin(x)?',
          answerBack: 'cos(x)',
          isMastered: true,
          createdAt: DateTime.now(),
        ),
        FlashcardModel(
          id: 'c2',
          topic: 'Calculus',
          questionFront: 'Integral of 1/x dx?',
          answerBack: 'ln|x| + C',
          isMastered: false,
          createdAt: DateTime.now(),
        ),
      ];

      final deck = FlashcardDeckModel(
        id: 'deck-calculus',
        title: 'Calculus Differentiation Deck',
        topic: 'Calculus',
        cardCount: 2,
        masteredCount: 1,
        cards: cards,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(deck.masteryPercentage, 0.5);
      expect(deck.cards.length, 2);

      final json = deck.toJson();
      final revived = FlashcardDeckModel.fromJson(json);

      expect(revived.id, 'deck-calculus');
      expect(revived.title, 'Calculus Differentiation Deck');
      expect(revived.masteredCount, 1);
      expect(revived.cards.first.isMastered, true);
    });
  });
}
