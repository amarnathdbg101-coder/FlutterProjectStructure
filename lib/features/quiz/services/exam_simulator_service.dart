import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/exam_simulator_model.dart';

class ExamSimulatorService {
  static final ExamSimulatorService _instance = ExamSimulatorService._internal();
  factory ExamSimulatorService() => _instance;
  ExamSimulatorService._internal();

  final Dio _dio = ApiClient().dio;

  /// Generates a structured AI Mock Exam tailored to target exam conditions
  Future<MockExamModel> generateMockExam({
    required String topic,
    String examType = 'JEE Main',
    int durationMinutes = 15,
    int questionCount = 5,
    double positiveMarking = 4.0,
    double negativeMarking = 1.0,
  }) async {
    final cleanTopic = topic.trim().isEmpty ? 'Core Physics & Mathematics' : topic.trim();

    try {
      final response = await _dio.post(
        ApiConstants.generateQuiz,
        data: {
          'topic': cleanTopic,
          'difficulty': 'adaptive',
          'question_count': questionCount,
          'exam_type': examType,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        final rawQuestions = data['questions'] as List<dynamic>? ?? [];

        final questions = rawQuestions.map((q) {
          final map = Map<String, dynamic>.from(q as Map);
          map['positive_marks'] = positiveMarking;
          map['negative_marks'] = negativeMarking;
          return MockExamQuestionModel.fromJson(map);
        }).toList();

        if (questions.isNotEmpty) {
          return MockExamModel(
            id: 'exam-${DateTime.now().millisecondsSinceEpoch}',
            title: '$cleanTopic $examType Mock',
            examType: examType,
            durationMinutes: durationMinutes,
            positiveMarking: positiveMarking,
            negativeMarking: negativeMarking,
            totalQuestions: questions.length,
            createdAt: DateTime.now(),
            questions: questions,
          );
        }
      }
      throw Exception('Server returned an empty exam structure');
    } catch (e) {
      throw Exception('Failed to generate AI Mock Exam: ${e.toString().replaceAll('Exception:', '').trim()}');
    }
  }

  /// Evaluates student exam attempt, applies negative marking, and runs AI Diagnostic Forensic Analysis
  ExamDiagnosticReportModel evaluateDiagnosticReport({
    required MockExamModel exam,
    required Map<int, int> userAnswers, // questionIndex -> selectedOptionIndex (-1 if skipped)
    required int timeTakenSeconds,
  }) {
    double totalScore = 0.0;
    double maxPossibleScore = exam.questions.length * exam.positiveMarking;
    int correctCount = 0;
    int incorrectCount = 0;
    int skippedCount = 0;

    int conceptualErrorCount = 0;
    int examinerTrapCount = 0;
    int calculationErrorCount = 0;

    final weakTopics = <String>{};
    final feedbackList = <QuestionDiagnosticFeedback>[];

    for (int i = 0; i < exam.questions.length; i++) {
      final q = exam.questions[i];
      final selected = userAnswers[i] ?? -1;

      if (selected == -1) {
        skippedCount++;
        if (q.topic.isNotEmpty) weakTopics.add(q.topic);
        feedbackList.add(
          QuestionDiagnosticFeedback(
            question: q,
            selectedOption: -1,
            isCorrect: false,
            isSkipped: true,
            marksAwarded: 0.0,
          ),
        );
      } else if (selected == q.correctOptionIndex) {
        correctCount++;
        totalScore += q.positiveMarks;
        feedbackList.add(
          QuestionDiagnosticFeedback(
            question: q,
            selectedOption: selected,
            isCorrect: true,
            isSkipped: false,
            marksAwarded: q.positiveMarks,
          ),
        );
      } else {
        incorrectCount++;
        totalScore -= q.negativeMarks;
        if (q.topic.isNotEmpty) weakTopics.add(q.topic);

        switch (q.errorCategory) {
          case ErrorCategory.conceptual:
            conceptualErrorCount++;
            break;
          case ErrorCategory.trap:
            examinerTrapCount++;
            break;
          case ErrorCategory.calculation:
            calculationErrorCount++;
            break;
          default:
            conceptualErrorCount++;
        }

        feedbackList.add(
          QuestionDiagnosticFeedback(
            question: q,
            selectedOption: selected,
            isCorrect: false,
            isSkipped: false,
            marksAwarded: -q.negativeMarks,
          ),
        );
      }
    }

    final accuracy = exam.questions.isNotEmpty
        ? (correctCount / exam.questions.length) * 100.0
        : 0.0;
    final avgSeconds = exam.questions.isNotEmpty
        ? (timeTakenSeconds / exam.questions.length)
        : 0.0;

    return ExamDiagnosticReportModel(
      attemptId: 'report-${DateTime.now().millisecondsSinceEpoch}',
      examId: exam.id,
      examTitle: exam.title,
      examType: exam.examType,
      totalScore: totalScore.clamp(0.0, maxPossibleScore),
      maxPossibleScore: maxPossibleScore,
      accuracyPercentage: accuracy,
      timeTakenSeconds: timeTakenSeconds,
      averageSecondsPerQuestion: avgSeconds,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      skippedCount: skippedCount,
      conceptualErrorCount: conceptualErrorCount,
      examinerTrapCount: examinerTrapCount,
      calculationErrorCount: calculationErrorCount,
      weakTopics: weakTopics.toList(),
      feedbackList: feedbackList,
    );
  }
}
