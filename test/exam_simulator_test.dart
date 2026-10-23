import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/quiz/models/exam_simulator_model.dart';
import 'package:studysilo/features/quiz/services/exam_simulator_service.dart';

void main() {
  group('ExamSimulator Engine Tests', () {
    test('MockExamModel and MockExamQuestionModel JSON deserialization', () {
      final jsonMap = {
        'id': 'exam-1',
        'title': 'JEE Physics Mock',
        'exam_type': 'JEE Main',
        'duration_minutes': 15,
        'positive_marking': 4.0,
        'negative_marking': 1.0,
        'total_questions': 2,
        'questions': [
          {
            'id': 'q1',
            'question_text': 'What is the velocity gradient?',
            'options': ['A) dv/dx', 'B) dx/dt', 'C) dt/dx', 'D) dv/dt'],
            'correct_option_index': 0,
            'explanation': 'Velocity gradient is change in velocity over distance dv/dx.',
            'trap_warning': 'Do not confuse with acceleration dv/dt.',
            'topic': 'Fluid Mechanics',
            'error_category': 'conceptual',
          },
          {
            'id': 'q2',
            'question_text': 'Calculate kinematic viscosity if dynamic viscosity is 0.01 and density is 1000.',
            'options': ['A) 1e-5', 'B) 10', 'C) 1e-6', 'D) 100'],
            'correct_option_index': 0,
            'explanation': 'Kinematic viscosity = mu / rho = 0.01 / 1000 = 1e-5.',
            'trap_warning': 'Calculation trap: converting grams vs kilograms.',
            'topic': 'Fluid Mechanics',
            'error_category': 'calculation',
          },
        ]
      };

      final exam = MockExamModel.fromJson(jsonMap);

      expect(exam.id, 'exam-1');
      expect(exam.title, 'JEE Physics Mock');
      expect(exam.questions.length, 2);
      expect(exam.questions.first.correctOptionIndex, 0);
      expect(exam.questions.first.errorCategory, ErrorCategory.conceptual);
      expect(exam.questions.last.errorCategory, ErrorCategory.calculation);
    });

    test('ExamSimulatorService diagnostic evaluation applies negative marking and error categories', () {
      final service = ExamSimulatorService();

      final exam = MockExamModel(
        id: 'test-exam',
        title: 'Diagnostic Test',
        examType: 'JEE Main',
        durationMinutes: 15,
        positiveMarking: 4.0,
        negativeMarking: 1.0,
        totalQuestions: 3,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(
            id: 'q1',
            questionText: 'Concept Q',
            options: ['A', 'B', 'C', 'D'],
            correctOptionIndex: 0,
            topic: 'Kinematics',
            errorCategory: ErrorCategory.conceptual,
          ),
          MockExamQuestionModel(
            id: 'q2',
            questionText: 'Trap Q',
            options: ['A', 'B', 'C', 'D'],
            correctOptionIndex: 1,
            topic: 'Thermodynamics',
            errorCategory: ErrorCategory.trap,
          ),
          MockExamQuestionModel(
            id: 'q3',
            questionText: 'Calculation Q',
            options: ['A', 'B', 'C', 'D'],
            correctOptionIndex: 2,
            topic: 'Optics',
            errorCategory: ErrorCategory.calculation,
          ),
        ],
      );

      // User answers: Q1 -> 0 (Correct), Q2 -> 0 (Wrong, Trap), Q3 -> -1 (Skipped)
      final userAnswers = {
        0: 0,
        1: 0,
        2: -1,
      };

      final report = service.evaluateDiagnosticReport(
        exam: exam,
        userAnswers: userAnswers,
        timeTakenSeconds: 120,
      );

      expect(report.correctCount, 1);
      expect(report.incorrectCount, 1);
      expect(report.skippedCount, 1);
      // Score: +4 for Q1, -1 for Q2, 0 for Q3 = 3.0
      expect(report.totalScore, 3.0);
      expect(report.maxPossibleScore, 12.0);
      expect(report.examinerTrapCount, 1);
      expect(report.weakTopics, contains('Thermodynamics'));
      expect(report.weakTopics, contains('Optics'));
    });
  });
}
