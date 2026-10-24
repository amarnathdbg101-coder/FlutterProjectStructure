/// Student Cognitive Memory Profile representing personalized target exams,
/// academic levels, strengths, weak areas, topic mastery, and cognitive readiness score.
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

  // Real Cognitive Brain & Mastery Fields
  final String aiSummary;
  final Map<String, int> topicMastery;
  final int rawReadinessScore;
  final List<String> recommendedActions;
  final int totalDoubtsAsked;
  final int studyStreakDays;
  final int totalStudyMinutes;
  final int totalQuizzesTaken;
  final double averageQuizScore;

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
    this.aiSummary = '',
    this.topicMastery = const {},
    this.rawReadinessScore = 0,
    this.recommendedActions = const [],
    this.totalDoubtsAsked = 0,
    this.studyStreakDays = 1,
    this.totalStudyMinutes = 0,
    this.totalQuizzesTaken = 0,
    this.averageQuizScore = 0.0,
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
      aiSummary: 'Cognitive brain active. Practice topics and take quizzes to unlock deep AI diagnostic insights.',
      topicMastery: const {},
      rawReadinessScore: 50,
      recommendedActions: const [
        'Ask your first doubt to the AI Tutor',
        'Take an adaptive quiz on core topics',
        'Explore dynamic mind maps',
      ],
      totalDoubtsAsked: 0,
      studyStreakDays: 1,
      totalStudyMinutes: 0,
      totalQuizzesTaken: 0,
      averageQuizScore: 0.0,
      lastActiveAt: now,
      updatedAt: now,
    );
  }

  /// Factory constructor to parse from JSON map
  factory StudentMemoryProfile.fromJson(Map<String, dynamic> json) {
    // Parse topic mastery map
    Map<String, int> mastery = {};
    if (json['topic_mastery'] != null && json['topic_mastery'] is Map) {
      (json['topic_mastery'] as Map).forEach((k, v) {
        mastery[k.toString()] = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 50;
      });
    }

    final weakList = (json['weak_topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (json['weakTopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final strongList = (json['strong_topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (json['strongTopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final trapsList = (json['exam_traps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (json['examTrapsEncountered'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final actionsList = (json['recommended_actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final totalDoubts = (json['total_doubts_asked'] is num) ? (json['total_doubts_asked'] as num).toInt() : 0;
    final totalQuizzes = (json['total_quizzes_taken'] is num) ? (json['total_quizzes_taken'] as num).toInt() : 0;

    const legacyMockTopics = {
      'core theory & mechanics',
      'formula derivations',
      'examiner traps & pyqs',
    };

    final filteredWeak = weakList.where((w) {
      final lower = w.trim().toLowerCase();
      if (legacyMockTopics.contains(lower)) return false;
      if (totalDoubts == 0 && totalQuizzes == 0) {
        if (lower == 'data structures' || lower == 'dynamic programming') return false;
      }
      return true;
    }).toList();

    final filteredStrong = strongList.where((s) {
      final lower = s.trim().toLowerCase();
      if (legacyMockTopics.contains(lower)) return false;
      if (totalDoubts == 0 && totalQuizzes == 0) {
        if (lower == 'object-oriented programming') return false;
      }
      return true;
    }).toList();

    final filteredTraps = trapsList.where((trap) {
      final lower = trap.trim().toLowerCase();
      if (totalDoubts == 0 && totalQuizzes == 0) {
        if (lower.contains('off-by-one') || lower.contains('time complexity underestimation')) return false;
      }
      return true;
    }).toList();

    mastery.removeWhere((k, _) {
      final lower = k.trim().toLowerCase();
      if (legacyMockTopics.contains(lower)) return true;
      if (totalDoubts == 0 && totalQuizzes == 0) {
        if (lower == 'data structures' || lower == 'dynamic programming' || lower == 'object-oriented programming') {
          return true;
        }
      }
      return false;
    });

    var targetExamStr = (json['target_exam'] ?? json['targetExam'] ?? 'General Academic Preparation').toString();
    targetExamStr = targetExamStr
        .replaceAll(RegExp(r'\s*&\s*explain point through not paragraph', caseSensitive: false), '')
        .replaceAll(RegExp(r'explain point through not paragraph', caseSensitive: false), '')
        .replaceAll(RegExp(r'point by point answer dena', caseSensitive: false), '')
        .trim();
    if (targetExamStr.isEmpty) {
      targetExamStr = 'General Academic Preparation';
    }

    var academicLevelStr = (json['academic_level'] ?? json['academicLevel'] ?? 'College & Competitive Exams').toString();
    academicLevelStr = academicLevelStr
        .replaceAll(RegExp(r'point by point answer dena', caseSensitive: false), '')
        .replaceAll(RegExp(r'explain point through not paragraph', caseSensitive: false), '')
        .trim();
    if (academicLevelStr.isEmpty) {
      academicLevelStr = 'College & Competitive Exams';
    }

    return StudentMemoryProfile(
      userId: (json['user_id'] ?? json['userId'] ?? 'local_scholar').toString(),
      targetExam: targetExamStr,
      academicLevel: academicLevelStr,
      strongTopics: filteredStrong,
      weakTopics: filteredWeak,
      examTrapsEncountered: filteredTraps,
      preferredPersona: (json['preferred_persona'] ?? json['preferredPersona'] ?? 'Professor').toString(),
      cumulativeMemorySummary: (json['memory_summary'] ?? json['cumulativeMemorySummary'] ?? '').toString(),
      totalInteractions: (json['total_interactions'] ?? json['totalInteractions'] ?? 0) as int,
      flashcardsMastered: (json['flashcards_mastered'] ?? json['flashcardsMastered'] ?? 0) as int,
      flashcardsAttempted: (json['flashcards_attempted'] ?? json['flashcardsAttempted'] ?? 0) as int,
      aiSummary: (json['ai_summary'] ?? '').toString(),
      topicMastery: mastery,
      rawReadinessScore: (json['readiness_score'] is num) ? (json['readiness_score'] as num).toInt() : 0,
      recommendedActions: actionsList,
      totalDoubtsAsked: (json['total_doubts_asked'] is num) ? (json['total_doubts_asked'] as num).toInt() : 0,
      studyStreakDays: (json['study_streak_days'] is num) ? (json['study_streak_days'] as num).toInt() : 1,
      totalStudyMinutes: (json['total_study_minutes'] is num) ? (json['total_study_minutes'] as num).toInt() : 0,
      totalQuizzesTaken: (json['total_quizzes_taken'] is num) ? (json['total_quizzes_taken'] as num).toInt() : 0,
      averageQuizScore: (json['average_quiz_score'] is num) ? (json['average_quiz_score'] as num).toDouble() : 0.0,
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
      'ai_summary': aiSummary,
      'topic_mastery': topicMastery,
      'readiness_score': rawReadinessScore,
      'recommended_actions': recommendedActions,
      'total_doubts_asked': totalDoubtsAsked,
      'study_streak_days': studyStreakDays,
      'total_study_minutes': totalStudyMinutes,
      'total_quizzes_taken': totalQuizzesTaken,
      'average_quiz_score': averageQuizScore,
      'last_active_at': lastActiveAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Compute overall Exam Readiness Score percentage (0 - 100%)
  int get readinessScore {
    if (rawReadinessScore > 0) {
      return rawReadinessScore.clamp(0, 100);
    }
    if (totalQuizzesTaken == 0 && strongTopics.isEmpty && weakTopics.isEmpty) {
      return 55; // Clean baseline
    }

    double quizPart = totalQuizzesTaken > 0 ? (averageQuizScore * 0.6) : 30.0;
    final totalTopics = strongTopics.length + weakTopics.length;
    double topicPart = totalTopics > 0 ? (strongTopics.length / totalTopics) * 40.0 : 25.0;

    return (quizPart + topicPart).clamp(0.0, 100.0).round();
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
    if (aiSummary.isNotEmpty) {
      sb.writeln('• AI Pedagogical Diagnosis: $aiSummary');
    }
    sb.writeln('• Readiness Score: $readinessScore% | Streak: $studyStreakDays days');
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
    String? aiSummary,
    Map<String, int>? topicMastery,
    int? rawReadinessScore,
    List<String>? recommendedActions,
    int? totalDoubtsAsked,
    int? studyStreakDays,
    int? totalStudyMinutes,
    int? totalQuizzesTaken,
    double? averageQuizScore,
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
      aiSummary: aiSummary ?? this.aiSummary,
      topicMastery: topicMastery ?? this.topicMastery,
      rawReadinessScore: rawReadinessScore ?? this.rawReadinessScore,
      recommendedActions: recommendedActions ?? this.recommendedActions,
      totalDoubtsAsked: totalDoubtsAsked ?? this.totalDoubtsAsked,
      studyStreakDays: studyStreakDays ?? this.studyStreakDays,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
      totalQuizzesTaken: totalQuizzesTaken ?? this.totalQuizzesTaken,
      averageQuizScore: averageQuizScore ?? this.averageQuizScore,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
