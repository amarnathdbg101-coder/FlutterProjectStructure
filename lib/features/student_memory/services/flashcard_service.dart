import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/flashcard_model.dart';

/// Full-featured Flashcard Service with Remote PostgreSQL Sync & Local Offline Caching
class FlashcardService {
  static final FlashcardService _instance = FlashcardService._internal();
  factory FlashcardService() => _instance;
  FlashcardService._internal();

  final ApiClient _apiClient = ApiClient();
  static const String _localDecksKey = 'study_silo_saved_flashcard_decks_v1';

  /// Generates a flexible active recall flashcard deck from topic / custom content
  Future<FlashcardDeckModel> generateDeck({
    required String topic,
    String? content,
    int cardCount = 5,
    String difficulty = 'medium',
    bool saveDeck = true,
  }) async {
    final cleanTopic = topic.trim().isEmpty ? 'General Academic Concepts' : topic.trim();

    try {
      final response = await _apiClient.dio.post(
        ApiConstants.flashcardsGenerate,
        data: {
          'topic': cleanTopic,
          'content': content ?? '',
          'card_count': cardCount,
          'difficulty': difficulty,
          'save_deck': saveDeck,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final deck = FlashcardDeckModel(
            id: data['deck_id']?.toString() ?? 'deck-${DateTime.now().millisecondsSinceEpoch}',
            title: data['title']?.toString() ?? '$cleanTopic Active Recall Deck',
            topic: data['topic']?.toString() ?? cleanTopic,
            difficulty: data['difficulty']?.toString() ?? difficulty,
            cardCount: (data['total_cards'] as num?)?.toInt() ?? cardCount,
            masteredCount: (data['mastered_count'] as num?)?.toInt() ?? 0,
            isPinned: false,
            cards: (data['cards'] as List<dynamic>?)
                    ?.map((e) => FlashcardModel.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _cacheDeckLocally(deck);
          return deck;
        }
      }
      throw Exception('Server returned an empty deck response');
    } catch (e) {
      throw Exception('Failed to generate flashcards: ${e.toString().replaceAll('Exception:', '').trim()}');
    }
  }

  /// Lists all saved flashcard decks from PostgreSQL (with local cache fallback)
  Future<List<FlashcardDeckModel>> listDecks({String? search}) async {
    List<FlashcardDeckModel> remoteDecks = [];

    try {
      final response = await _apiClient.dio.get(
        ApiConstants.flashcardDecks,
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null && data['items'] is List) {
          final items = data['items'] as List;
          remoteDecks = items.map((e) => FlashcardDeckModel.fromJson(e as Map<String, dynamic>)).toList();
          await _saveAllDecksLocally(remoteDecks);
          return remoteDecks;
        }
      }
    } catch (_) {}

    // Fallback to local cache
    final localDecks = await _loadLocalDecks();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return localDecks.where((d) => d.title.toLowerCase().contains(q) || d.topic.toLowerCase().contains(q)).toList();
    }
    return localDecks;
  }

  /// Retrieves a specific deck by ID
  Future<FlashcardDeckModel?> getDeck(String id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.flashcardDecks}/$id');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final deck = FlashcardDeckModel.fromJson(data);
          await _cacheDeckLocally(deck);
          return deck;
        }
      }
    } catch (_) {}

    // Check local cache
    final local = await _loadLocalDecks();
    try {
      return local.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Updates card review progress, difficulty and mastered count on backend and local cache
  Future<void> updateDeckProgress(FlashcardDeckModel deck) async {
    await _cacheDeckLocally(deck);

    try {
      await _apiClient.dio.put(
        '${ApiConstants.flashcardDecks}/${deck.id}',
        data: {
          'title': deck.title,
          'cards': deck.cards.map((c) => c.toJson()).toList(),
          'mastered_count': deck.masteredCount,
          'is_pinned': deck.isPinned,
        },
      );
    } catch (_) {}
  }

  /// Deletes a flashcard deck from backend and local cache
  Future<void> deleteDeck(String id) async {
    await _removeDeckLocally(id);

    try {
      await _apiClient.dio.delete('${ApiConstants.flashcardDecks}/$id');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Local Caching Helpers
  // ---------------------------------------------------------------------------
  Future<List<FlashcardDeckModel>> _loadLocalDecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localDecksKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => FlashcardDeckModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveAllDecksLocally(List<FlashcardDeckModel> decks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(decks.map((d) => d.toJson()).toList());
      await prefs.setString(_localDecksKey, raw);
    } catch (_) {}
  }

  Future<void> _cacheDeckLocally(FlashcardDeckModel deck) async {
    final list = await _loadLocalDecks();
    final idx = list.indexWhere((d) => d.id == deck.id);
    if (idx != -1) {
      list[idx] = deck;
    } else {
      list.insert(0, deck);
    }
    await _saveAllDecksLocally(list);
  }

  Future<void> _removeDeckLocally(String id) async {
    final list = await _loadLocalDecks();
    list.removeWhere((d) => d.id == id);
    await _saveAllDecksLocally(list);
  }
}
