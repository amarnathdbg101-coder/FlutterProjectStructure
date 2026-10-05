/// Student Cognitive Memory Profile representing personalized target exams,
/// academic levels, strengths, weak areas, and cognitive readiness score.
class StudentMemoryProfile {
  final String userId;
  final String targetExam;
  final String academicLevel;
  final List<String> strongTopics;
  final List<String> weakTopics;
  final List<String> examTrapsEncountered;
  final String preferredPersona;
  final String cumulativeMemorySummary;
  final int totalInteractions;
  final int flashcardsMastered;
  final int flashcardsAttempted;
  final DateTime lastActiveAt;
  final DateTime updatedAt;

  const StudentMemoryProfile({
    required this.userId,
    this.targetExam = 'Academic Studies & General Exams',
    this.academicLevel = 'School / College (Adaptive)',
    this.strongTopics = const [],
    this.weakTopics = const [],
    this.examTrapsEncountered = const [],
    this.preferredPersona = 'Professor',
    this.cumulativeMemorySummary = '',
    this.totalInteractions = 0,
    this.flashcardsMastered = 0,
    this.flashcardsAttempted = 0,
    required this.lastActiveAt,
    required this.updatedAt,
  });

  /// Factory for a fresh, default student profile
  factory StudentMemoryProfile.defaultProfile({String userId = 'local_scholar'}) {
    final now = DateTime.now();
    return StudentMemoryProfile(
      userId: userId,
      targetExam: 'General Academic Preparation',
      academicLevel: 'School / College (Adaptive)',
      strongTopics: const [],
      weakTopics: const [],
      examTrapsEncountered: const [],
      preferredPersona: 'Professor',
      cumulativeMemorySummary:
          'Student is actively building subject mastery. Values step-by-step conceptual clarity and grade-appropriate depth.',
      totalInteractions: 0,
      flashcardsMastered: 0,
      flashcardsAttempted: 0,
      lastActiveAt: now,
      updatedAt: now,
    );
  }

  /// Factory constructor to parse from JSON map
  factory StudentMemoryProfile.fromJson(Map<String, dynamic> json) {
    return StudentMemoryProfile(
      userId: (json['user_id'] ?? json['userId'] ?? 'local_scholar').toString(),
      targetExam: (json['target_exam'] ?? json['targetExam'] ?? 'General Academic Preparation').toString(),
      academicLevel: (json['academic_level'] ?? json['academicLevel'] ?? 'College & Competitive Exams').toString(),
      strongTopics: (json['strong_topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['strongTopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      weakTopics: (json['weak_topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['weakTopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      examTrapsEncountered: (json['exam_traps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['examTrapsEncountered'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      preferredPersona: (json['preferred_persona'] ?? json['preferredPersona'] ?? 'Professor').toString(),
      cumulativeMemorySummary: (json['memory_summary'] ?? json['cumulativeMemorySummary'] ?? '').toString(),
      totalInteractions: (json['total_interactions'] ?? json['totalInteractions'] ?? 0) as int,
      flashcardsMastered: (json['flashcards_mastered'] ?? json['flashcardsMastered'] ?? 0) as int,
      flashcardsAttempted: (json['flashcards_attempted'] ?? json['flashcardsAttempted'] ?? 0) as int,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString()) ?? DateTime.now()
          : (json['lastActiveAt'] != null
              ? DateTime.tryParse(json['lastActiveAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'target_exam': targetExam,
      'academic_level': academicLevel,
      'strong_topics': strongTopics,
      'weak_topics': weakTopics,
      'exam_traps': examTrapsEncountered,
      'preferred_persona': preferredPersona,
      'memory_summary': cumulativeMemorySummary,
      'total_interactions': totalInteractions,
      'flashcards_mastered': flashcardsMastered,
      'flashcards_attempted': flashcardsAttempted,
      'last_active_at': lastActiveAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Compute overall Exam Readiness Score percentage (0 - 100%)
  int get readinessScore {
    if (flashcardsAttempted == 0 && strongTopics.isEmpty && weakTopics.isEmpty) {
      return 60; // Baseline
    }

    double cardScore = flashcardsAttempted > 0
        ? (flashcardsMastered / flashcardsAttempted) * 50.0
        : 25.0;

    final totalTopics = strongTopics.length + weakTopics.length;
    double topicScore = totalTopics > 0
        ? (strongTopics.length / totalTopics) * 50.0
        : 25.0;

    return (cardScore + topicScore).clamp(0.0, 100.0).round();
  }

  bool get hasWeaknesses => weakTopics.isNotEmpty;
  bool get hasStrengths => strongTopics.isNotEmpty;

  /// Formatted compact representation for AI prompt context
  String get formattedAiContext {
    final sb = StringBuffer();
    sb.writeln('[STUDENT COGNITIVE PROFILE & ACADEMIC MEMORY]');
    sb.writeln('• Target Exam / Goal: $targetExam');
    sb.writeln('• Academic Grade / Level: $academicLevel');
    if (strongTopics.isNotEmpty) {
      sb.writeln('• Strengths & Mastered Concepts: ${strongTopics.join(", ")}');
    }
    if (weakTopics.isNotEmpty) {
      sb.writeln('• Known Weak Areas to Reinforce: ${weakTopics.join(", ")}');
    }
    if (examTrapsEncountered.isNotEmpty) {
      sb.writeln('• Previous Exam Traps Encountered: ${examTrapsEncountered.join(", ")}');
    }
    if (cumulativeMemorySummary.isNotEmpty) {
      sb.writeln('• AI Pedagogical Memory: $cumulativeMemorySummary');
    }
    sb.writeln('• STRICT EXAM DIRECTIVE: Calibrate explanation depth, mathematical formulas, and vocabulary STRICTLY to match "$targetExam" ($academicLevel).');
    return sb.toString();
  }

  StudentMemoryProfile copyWith({
    String? userId,
    String? targetExam,
    String? academicLevel,
    List<String>? strongTopics,
    List<String>? weakTopics,
    List<String>? examTrapsEncountered,
    String? preferredPersona,
    String? cumulativeMemorySummary,
    int? totalInteractions,
    int? flashcardsMastered,
    int? flashcardsAttempted,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
  }) {
    return StudentMemoryProfile(
      userId: userId ?? this.userId,
      targetExam: targetExam ?? this.targetExam,
      academicLevel: academicLevel ?? this.academicLevel,
      strongTopics: strongTopics ?? this.strongTopics,
      weakTopics: weakTopics ?? this.weakTopics,
      examTrapsEncountered: examTrapsEncountered ?? this.examTrapsEncountered,
      preferredPersona: preferredPersona ?? this.preferredPersona,
      cumulativeMemorySummary: cumulativeMemorySummary ?? this.cumulativeMemorySummary,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      flashcardsMastered: flashcardsMastered ?? this.flashcardsMastered,
      flashcardsAttempted: flashcardsAttempted ?? this.flashcardsAttempted,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
