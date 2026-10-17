class ChatMessageModel {
  final String id;
  final String role; // "user" or "assistant"
  final String content;
  final String? imageUrl;
  final List<String> latexFormulas;
  final List<String> followUpQuestions;
  final List<String> keyConcepts;
  final DateTime createdAt;
  final String? sessionId;
  final String? spokenTranscript;
  final List<AiBlockModel>? blocks;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.imageUrl,
    this.latexFormulas = const [],
    this.followUpQuestions = const [],
    this.keyConcepts = const [],
    required this.createdAt,
    this.sessionId,
    this.spokenTranscript,
    this.blocks,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessageModel copyWith({
    String? id,
    String? role,
    String? content,
    String? imageUrl,
    List<String>? latexFormulas,
    List<String>? followUpQuestions,
    List<String>? keyConcepts,
    DateTime? createdAt,
    String? sessionId,
    String? spokenTranscript,
    List<AiBlockModel>? blocks,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      latexFormulas: latexFormulas ?? this.latexFormulas,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      createdAt: createdAt ?? this.createdAt,
      sessionId: sessionId ?? this.sessionId,
      spokenTranscript: spokenTranscript ?? this.spokenTranscript,
      blocks: blocks ?? this.blocks,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<AiBlockModel>? parseBlocks(dynamic raw) {
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().map(AiBlockModel.fromJson).toList();
      }
      return null;
    }

    return ChatMessageModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? (json['answer'] as String? ?? ''),
      imageUrl: json['image_url'] as String?,
      latexFormulas: parseList(json['latex_formulas']),
      followUpQuestions: parseList(json['follow_up_questions'] ?? json['follow_up_chips']),
      keyConcepts: parseList(json['key_concepts']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sessionId: json['session_id'] as String? ?? json['scope_id'] as String?,
      spokenTranscript: json['spoken_transcript'] as String?,
      blocks: parseBlocks(json['blocks']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'image_url': imageUrl,
    'latex_formulas': latexFormulas,
    'follow_up_questions': followUpQuestions,
    'key_concepts': keyConcepts,
    'created_at': createdAt.toIso8601String(),
    if (sessionId != null) 'session_id': sessionId,
    if (spokenTranscript != null) 'spoken_transcript': spokenTranscript,
    if (blocks != null) 'blocks': blocks!.map((b) => b.toJson()).toList(),
  };
}

class AiBlockModel {
  final String type;
  final String text;
  final String? extra;

  const AiBlockModel({
    required this.type,
    required this.text,
    this.extra,
  });

  factory AiBlockModel.fromJson(Map<String, dynamic> json) {
    return AiBlockModel(
      type: json['type']?.toString() ?? 'paragraph',
      text: json['text']?.toString() ?? '',
      extra: json['extra']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'text': text,
    if (extra != null) 'extra': extra,
  };
}
