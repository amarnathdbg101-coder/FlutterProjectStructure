import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';
import 'flashcard_service.dart';

class DueCardWithDeck {
  final FlashcardDeckModel deck;
  final FlashcardModel card;

  const DueCardWithDeck({
    required this.deck,
    required this.card,
  });
}

/// SpacedRepetitionService - Manages the Daily Active Recall Queue & SM-2 Review Submissions
class SpacedRepetitionService extends ChangeNotifier {
  static final SpacedRepetitionService _instance = SpacedRepetitionService._internal();
  factory SpacedRepetitionService() => _instance;
  SpacedRepetitionService._internal();

  final FlashcardService _flashcardService = FlashcardService();

  int _reviewedToday = 0;
  DateTime _lastResetDate = DateTime.now();

  int get reviewedTodayCount {
    _checkDailyReset();
    return _reviewedToday;
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    if (now.year != _lastResetDate.year ||
        now.month != _lastResetDate.month ||
        now.day != _lastResetDate.day) {
      _reviewedToday = 0;
      _lastResetDate = now;
    }
  }

  /// Fetches all cards due for review today across all user decks
  Future<List<DueCardWithDeck>> getDueReviewCards() async {
    _checkDailyReset();
    try {
      final decks = await _flashcardService.listDecks();
      final dueItems = <DueCardWithDeck>[];

      for (final deck in decks) {
        for (final card in deck.cards) {
          if (card.isDueForReview) {
            dueItems.add(DueCardWithDeck(deck: deck, card: card));
          }
        }
      }

      return dueItems;
    } catch (_) {
      return [];
    }
  }

  /// Submits an SM-2 rating review for a specific card within a deck
  Future<FlashcardModel> submitReview({
    required FlashcardDeckModel deck,
    required FlashcardModel card,
    required ReviewRating rating,
  }) async {
    final updatedCard = card.calculateNextReview(rating);

    final updatedCards = deck.cards.map((c) {
      return c.id == card.id ? updatedCard : c;
    }).toList();

    final masteredCount = updatedCards.where((c) => c.isMastered).length;

    final updatedDeck = deck.copyWith(
      cards: updatedCards,
      masteredCount: masteredCount,
      updatedAt: DateTime.now(),
    );

    await _flashcardService.updateDeckProgress(updatedDeck);

    _reviewedToday++;
    notifyListeners();

    return updatedCard;
  }
}
