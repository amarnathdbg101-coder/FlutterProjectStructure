class QuizQuestionModel {
  final String id;
  final String quizId;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String trapWarning;
  final String difficulty;
  final String topic;

  QuizQuestionModel({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    this.explanation = '',
    this.trapWarning = '',
    this.difficulty = 'medium',
    this.topic = '',
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseOptions(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    final qText = json['question_text'] as String? ??
        json['question'] as String? ??
        json['prompt'] as String? ??
        json['problem'] as String? ??
        '';

    final opts = parseOptions(json['options'] ?? json['choices'] ?? json['answers']);

    int correctIdx = 0;
    final rawCorrect = json['correct_option_index'] ??
        json['correct_answer_index'] ??
        json['answer_index'] ??
        json['correct_index'] ??
        json['answer'];

    if (rawCorrect is num) {
      correctIdx = rawCorrect.toInt();
    } else if (rawCorrect is String) {
      final s = rawCorrect.trim().toUpperCase();
      if (s.length == 1 && s.codeUnitAt(0) >= 65 && s.codeUnitAt(0) <= 68) {
        correctIdx = s.codeUnitAt(0) - 65;
      } else {
        correctIdx = int.tryParse(s) ?? 0;
      }
    }

    if (correctIdx < 0 || (opts.isNotEmpty && correctIdx >= opts.length)) {
      correctIdx = 0;
    }

    return QuizQuestionModel(
      id: json['id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      questionText: qText,
      options: opts,
      correctOptionIndex: correctIdx,
      explanation: json['explanation'] as String? ?? json['solution'] as String? ?? json['rationale'] as String? ?? '',
      trapWarning: json['trap_warning'] as String? ?? json['trap'] as String? ?? json['misconception'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      topic: json['topic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quiz_id': quizId,
    'question_text': questionText,
    'options': options,
    'correct_option_index': correctOptionIndex,
    'explanation': explanation,
    'trap_warning': trapWarning,
    'difficulty': difficulty,
    'topic': topic,
  };
}

class QuizModel {
  final String id;
  final String userId;
  final String? courseId;
  final String? noteId;
  final String title;
  final String topic;
  final String difficulty;
  final int totalQuestions;
  final DateTime createdAt;
  final List<QuizQuestionModel> questions;

  QuizModel({
    required this.id,
    required this.userId,
    this.courseId,
    this.noteId,
    required this.title,
    required this.topic,
    this.difficulty = 'adaptive',
    required this.totalQuestions,
    required this.createdAt,
    this.questions = const [],
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    List<QuizQuestionModel> parsedQuestions = [];
    if (rawQuestions is List) {
      parsedQuestions = rawQuestions
          .map((q) => QuizQuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();
    }

    return QuizModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      courseId: json['course_id'] as String?,
      noteId: json['note_id'] as String?,
      title: json['title'] as String? ?? 'Adaptive Quiz',
      topic: json['topic'] as String? ?? 'General',
      difficulty: json['difficulty'] as String? ?? 'adaptive',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? parsedQuestions.length,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questions: parsedQuestions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'course_id': courseId,
    'note_id': noteId,
    'title': title,
    'topic': topic,
    'difficulty': difficulty,
    'total_questions': totalQuestions,
    'created_at': createdAt.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}

class QuestionFeedbackModel {
  final String questionId;
  final String questionText;
  final int selectedOption;
  final int correctOptionIndex;
  final bool isCorrect;
  final String explanation;
  final String trapWarning;

  QuestionFeedbackModel({
    required this.questionId,
    required this.questionText,
    required this.selectedOption,
    required this.correctOptionIndex,
    required this.isCorrect,
    this.explanation = '',
    this.trapWarning = '',
  });

  factory QuestionFeedbackModel.fromJson(Map<String, dynamic> json) {
    return QuestionFeedbackModel(
      questionId: json['question_id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? json['question'] as String? ?? '',
      selectedOption: (json['selected_option'] as num?)?.toInt() ?? 0,
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? 0,
      isCorrect: json['is_correct'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? json['solution'] as String? ?? '',
      trapWarning: json['trap_warning'] as String? ?? json['trap'] as String? ?? '',
    );
  }
}

class QuizSubmissionResponseModel {
  final String attemptId;
  final String quizId;
  final int score;
  final int totalScore;
  final double percentage;
  final List<QuestionFeedbackModel> feedback;
  final List<String> weakAreasIdentified;
  final int studyStreakDays;
  final int totalQuizzesTaken;
  final double averageQuizScore;

  QuizSubmissionResponseModel({
    required this.attemptId,
    required this.quizId,
    required this.score,
    required this.totalScore,
    required this.percentage,
    this.feedback = const [],
    this.weakAreasIdentified = const [],
    this.studyStreakDays = 0,
    this.totalQuizzesTaken = 0,
    this.averageQuizScore = 0.0,
  });

  factory QuizSubmissionResponseModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    final rawFeedback = json['feedback'];
    List<QuestionFeedbackModel> parsedFeedback = [];
    if (rawFeedback is List) {
      parsedFeedback = rawFeedback
          .map((f) => QuestionFeedbackModel.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    }

    return QuizSubmissionResponseModel(
      attemptId: json['attempt_id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      feedback: parsedFeedback,
      weakAreasIdentified: parseList(json['weak_areas_identified']),
      studyStreakDays: (json['study_streak_days'] as num?)?.toInt() ?? 0,
      totalQuizzesTaken: (json['total_quizzes_taken'] as num?)?.toInt() ?? 0,
      averageQuizScore: (json['average_quiz_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CognitiveProfileModel {
  final String targetExam;
  final String academicLevel;
  final List<String> weakTopics;
  final List<String> strongTopics;
  final List<String> examTraps;
  final int studyStreakDays;
  final int totalStudyMinutes;
  final int totalQuizzesTaken;
  final double averageQuizScore;

  CognitiveProfileModel({
    this.targetExam = 'Competitive / University Exam',
    this.academicLevel = 'Undergraduate',
    this.weakTopics = const [],
    this.strongTopics = const [],
    this.examTraps = const [],
    this.studyStreakDays = 1,
    this.totalStudyMinutes = 0,
    this.totalQuizzesTaken = 0,
    this.averageQuizScore = 0.0,
  });

  factory CognitiveProfileModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return CognitiveProfileModel(
      targetExam: json['target_exam'] as String? ?? 'Competitive Exam',
      academicLevel: json['academic_level'] as String? ?? 'Undergraduate',
      weakTopics: parseList(json['weak_topics']),
      strongTopics: parseList(json['strong_topics']),
      examTraps: parseList(json['exam_traps']),
      studyStreakDays: (json['study_streak_days'] as num?)?.toInt() ?? 0,
      totalStudyMinutes: (json['total_study_minutes'] as num?)?.toInt() ?? 0,
      totalQuizzesTaken: (json['total_quizzes_taken'] as num?)?.toInt() ?? 0,
      averageQuizScore: (json['average_quiz_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
