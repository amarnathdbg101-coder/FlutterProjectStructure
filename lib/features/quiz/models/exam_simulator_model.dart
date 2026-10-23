enum ErrorCategory { conceptual, trap, calculation, none }

class MockExamQuestionModel {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String trapWarning;
  final String topic;
  final ErrorCategory errorCategory;
  final double positiveMarks;
  final double negativeMarks;

  MockExamQuestionModel({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    this.explanation = '',
    this.trapWarning = '',
    this.topic = 'General Academic',
    this.errorCategory = ErrorCategory.conceptual,
    this.positiveMarks = 4.0,
    this.negativeMarks = 1.0,
  });

  factory MockExamQuestionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseOptions(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    int correctIdx = 0;
    final rawCorrect = json['correct_option_index'] ?? json['correct_index'] ?? json['answer'];
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

    ErrorCategory cat = ErrorCategory.conceptual;
    final catStr = json['error_category']?.toString().toLowerCase() ?? '';
    if (catStr.contains('trap')) {
      cat = ErrorCategory.trap;
    } else if (catStr.contains('calc') || catStr.contains('math')) {
      cat = ErrorCategory.calculation;
    }

    return MockExamQuestionModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      questionText: json['question_text']?.toString() ?? json['question'] ?? '',
      options: parseOptions(json['options'] ?? json['choices']),
      correctOptionIndex: correctIdx,
      explanation: json['explanation']?.toString() ?? json['solution'] ?? '',
      trapWarning: json['trap_warning']?.toString() ?? json['trap'] ?? '',
      topic: json['topic']?.toString() ?? 'General Topic',
      errorCategory: cat,
      positiveMarks: (json['positive_marks'] as num?)?.toDouble() ?? 4.0,
      negativeMarks: (json['negative_marks'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_text': questionText,
        'options': options,
        'correct_option_index': correctOptionIndex,
        'explanation': explanation,
        'trap_warning': trapWarning,
        'topic': topic,
        'error_category': errorCategory.name,
        'positive_marks': positiveMarks,
        'negative_marks': negativeMarks,
      };
}

class MockExamModel {
  final String id;
  final String title;
  final String examType; // 'JEE Main', 'NEET UG', 'GATE CS', 'University Midterm'
  final int durationMinutes;
  final double positiveMarking;
  final double negativeMarking;
  final int totalQuestions;
  final DateTime createdAt;
  final List<MockExamQuestionModel> questions;

  MockExamModel({
    required this.id,
    required this.title,
    this.examType = 'JEE Main',
    this.durationMinutes = 15,
    this.positiveMarking = 4.0,
    this.negativeMarking = 1.0,
    required this.totalQuestions,
    required this.createdAt,
    required this.questions,
  });

  factory MockExamModel.fromJson(Map<String, dynamic> json) {
    List<MockExamQuestionModel> parsed = [];
    if (json['questions'] is List) {
      parsed = (json['questions'] as List)
          .map((q) => MockExamQuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();
    }

    return MockExamModel(
      id: json['id']?.toString() ?? 'exam-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'AI Exam Simulator',
      examType: json['exam_type']?.toString() ?? 'JEE Main',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 15,
      positiveMarking: (json['positive_marking'] as num?)?.toDouble() ?? 4.0,
      negativeMarking: (json['negative_marking'] as num?)?.toDouble() ?? 1.0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? parsed.length,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questions: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'exam_type': examType,
        'duration_minutes': durationMinutes,
        'positive_marking': positiveMarking,
        'negative_marking': negativeMarking,
        'total_questions': totalQuestions,
        'created_at': createdAt.toIso8601String(),
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class QuestionDiagnosticFeedback {
  final MockExamQuestionModel question;
  final int selectedOption;
  final bool isCorrect;
  final bool isSkipped;
  final double marksAwarded;

  QuestionDiagnosticFeedback({
    required this.question,
    required this.selectedOption,
    required this.isCorrect,
    required this.isSkipped,
    required this.marksAwarded,
  });
}

class ExamDiagnosticReportModel {
  final String attemptId;
  final String examId;
  final String examTitle;
  final String examType;
  final double totalScore;
  final double maxPossibleScore;
  final double accuracyPercentage;
  final int timeTakenSeconds;
  final double averageSecondsPerQuestion;
  final int correctCount;
  final int incorrectCount;
  final int skippedCount;

  // Diagnostic Error Categories
  final int conceptualErrorCount;
  final int examinerTrapCount;
  final int calculationErrorCount;

  final List<String> weakTopics;
  final List<QuestionDiagnosticFeedback> feedbackList;

  ExamDiagnosticReportModel({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.examType,
    required this.totalScore,
    required this.maxPossibleScore,
    required this.accuracyPercentage,
    required this.timeTakenSeconds,
    required this.averageSecondsPerQuestion,
    required this.correctCount,
    required this.incorrectCount,
    required this.skippedCount,
    required this.conceptualErrorCount,
    required this.examinerTrapCount,
    required this.calculationErrorCount,
    required this.weakTopics,
    required this.feedbackList,
  });
}
