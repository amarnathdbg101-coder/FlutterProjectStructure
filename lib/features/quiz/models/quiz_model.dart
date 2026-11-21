class QuizQuestionModel {
  final String id;
  final String quizId;
  final String questionType; // 'mcq' | 'subjective'
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String trapWarning;
  final String modelAnswer;
  final List<String> rubric;
  final int maxMarks;
  final String difficulty;
  final String topic;

  QuizQuestionModel({
    required this.id,
    required this.quizId,
    this.questionType = 'mcq',
    required this.questionText,
    this.options = const [],
    this.correctOptionIndex = 0,
    this.explanation = '',
    this.trapWarning = '',
    this.modelAnswer = '',
    this.rubric = const [],
    this.maxMarks = 1,
    this.difficulty = 'medium',
    this.topic = '',
  });

  bool get isSubjective => questionType.toLowerCase() == 'subjective';

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.trim().isNotEmpty) {
        return [raw.trim()];
      }
      return [];
    }

    final qText = json['question_text'] as String? ??
        json['question'] as String? ??
        json['prompt'] as String? ??
        json['problem'] as String? ??
        '';

    final opts = parseStringList(json['options'] ?? json['choices'] ?? json['answers']);

    String qType = (json['question_type'] as String? ?? '').trim().toLowerCase();
    if (qType.isEmpty) {
      qType = opts.length >= 2 ? 'mcq' : 'subjective';
    }

    int correctIdx = 0;
    if (qType == 'subjective') {
      correctIdx = -1;
    } else {
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
    }

    final mMarks = (json['max_marks'] as num?)?.toInt() ??
        (json['marks'] as num?)?.toInt() ??
        (qType == 'subjective' ? 5 : 1);

    return QuizQuestionModel(
      id: json['id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      questionType: qType,
      questionText: qText,
      options: opts,
      correctOptionIndex: correctIdx,
      explanation: json['explanation'] as String? ?? json['solution'] as String? ?? json['rationale'] as String? ?? '',
      trapWarning: json['trap_warning'] as String? ?? json['trap'] as String? ?? json['misconception'] as String? ?? '',
      modelAnswer: json['model_answer'] as String? ?? json['ideal_answer'] as String? ?? '',
      rubric: parseStringList(json['rubric']),
      maxMarks: mMarks > 0 ? mMarks : (qType == 'subjective' ? 5 : 1),
      difficulty: json['difficulty'] as String? ?? 'medium',
      topic: json['topic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quiz_id': quizId,
    'question_type': questionType,
    'question_text': questionText,
    'options': options,
    'correct_option_index': correctOptionIndex,
    'explanation': explanation,
    'trap_warning': trapWarning,
    'model_answer': modelAnswer,
    'rubric': rubric,
    'max_marks': maxMarks,
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
  final String testType; // 'mcq' | 'subjective' | 'mixed'
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
    this.testType = 'mcq',
    required this.totalQuestions,
    required this.createdAt,
    this.questions = const [],
  });

  bool get isSubjective => testType == 'subjective';
  bool get isMixed => testType == 'mixed';

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    List<QuizQuestionModel> parsedQuestions = [];
    if (rawQuestions is List) {
      parsedQuestions = rawQuestions
          .map((q) => QuizQuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();
    }

    final tType = (json['test_type'] as String? ?? 'mcq').trim().toLowerCase();

    return QuizModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      courseId: json['course_id'] as String?,
      noteId: json['note_id'] as String?,
      title: json['title'] as String? ?? 'Adaptive Quiz',
      topic: json['topic'] as String? ?? 'General',
      difficulty: json['difficulty'] as String? ?? 'adaptive',
      testType: tType.isNotEmpty ? tType : 'mcq',
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
    'test_type': testType,
    'total_questions': totalQuestions,
    'created_at': createdAt.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}

class QuestionFeedbackModel {
  final String questionId;
  final String questionType; // 'mcq' | 'subjective'
  final String questionText;
  final List<String> options;
  final int selectedOption;
  final int correctOptionIndex;
  final String studentAnswer;
  final String modelAnswer;
  final int score;
  final int maxMarks;
  final bool isCorrect;
  final String explanation;
  final String trapWarning;
  final String feedback;
  final List<String> rubric;
  final List<String> keyPointsCovered;
  final List<String> keyPointsMissed;

  QuestionFeedbackModel({
    required this.questionId,
    this.questionType = 'mcq',
    required this.questionText,
    this.options = const [],
    required this.selectedOption,
    required this.correctOptionIndex,
    this.studentAnswer = '',
    this.modelAnswer = '',
    this.score = 0,
    this.maxMarks = 1,
    required this.isCorrect,
    this.explanation = '',
    this.trapWarning = '',
    this.feedback = '',
    this.rubric = const [],
    this.keyPointsCovered = const [],
    this.keyPointsMissed = const [],
  });

  bool get isSubjective => questionType.toLowerCase() == 'subjective';
  bool get isAttempted => isSubjective ? studentAnswer.trim().isNotEmpty : selectedOption >= 0;

  factory QuestionFeedbackModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    final qType = (json['question_type'] as String? ?? 'mcq').trim().toLowerCase();

    return QuestionFeedbackModel(
      questionId: json['question_id'] as String? ?? '',
      questionType: qType,
      questionText: json['question_text'] as String? ?? json['question'] as String? ?? '',
      options: parseStringList(json['options']),
      selectedOption: (json['selected_option'] as num?)?.toInt() ?? -1,
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? 0,
      studentAnswer: json['student_answer'] as String? ?? '',
      modelAnswer: json['model_answer'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? (qType == 'subjective' ? 5 : 1),
      isCorrect: json['is_correct'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? json['solution'] as String? ?? '',
      trapWarning: json['trap_warning'] as String? ?? json['trap'] as String? ?? '',
      feedback: json['feedback'] as String? ?? '',
      rubric: parseStringList(json['rubric']),
      keyPointsCovered: parseStringList(json['key_points_covered']),
      keyPointsMissed: parseStringList(json['key_points_missed']),
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

class UserAnswerModel {
  final String questionId;
  final String questionType;
  final int selectedOption;
  final String answerText;
  final int score;
  final int maxMarks;
  final bool isCorrect;
  final String feedback;
  final List<String> keyPointsCovered;
  final List<String> keyPointsMissed;

  UserAnswerModel({
    required this.questionId,
    this.questionType = 'mcq',
    this.selectedOption = -1,
    this.answerText = '',
    this.score = 0,
    this.maxMarks = 1,
    required this.isCorrect,
    this.feedback = '',
    this.keyPointsCovered = const [],
    this.keyPointsMissed = const [],
  });

  factory UserAnswerModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return UserAnswerModel(
      questionId: json['question_id'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'mcq',
      selectedOption: (json['selected_option'] as num?)?.toInt() ?? -1,
      answerText: json['answer_text'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? 1,
      isCorrect: json['is_correct'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? '',
      keyPointsCovered: parseStringList(json['key_points_covered']),
      keyPointsMissed: parseStringList(json['key_points_missed']),
    );
  }

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'question_type': questionType,
    'selected_option': selectedOption,
    'answer_text': answerText,
    'is_correct': isCorrect,
  };
}

class QuizAttemptModel {
  final String id;
  final String quizId;
  final String userId;
  final int score;
  final int totalScore;
  final double percentage;
  final List<UserAnswerModel> answers;
  final List<String> weakAreasIdentified;
  final int timeTakenSeconds;
  final DateTime createdAt;

  QuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.score,
    required this.totalScore,
    required this.percentage,
    this.answers = const [],
    this.weakAreasIdentified = const [],
    this.timeTakenSeconds = 0,
    required this.createdAt,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    final rawAnswers = json['answers'];
    List<UserAnswerModel> parsedAnswers = [];
    if (rawAnswers is List) {
      parsedAnswers = rawAnswers
          .map((a) => UserAnswerModel.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList();
    }

    return QuizAttemptModel(
      id: json['id'] as String? ?? '',
      quizId: json['quiz_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      answers: parsedAnswers,
      weakAreasIdentified: parseList(json['weak_areas_identified']),
      timeTakenSeconds: (json['time_taken_seconds'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

