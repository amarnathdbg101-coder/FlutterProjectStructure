import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/flashcard_model.dart';

void main() {
  group('Comprehensive Spaced Repetition & SM-2 Flashcard Engine Tests (20+ Cases)', () {
    test('1. FlashcardModel default constructor assigns baseline SM-2 values', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Chemistry',
        questionFront: 'What is Avogadro Number?',
        answerBack: '6.022 x 10^23',
        createdAt: DateTime.now(),
      );

      expect(card.intervalDays, 1);
      expect(card.easeFactor, 2.5);
      expect(card.repetitionCount, 0);
      expect(card.nextReviewAt, isNull);
      expect(card.isDueForReview, true);
    });

    test('2. SM-2 Rating Again resets repetition count to 0 and interval to 1 day', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Physics',
        questionFront: 'Newton Second Law',
        answerBack: 'F = ma',
        createdAt: DateTime.now(),
        intervalDays: 14,
        easeFactor: 2.5,
        repetitionCount: 3,
        isMastered: true,
      );

      final reviewed = card.calculateNextReview(ReviewRating.again);

      expect(reviewed.repetitionCount, 0);
      expect(reviewed.intervalDays, 1);
      expect(reviewed.easeFactor, closeTo(2.3, 0.01)); // 2.5 - 0.2
      expect(reviewed.isMastered, false);
      expect(reviewed.difficulty, 'again');
      expect(reviewed.isReviewed, true);
      expect(reviewed.nextReviewAt, isNotNull);
    });

    test('3. SM-2 Rating Again clamps ease factor to minimum 1.3', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Math',
        questionFront: 'Derive Euler Identity',
        answerBack: 'e^(i pi) + 1 = 0',
        createdAt: DateTime.now(),
        easeFactor: 1.4,
      );

      final reviewed = card.calculateNextReview(ReviewRating.again);

      expect(reviewed.easeFactor, 1.3); // Clamped at 1.3
    });

    test('4. SM-2 Rating Hard increases interval by 1.2x and lowers ease factor by 0.15', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Bio',
        questionFront: 'Mitochondria function',
        answerBack: 'Powerhouse of cell',
        createdAt: DateTime.now(),
        intervalDays: 10,
        easeFactor: 2.5,
        repetitionCount: 2,
      );

      final reviewed = card.calculateNextReview(ReviewRating.hard);

      expect(reviewed.repetitionCount, 3);
      expect(reviewed.intervalDays, 12); // (10 * 1.2).round() = 12
      expect(reviewed.easeFactor, closeTo(2.35, 0.01)); // 2.5 - 0.15
      expect(reviewed.difficulty, 'hard');
    });

    test('5. SM-2 Rating Good on 1st repetition sets 1 day interval', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'CS',
        questionFront: 'Stack vs Queue',
        answerBack: 'LIFO vs FIFO',
        createdAt: DateTime.now(),
        repetitionCount: 0,
      );

      final reviewed = card.calculateNextReview(ReviewRating.good);

      expect(reviewed.repetitionCount, 1);
      expect(reviewed.intervalDays, 1);
      expect(reviewed.difficulty, 'good');
    });

    test('6. SM-2 Rating Good on 2nd repetition sets 3 days interval', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'CS',
        questionFront: 'Stack vs Queue',
        answerBack: 'LIFO vs FIFO',
        createdAt: DateTime.now(),
        repetitionCount: 1,
        intervalDays: 1,
      );

      final reviewed = card.calculateNextReview(ReviewRating.good);

      expect(reviewed.repetitionCount, 2);
      expect(reviewed.intervalDays, 3);
    });

    test('7. SM-2 Rating Good on 3rd repetition applies ease factor multiplier', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'CS',
        questionFront: 'Stack vs Queue',
        answerBack: 'LIFO vs FIFO',
        createdAt: DateTime.now(),
        repetitionCount: 2,
        intervalDays: 3,
        easeFactor: 2.5,
      );

      final reviewed = card.calculateNextReview(ReviewRating.good);

      expect(reviewed.repetitionCount, 3);
      expect(reviewed.intervalDays, 8); // (3 * 2.5).round() = 8
    });

    test('8. SM-2 Rating Easy on 1st repetition sets 3 days interval', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Hist',
        questionFront: 'Year of Independence',
        answerBack: '1947',
        createdAt: DateTime.now(),
        repetitionCount: 0,
      );

      final reviewed = card.calculateNextReview(ReviewRating.easy);

      expect(reviewed.repetitionCount, 1);
      expect(reviewed.intervalDays, 3);
      expect(reviewed.difficulty, 'easy');
    });

    test('9. SM-2 Rating Easy on 2nd repetition sets 7 days interval and marks mastered', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Hist',
        questionFront: 'Year of Independence',
        answerBack: '1947',
        createdAt: DateTime.now(),
        repetitionCount: 1,
        intervalDays: 3,
      );

      final reviewed = card.calculateNextReview(ReviewRating.easy);

      expect(reviewed.repetitionCount, 2);
      expect(reviewed.intervalDays, 7);
      expect(reviewed.isMastered, true); // Interval >= 7 for easy marks mastered
    });

    test('10. SM-2 Rating Easy increases ease factor by +0.15 up to max 3.0', () {
      final card = FlashcardModel(
        id: 'c-1',
        topic: 'Geog',
        questionFront: 'Largest Ocean',
        answerBack: 'Pacific Ocean',
        createdAt: DateTime.now(),
        easeFactor: 2.9,
      );

      final reviewed = card.calculateNextReview(ReviewRating.easy);

      expect(reviewed.easeFactor, 3.0); // Clamped at 3.0
    });

    test('11. isDueForReview is true for past nextReviewAt timestamps', () {
      final card = FlashcardModel(
        id: 'c-due',
        topic: 'Test',
        questionFront: 'Q',
        answerBack: 'A',
        createdAt: DateTime.now(),
        nextReviewAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(card.isDueForReview, true);
    });

    test('12. isDueForReview is false for future nextReviewAt timestamps', () {
      final card = FlashcardModel(
        id: 'c-future',
        topic: 'Test',
        questionFront: 'Q',
        answerBack: 'A',
        createdAt: DateTime.now(),
        nextReviewAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(card.isDueForReview, false);
    });

    test('13. FlashcardModel JSON handles missing / alternate key names', () {
      final json = {
        'id': 'alt-1',
        'topic': 'Physics',
        'front': 'Question Front Text',
        'back': 'Answer Back Text',
        'is_mastered': true,
        'interval_days': 5,
        'ease_factor': 2.4,
        'repetition_count': 2,
        'next_review_at': '2026-11-01T12:00:00.000Z',
      };

      final card = FlashcardModel.fromJson(json);

      expect(card.id, 'alt-1');
      expect(card.questionFront, 'Question Front Text');
      expect(card.answerBack, 'Answer Back Text');
      expect(card.isMastered, true);
      expect(card.intervalDays, 5);
      expect(card.easeFactor, 2.4);
      expect(card.repetitionCount, 2);
      expect(card.nextReviewAt, DateTime.tryParse('2026-11-01T12:00:00.000Z'));
    });

    test('14. FlashcardModel copyWith creates exact updated instance', () {
      final card = FlashcardModel(
        id: 'cp-1',
        topic: 'Law',
        questionFront: 'Habeas Corpus',
        answerBack: 'Produce the body',
        createdAt: DateTime.now(),
        intervalDays: 2,
        easeFactor: 2.5,
      );

      final copied = card.copyWith(
        intervalDays: 10,
        isMastered: true,
      );

      expect(copied.id, 'cp-1');
      expect(copied.topic, 'Law');
      expect(copied.intervalDays, 10);
      expect(copied.isMastered, true);
      expect(copied.easeFactor, 2.5);
    });

    test('15. FlashcardDeckModel masteryPercentage returns 0.0 for empty cards', () {
      final deck = FlashcardDeckModel(
        id: 'empty-deck',
        title: 'Empty Deck',
        topic: 'None',
        cardCount: 0,
        masteredCount: 0,
        cards: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(deck.masteryPercentage, 0.0);
    });

    test('16. FlashcardDeckModel masteryPercentage clamps between 0.0 and 1.0', () {
      final deck = FlashcardDeckModel(
        id: 'deck-1',
        title: 'Deck 1',
        topic: 'Topic',
        cardCount: 4,
        masteredCount: 3,
        cards: List.generate(4, (i) => FlashcardModel(id: 'c$i', topic: 'T', questionFront: 'Q', answerBack: 'A', createdAt: DateTime.now(), isMastered: i < 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(deck.masteryPercentage, 0.75);
    });

    test('17. FlashcardDeckModel copyWith allows updating card list and mastered count', () {
      final deck = FlashcardDeckModel(
        id: 'd-1',
        title: 'Original Title',
        topic: 'Original Topic',
        cardCount: 1,
        masteredCount: 0,
        cards: [FlashcardModel(id: 'c1', topic: 'T', questionFront: 'Q', answerBack: 'A', createdAt: DateTime.now())],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = deck.copyWith(
        title: 'New Title',
        masteredCount: 1,
      );

      expect(updated.id, 'd-1');
      expect(updated.title, 'New Title');
      expect(updated.masteredCount, 1);
      expect(updated.cards.length, 1);
    });

    test('18. FlashcardDeckModel JSON serialization roundtrip', () {
      final deck = FlashcardDeckModel(
        id: 'd-json',
        title: 'Organic Mechanisms',
        topic: 'Chemistry',
        difficulty: 'hard',
        cardCount: 2,
        masteredCount: 1,
        isPinned: true,
        cards: [
          FlashcardModel(id: 'c1', topic: 'Chem', questionFront: 'SN1 Mechanism', answerBack: 'Carbocation intermediate', createdAt: DateTime(2026, 10, 1), isMastered: true),
          FlashcardModel(id: 'c2', topic: 'Chem', questionFront: 'SN2 Mechanism', answerBack: 'Pentavalent transition state', createdAt: DateTime(2026, 10, 1), isMastered: false),
        ],
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final json = deck.toJson();
      final revived = FlashcardDeckModel.fromJson(json);

      expect(revived.id, 'd-json');
      expect(revived.title, 'Organic Mechanisms');
      expect(revived.isPinned, true);
      expect(revived.cards.length, 2);
      expect(revived.cards.first.questionFront, 'SN1 Mechanism');
      expect(revived.cards.first.isMastered, true);
    });

    test('19. Interval calculation caps at maximum 365 days', () {
      final card = FlashcardModel(
        id: 'c-max',
        topic: 'Test',
        questionFront: 'Q',
        answerBack: 'A',
        createdAt: DateTime.now(),
        intervalDays: 300,
        easeFactor: 2.5,
        repetitionCount: 10,
      );

      final reviewed = card.calculateNextReview(ReviewRating.easy);

      expect(reviewed.intervalDays, 365); // Capped at 365
    });

    test('20. Multiple consecutive Good ratings scale exponentially', () {
      var card = FlashcardModel(
        id: 'c-scale',
        topic: 'Test',
        questionFront: 'Q',
        answerBack: 'A',
        createdAt: DateTime.now(),
      );

      card = card.calculateNextReview(ReviewRating.good); // 1st -> 1d
      expect(card.intervalDays, 1);

      card = card.calculateNextReview(ReviewRating.good); // 2nd -> 3d
      expect(card.intervalDays, 3);

      card = card.calculateNextReview(ReviewRating.good); // 3rd -> 8d
      expect(card.intervalDays, 8);

      card = card.calculateNextReview(ReviewRating.good); // 4th -> 20d
      expect(card.intervalDays, 20);
    });
  });
}
