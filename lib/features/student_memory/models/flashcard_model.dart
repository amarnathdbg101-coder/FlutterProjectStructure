/// Model for an individual Anki-style active recall flashcard
class FlashcardModel {
  final String id;
  final String topic;
  final String questionFront;
  final String answerBack;
  final String difficulty; // 'easy', 'medium', 'hard', 'good'
  final bool isMastered;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime? lastReviewedAt;

  const FlashcardModel({
    required this.id,
    required this.topic,
    required this.questionFront,
    required this.answerBack,
    this.difficulty = 'medium',
    this.isMastered = false,
    this.isReviewed = false,
    required this.createdAt,
    this.lastReviewedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'front': questionFront,
      'back': answerBack,
      'questionFront': questionFront,
      'answerBack': answerBack,
      'difficulty': difficulty,
      'is_mastered': isMastered,
      'is_reviewed': isReviewed,
      'createdAt': createdAt.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      topic: json['topic']?.toString() ?? 'General Academic',
      questionFront: json['front']?.toString() ?? json['questionFront'] ?? json['question'] ?? '',
      answerBack: json['back']?.toString() ?? json['answerBack'] ?? json['answer'] ?? '',
      difficulty: json['difficulty']?.toString() ?? 'medium',
      isMastered: json['is_mastered'] == true || json['isMastered'] == true,
      isReviewed: json['is_reviewed'] == true || json['isReviewed'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.tryParse(json['lastReviewedAt'].toString())
          : (json['last_reviewed_at'] != null ? DateTime.tryParse(json['last_reviewed_at'].toString()) : null),
    );
  }

  FlashcardModel copyWith({
    String? difficulty,
    bool? isMastered,
    bool? isReviewed,
    DateTime? lastReviewedAt,
  }) {
    return FlashcardModel(
      id: id,
      topic: topic,
      questionFront: questionFront,
      answerBack: answerBack,
      difficulty: difficulty ?? this.difficulty,
      isMastered: isMastered ?? this.isMastered,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

/// Comprehensive Model for a Flashcard Deck saved in PostgreSQL / Hive
class FlashcardDeckModel {
  final String id;
  final String title;
  final String topic;
  final String difficulty;
  final int cardCount;
  final int masteredCount;
  final bool isPinned;
  final List<FlashcardModel> cards;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlashcardDeckModel({
    required this.id,
    required this.title,
    required this.topic,
    this.difficulty = 'medium',
    required this.cardCount,
    this.masteredCount = 0,
    this.isPinned = false,
    required this.cards,
    required this.createdAt,
    required this.updatedAt,
  });

  double get masteryPercentage {
    if (cards.isEmpty) return 0.0;
    return (masteredCount / cards.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'difficulty': difficulty,
      'card_count': cardCount,
      'mastered_count': masteredCount,
      'is_pinned': isPinned,
      'cards': cards.map((c) => c.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FlashcardDeckModel.fromJson(Map<String, dynamic> json) {
    List<FlashcardModel> loadedCards = [];
    if (json['cards'] is List) {
      loadedCards = (json['cards'] as List)
          .map((item) => FlashcardModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final total = (json['card_count'] as num?)?.toInt() ?? (loadedCards.isNotEmpty ? loadedCards.length : 0);
    final mastered = (json['mastered_count'] as num?)?.toInt() ??
        loadedCards.where((c) => c.isMastered).length;

    return FlashcardDeckModel(
      id: json['id']?.toString() ?? 'deck-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Active Recall Deck',
      topic: json['topic']?.toString() ?? 'General Topic',
      difficulty: json['difficulty']?.toString() ?? 'medium',
      cardCount: total,
      masteredCount: mastered,
      isPinned: json['is_pinned'] == true,
      cards: loadedCards,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  FlashcardDeckModel copyWith({
    String? title,
    String? topic,
    String? difficulty,
    int? cardCount,
    int? masteredCount,
    bool? isPinned,
    List<FlashcardModel>? cards,
    DateTime? updatedAt,
  }) {
    return FlashcardDeckModel(
      id: id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      cardCount: cardCount ?? this.cardCount,
      masteredCount: masteredCount ?? this.masteredCount,
      isPinned: isPinned ?? this.isPinned,
      cards: cards ?? this.cards,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
