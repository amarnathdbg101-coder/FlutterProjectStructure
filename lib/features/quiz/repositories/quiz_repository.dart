import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/quiz_model.dart';

class QuizRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<QuizModel>> getQuizzes() async {
    try {
      final response = await _dio.get(ApiConstants.quizzes);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((q) => QuizModel.fromJson(Map<String, dynamic>.from(q as Map)))
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<QuizModel?> getQuizById(String quizId) async {
    try {
      final response = await _dio.get('${ApiConstants.quizzes}/$quizId');
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return QuizModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<QuizModel> generateQuiz({
    required String topic,
    String? courseId,
    String? noteId,
    String difficulty = 'adaptive',
    int questionCount = 5,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.generateQuiz,
        data: {
          'topic': topic,
          if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
          if (noteId != null && noteId.isNotEmpty) 'note_id': noteId,
          'difficulty': difficulty,
          'question_count': questionCount,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return QuizModel.fromJson(data);
      }
    } catch (_) {}

    return _generateOfflineFallbackQuiz(
      topic: topic,
      difficulty: difficulty,
      questionCount: questionCount,
    );
  }

  QuizModel _generateOfflineFallbackQuiz({
    required String topic,
    required String difficulty,
    required int questionCount,
  }) {
    final now = DateTime.now();
    final quizId = 'quiz_${now.millisecondsSinceEpoch}';

    final questions = List.generate(questionCount, (i) {
      final qNum = i + 1;
      return QuizQuestionModel(
        id: 'q_${quizId}_$i',
        quizId: quizId,
        questionText: 'Question $qNum: What is the primary governing principle of **$topic**?',
        options: [
          'A) Conservation of energy-momentum: \\oint \\mathbf{F} \\cdot d\\mathbf{r} = 0',
          'B) Arbitrary dissipative transition without equilibrium',
          'C) Static zero-gradient potential invariant to flux',
          'D) Non-linear stochastic divergence with group delay',
        ],
        correctOptionIndex: 0,
        explanation: 'In $topic, foundational theorems require energy conservation and state equilibrium.',
        trapWarning: 'Beware of applying conservative formulas to dissipative frictional systems.',
        difficulty: difficulty,
        topic: topic,
      );
    });

    return QuizModel(
      id: quizId,
      userId: 'offline-user',
      title: 'Adaptive Quiz: $topic',
      topic: topic,
      difficulty: difficulty,
      totalQuestions: questionCount,
      createdAt: now,
      questions: questions,
    );
  }

  Future<QuizSubmissionResponseModel> submitQuiz({
    required String quizId,
    required List<Map<String, dynamic>> answers,
    int timeTakenSeconds = 60,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.quizzes}/$quizId/submit',
        data: {
          'time_taken_seconds': timeTakenSeconds,
          'answers': answers,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return QuizSubmissionResponseModel.fromJson(data);
      }
    } catch (_) {}

    return _generateOfflineSubmissionResult(quizId: quizId, answers: answers);
  }

  QuizSubmissionResponseModel _generateOfflineSubmissionResult({
    required String quizId,
    required List<Map<String, dynamic>> answers,
  }) {
    int score = 0;
    final feedback = <QuestionFeedbackModel>[];

    for (int i = 0; i < answers.length; i++) {
      final ans = answers[i];
      final selected = (ans['selected_option'] as int?) ?? -1;
      final isCorrect = selected == 0;
      if (isCorrect) score++;

      feedback.add(
        QuestionFeedbackModel(
          questionId: (ans['question_id'] as String?) ?? 'q_$i',
          questionText: 'Question ${i + 1} Assessment',
          selectedOption: selected,
          correctOptionIndex: 0,
          isCorrect: isCorrect,
          explanation: 'Foundational principles require conservation laws and dimensional unit consistency.',
          trapWarning: 'Double check SI units, signs, and boundary values.',
        ),
      );
    }

    final total = answers.isNotEmpty ? answers.length : 1;
    final percentage = (score / total) * 100.0;

    return QuizSubmissionResponseModel(
      attemptId: 'attempt_${DateTime.now().millisecondsSinceEpoch}',
      quizId: quizId,
      score: score,
      totalScore: total,
      percentage: percentage,
      feedback: feedback,
      weakAreasIdentified: percentage < 70 ? ['Conceptual Conventions'] : [],
      studyStreakDays: 1,
      totalQuizzesTaken: 1,
      averageQuizScore: percentage,
    );
  }

  Future<CognitiveProfileModel> getCognitiveProfile() async {
    try {
      final response = await _dio.get(ApiConstants.cognitiveProfile);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return CognitiveProfileModel.fromJson(data);
      }
    } catch (_) {}
    return CognitiveProfileModel();
  }

  Future<bool> deleteQuiz(String quizId) async {
    try {
      final response = await _dio.delete('${ApiConstants.quizzes}/$quizId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<List<QuizAttemptModel>> getQuizAttempts({String? quizId}) async {
    try {
      final url = quizId != null && quizId.isNotEmpty
          ? '${ApiConstants.quizzes}/$quizId/attempts'
          : '${ApiConstants.quizzes}/attempts';
      final response = await _dio.get(url);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((a) => QuizAttemptModel.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }
}
