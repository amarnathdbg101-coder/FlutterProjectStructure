import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/quiz/models/quiz_model.dart';

void main() {
  group('Adaptive Quiz & Cognitive Profile Models Test', () {
    test('QuizModel and QuizQuestionModel JSON deserialization', () {
      final json = {
        'id': 'quiz-1',
        'user_id': 'u-101',
        'title': 'Advanced Mechanics Diagnostic',
        'topic': 'Classical Mechanics',
        'difficulty': 'adaptive',
        'total_questions': 2,
        'created_at': '2026-10-03T10:00:00Z',
        'questions': [
          {
            'id': 'q-1',
            'quiz_id': 'quiz-1',
            'question_text': r'What is the Euler-Lagrange equation for $L(q, \dot{q}, t)$?',
            'options': [
              r'\frac{d}{dt}\left(\frac{\partial L}{\partial \dot{q}}\right) - \frac{\partial L}{\partial q} = 0',
              r'\frac{\partial L}{\partial \dot{q}} + \frac{\partial L}{\partial q} = 0',
              r'\frac{d^2 L}{dt^2} = 0',
              r'\nabla \times \vec{F} = 0',
            ],
            'correct_option_index': 0,
            'explanation': 'The principle of least action derives this exact variation equation.',
            'trap_warning': 'Do not confuse total time derivative with partial derivative.',
            'difficulty': 'hard',
            'topic': 'Lagrangian Mechanics',
          },
        ],
      };

      final quiz = QuizModel.fromJson(json);
      expect(quiz.id, 'quiz-1');
      expect(quiz.title, 'Advanced Mechanics Diagnostic');
      expect(quiz.questions.length, 1);

      final q = quiz.questions.first;
      expect(q.id, 'q-1');
      expect(q.correctOptionIndex, 0);
      expect(q.options.length, 4);
      expect(q.trapWarning, contains('total time derivative'));
    });

    test('QuizSubmissionResponseModel JSON deserialization', () {
      final json = {
        'attempt_id': 'att-1',
        'quiz_id': 'quiz-1',
        'score': 4,
        'total_score': 5,
        'percentage': 80.0,
        'feedback': [
          {
            'question_id': 'q-1',
            'question_text': 'Sample Question',
            'selected_option': 0,
            'correct_option_index': 0,
            'is_correct': true,
            'explanation': 'Correct derivation.',
            'trap_warning': '',
          },
        ],
        'weak_areas_identified': ['Rotational Inertia'],
        'study_streak_days': 5,
        'total_quizzes_taken': 12,
        'average_quiz_score': 84.5,
      };

      final res = QuizSubmissionResponseModel.fromJson(json);
      expect(res.attemptId, 'att-1');
      expect(res.score, 4);
      expect(res.percentage, 80.0);
      expect(res.weakAreasIdentified, contains('Rotational Inertia'));
      expect(res.studyStreakDays, 5);
    });

    test('CognitiveProfileModel JSON deserialization', () {
      final json = {
        'target_exam': 'GATE / JEE Advanced',
        'academic_level': 'Senior Undergraduate',
        'weak_topics': ['Electrodynamics', 'Fluid Mechanics'],
        'strong_topics': ['Kinematics', 'Optics'],
        'exam_traps': ['Unit conversion errors'],
        'study_streak_days': 7,
        'total_study_minutes': 420,
        'total_quizzes_taken': 15,
        'average_quiz_score': 88.2,
      };

      final profile = CognitiveProfileModel.fromJson(json);
      expect(profile.targetExam, 'GATE / JEE Advanced');
      expect(profile.weakTopics.length, 2);
      expect(profile.strongTopics.length, 2);
      expect(profile.studyStreakDays, 7);
      expect(profile.averageQuizScore, 88.2);
    });

    test('QuizAttemptModel JSON deserialization', () {
      final json = {
        'id': 'att-99',
        'quiz_id': 'quiz-1',
        'user_id': 'u-101',
        'score': 4,
        'total_score': 5,
        'percentage': 80.0,
        'answers': [
          {
            'question_id': 'q-1',
            'selected_option': 0,
            'is_correct': true,
          },
        ],
        'weak_areas_identified': ['Pipelining'],
        'time_taken_seconds': 120,
        'created_at': '2026-10-15T08:00:00Z',
      };

      final attempt = QuizAttemptModel.fromJson(json);
      expect(attempt.id, 'att-99');
      expect(attempt.score, 4);
      expect(attempt.percentage, 80.0);
      expect(attempt.answers.length, 1);
      expect(attempt.answers.first.isCorrect, true);
      expect(attempt.weakAreasIdentified, contains('Pipelining'));
      expect(attempt.timeTakenSeconds, 120);
    });
  });
}
