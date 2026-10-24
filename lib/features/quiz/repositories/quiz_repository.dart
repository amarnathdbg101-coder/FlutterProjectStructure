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
      throw Exception('Server returned empty quiz response');
    } catch (e) {
      throw Exception('Failed to generate quiz: ${e.toString().replaceAll('Exception:', '').trim()}');
    }
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
      throw Exception('Server returned empty submission response');
    } catch (e) {
      throw Exception('Failed to submit quiz results: ${e.toString().replaceAll('Exception:', '').trim()}');
    }
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
