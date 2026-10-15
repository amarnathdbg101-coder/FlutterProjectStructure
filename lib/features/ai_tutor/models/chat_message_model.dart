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
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
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
  };
}
